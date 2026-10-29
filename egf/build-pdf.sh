#!/usr/bin/env bash
# =============================================================================
# Build the Ecosystem Governance Framework PDF from Markdown.
#
# Re-run whenever egf/dpp-ecosystem-egf-vN.md changes, before creating or
# updating a GitHub Release asset. Do not replace an already-published
# release asset in place — corrections use a new version (egf-v2, …).
#
# Prerequisites (one of):
#   - pandoc + a PDF engine — recommended: `brew install pandoc tectonic`
#     (also accepts xelatex, lualatex, pdflatex, or weasyprint), OR
#   - Docker (pandoc/latex image; on Apple Silicon uses linux/amd64
#     emulation, which can be slow or memory-hungry)
#
# Usage:
#   ./egf/build-pdf.sh              # build v1 → egf/dpp-ecosystem-egf-v1.pdf
#   ./egf/build-pdf.sh v2           # build v2 from egf/dpp-ecosystem-egf-v2.md
#   ./egf/build-pdf.sh --out /tmp/dpp-ecosystem-egf-v1.pdf
#   EGF_VERSION=v1 ./egf/build-pdf.sh
#
# Environment:
#   EGF_VERSION   Version suffix without leading "v" or with it (default: 1 / v1)
#   OUT           Output PDF path (overrides --out)
#   PDF_ENGINE    Force a pandoc --pdf-engine value
#   DOCKER_IMAGE  Override Docker image (default: pandoc/latex:latest)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VERSION_RAW="${EGF_VERSION:-1}"
OUT_OVERRIDE="${OUT:-}"
DOCKER_IMAGE="${DOCKER_IMAGE:-pandoc/latex:latest}"

usage() {
  sed -n '2,28p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --out)
      [[ $# -ge 2 ]] || { echo "error: --out requires a path" >&2; exit 1; }
      OUT_OVERRIDE="$2"
      shift 2
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage 1
      ;;
    *)
      VERSION_RAW="$1"
      shift
      ;;
  esac
done

# Normalise to "vN" (accept "1", "v1", "V1")
VERSION_RAW="${VERSION_RAW#v}"
VERSION_RAW="${VERSION_RAW#V}"
VERSION="v${VERSION_RAW}"

SOURCE="${SCRIPT_DIR}/dpp-ecosystem-egf-${VERSION}.md"
OUTPUT="${OUT_OVERRIDE:-${SCRIPT_DIR}/dpp-ecosystem-egf-${VERSION}.pdf}"

if [[ ! -f "$SOURCE" ]]; then
  echo "error: source not found: $SOURCE" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

pick_local_engine() {
  if [[ -n "${PDF_ENGINE:-}" ]]; then
    if have_cmd "$PDF_ENGINE"; then
      echo "$PDF_ENGINE"
      return 0
    fi
    echo "error: PDF_ENGINE=$PDF_ENGINE not found on PATH" >&2
    return 1
  fi
  local eng
  # Prefer tectonic: small install (`brew install tectonic`), no full TeX live.
  for eng in tectonic xelatex lualatex pdflatex weasyprint; do
    if have_cmd "$eng"; then
      echo "$eng"
      return 0
    fi
  done
  return 1
}

build_with_local_pandoc() {
  local engine="$1"
  echo "Building with local pandoc (engine: ${engine})…"
  pandoc "$SOURCE" \
    -o "$OUTPUT" \
    --from markdown \
    --pdf-engine="$engine" \
    -V geometry:margin=1in \
    --metadata title="Digital Product Passport Ecosystem Governance Framework"
}

docker_pandoc() {
  # Optional extra docker-run flags (e.g. --platform linux/amd64).
  local src_base out_base out_dir
  src_base="$(basename "$SOURCE")"
  out_base="$(basename "$OUTPUT")"
  out_dir="$(cd "$(dirname "$OUTPUT")" && pwd)"

  docker run --rm \
    "$@" \
    --user "$(id -u):$(id -g)" \
    -v "${SCRIPT_DIR}:/data:ro" \
    -v "${out_dir}:/out" \
    "$DOCKER_IMAGE" \
    "/data/${src_base}" \
    -o "/out/${out_base}" \
    --from markdown \
    --pdf-engine=xelatex \
    -V geometry:margin=1in \
    --metadata title="Digital Product Passport Ecosystem Governance Framework"
}

build_with_docker() {
  if ! have_cmd docker; then
    return 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "error: Docker is installed but the daemon is not reachable" >&2
    return 1
  fi

  echo "Building with Docker image ${DOCKER_IMAGE}…"
  local arch
  arch="$(uname -m)"
  if [[ "$arch" == "arm64" || "$arch" == "aarch64" ]]; then
    # Official pandoc/latex images are amd64-only.
    docker_pandoc --platform linux/amd64
    return $?
  fi
  docker_pandoc
  return $?
}

print_digest() {
  local digest
  digest="sha384-$(openssl dgst -sha384 -binary "$OUTPUT" | openssl base64 -A)"
  echo
  echo "Wrote:   $OUTPUT"
  echo "Size:    $(wc -c <"$OUTPUT" | tr -d ' ') bytes"
  echo "Digest:  $digest"
  echo
  echo "Next: attach this file to GitHub Release tag egf-${VERSION} as"
  echo "      dpp-ecosystem-egf-${VERSION}.pdf (see docs/egf-hosting.md)."
  echo "      Pin EGF_DOC_DIGEST in dpp-vs/config.env to the digest above."
}

main() {
  cd "$REPO_ROOT"

  if have_cmd pandoc; then
    if engine="$(pick_local_engine)"; then
      build_with_local_pandoc "$engine"
      print_digest
      return 0
    fi
    echo "pandoc found, but no local PDF engine (xelatex/lualatex/pdflatex/tectonic/weasyprint)."
    echo "Trying Docker fallback…"
  else
    echo "pandoc not found on PATH; trying Docker fallback…"
  fi

  if build_with_docker; then
    print_digest
    return 0
  fi

  cat >&2 <<EOF
error: cannot build PDF.

Install one of:
  - brew install pandoc tectonic
  - Docker (image ${DOCKER_IMAGE}; may need --platform linux/amd64)

Then re-run: $0 ${VERSION}
EOF
  exit 1
}

main
