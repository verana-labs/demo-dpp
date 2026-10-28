# Ecosystem Governance Framework — hosting and publication

This document explains how the Digital Product Passport (DPP) demo publishes
its Ecosystem Governance Framework (EGF), why that design was chosen, how the
chain uses the document, and the exact checklist to publish version 1 and later
corrections.

Audience: anyone preparing the first `dpp-vs` deployment who is not yet
familiar with digests, GitHub Releases, or how Corporation / Ecosystem
creation consume the EGF.

---

## 1. What the EGF is in this project

The EGF is the governance text for the DPP Ecosystem: roles (operator, Issuer
grantor, verification service, brand issuers, third parties, verifiers),
admission rules, schema rules, and evidence expectations.

| Artefact | Path / location | Role |
|---|---|---|
| Source (editable) | `egf/dpp-ecosystem-egf-v1.md` | Human-authored Markdown; source of truth in git |
| Published form | PDF file `dpp-ecosystem-egf-v1.pdf` | What the chain points at |
| Public URL | See §3 | Written into Corporation and Ecosystem on-chain records |
| Content digest | `sha384-…` (SRI form) | Hash of the PDF bytes; stored on-chain next to the URL |

The agent and the workflows do **not** embed the PDF. They only store a URL and
a digest. Anyone can later re-download the URL and check that the bytes still
match the digest.

---

## 2. Why we do not use the same hosting as `verana-demos`

In [`verana-demos`](https://github.com/verana-labs/verana-demos), the example
EGF is **not** in that repository. It is hosted in a separate repo:

| | `verana-demos` (reference) | `demo-dpp` (this repo, decision D5) |
|---|---|---|
| Source repo | `verana-labs/governance-docs` | `verana-labs/demo-dpp` (`egf/`) |
| Publish mechanism | GitHub Pages | GitHub **Release** asset |
| Example URL | `https://verana-labs.github.io/governance-docs/EGF/example.pdf` | `https://github.com/verana-labs/demo-dpp/releases/download/egf-v1/dpp-ecosystem-egf-v1.pdf` |
| PDF in git? | Yes (`content/EGF/example.pdf` in governance-docs) | Optional; release asset is what matters |
| Cross-repo dependency | Yes | No |

Reasons for the DPP choice (agreed with reviewers, including GenAris):

1. **No external repo** — DPP governance lives next to the DPP deployment code.
2. **Immutability discipline** — on-chain records store a content digest of the
   file at the URL. A GitHub Pages path can be overwritten in place; a Release
   asset should not be replaced. Corrections use a **new** release (`egf-v2`)
   and an on-chain governance version update.
3. **Same-repo review** — EGF Markdown changes go through the same pull-request
   process as the rest of `demo-dpp`.

Rejected alternatives: putting DPP docs into `governance-docs`; GitHub Pages
*inside* `demo-dpp` (same overwrite risk as the demos’ Pages URL).

---

## 3. Locked URL and configuration

Already set in `dpp-vs/config.env`:

```bash
EGF_DOC_URL="https://github.com/verana-labs/demo-dpp/releases/download/egf-v1/dpp-ecosystem-egf-v1.pdf"
# EGF_DOC_DIGEST=""
```

| Piece | Value | Notes |
|---|---|---|
| Release **tag** | `egf-v1` | Must match the path segment in the URL |
| Asset **file name** | `dpp-ecosystem-egf-v1.pdf` | Must match the last path segment exactly |
| `EGF_DOC_URL` | Full download URL above | Used at Corporation and Ecosystem creation |
| `EGF_DOC_DIGEST` | Empty by default | If empty, scripts compute it at runtime (see §4) |

Until that release exists and the PDF downloads successfully, the first
`bootstrap-corporation` / `create-dpp-ecosystem` run **will fail** when
computing the digest (`curl` of a missing URL).

---

## 4. How the chain uses URL + digest (technical path)

### 4.1 Helper: `compute_sri_digest`

In `common/common.sh`:

```bash
# Downloads the URL, hashes the body with SHA-384, returns:
#   sha384-<base64>
compute_sri_digest() {
  curl -sfL "$url" | openssl dgst -sha384 -binary | openssl base64 -A
  # → echo "sha384-${hash}"
}
```

This is a **Subresource Integrity (SRI)** style digest: algorithm prefix +
base64 of the raw hash. It binds the *bytes* of the PDF, not the git commit.

### 4.2 Where it is written on-chain

| On-chain object | Script entry | What is stored |
|---|---|---|
| **Corporation** | `create_corporation` in `common/common.sh` | `--doc-url` + `--doc-digest-sri` |
| **Ecosystem** | `create_ecosystem` in `common/common.sh` | positional `doc_url` + `doc_digest` |

Call flow for the first full deploy (`dpp-vs`):

1. Workflow / `setup.sh` sources `dpp-vs/config.env` → reads `EGF_DOC_URL`
   (and optional `EGF_DOC_DIGEST`).
2. `create_corporation … "$EGF_DOC_URL"` — if digest empty, `compute_sri_digest`
   runs against the live URL.
3. Later, `create_ecosystem … "$EGF_DOC_URL" "$EGF_DOC_DIGEST"` — same rule.

So the PDF must already be downloadable **before** either of those steps.

### 4.3 Empty digest vs pinned digest

| Mode | Behaviour | Pros | Cons |
|---|---|---|---|
| **Empty `EGF_DOC_DIGEST`** (current demos style) | Digest computed at deploy time from the live URL | Simple; always matches whatever is at the URL that day | Deploy needs network access to GitHub Releases; silent asset replace could be hashed “successfully” if you overwrite the same release |
| **Pinned digest** (GenAris recommendation) | Set `EGF_DOC_DIGEST="sha384-…"` in `config.env` after publishing | Deploy fails if the URL content changes; digest reviewed in git | Must recompute and commit when publishing a new EGF version |

**Recommendation for DPP:** publish the PDF, compute the digest once, **pin** it
in `config.env`, then run the first Corporation create. Keep the compute
fallback for local experiments if needed.

### 4.4 Immutable releases (GenAris)

GitHub can mark a release as **immutable** so attached assets cannot be
replaced after publication. Prefer enabling that for `egf-v1` if the
organisation/repo settings allow it.

Even without immutable releases:

- Do **not** replace `dpp-ecosystem-egf-v1.pdf` on the `egf-v1` release.
- If someone does replace it anyway, a **pinned** on-chain digest no longer
  matches the new bytes — verification fails (that is intentional).
- Corrections = new tag / new URL / new digest / on-chain governance version
  bump (see §7).

---

## 5. End-to-end publication checklist (version 1)

Use this list before the first `dpp-vs` deploy (`step=all` or
`bootstrap-corporation` + `create-dpp-ecosystem`).

### A. Content

- [ ] Review `egf/dpp-ecosystem-egf-v1.md` (roles include Issuer grantor and
      verification service; demo status is explicit).
- [ ] Optionally clear “Draft” from the status line once you treat the text as
      the published v1.
- [ ] Merge the Markdown to `main` via pull request (so the release tags real
      repository history).

### B. Build the PDF

- [ ] Produce `dpp-ecosystem-egf-v1.pdf` from the Markdown (Pandoc, Typst,
      LibreOffice, Word export, etc.).
- [ ] File name must be exactly `dpp-ecosystem-egf-v1.pdf`.
- [ ] Keep a local copy; do not commit secrets. Committing the PDF under `egf/`
      is optional (reproducibility); the **release asset** is what the URL
      serves.

Example with Pandoc (if installed):

```bash
pandoc egf/dpp-ecosystem-egf-v1.md \
  -o /tmp/dpp-ecosystem-egf-v1.pdf \
  --pdf-engine=xelatex   # or weasyprint / wkhtmltopdf depending on your setup
```

Any tool that yields a stable PDF is fine; reproducibility matters more than
the toolchain.

### C. Create the GitHub Release

- [ ] On `verana-labs/demo-dpp`, create a release with tag **`egf-v1`**
      (exact spelling).
- [ ] Attach **only** `dpp-ecosystem-egf-v1.pdf` as a release asset (or at
      least ensure that file name is present).
- [ ] Prefer **immutable release** if available.
- [ ] Do not attach drafts you intend to replace; treat the asset as final for
      this tag.

Example with GitHub CLI (after the PDF exists locally):

```bash
gh release create egf-v1 \
  /tmp/dpp-ecosystem-egf-v1.pdf \
  --repo verana-labs/demo-dpp \
  --title "EGF v1 — DPP Ecosystem Governance Framework" \
  --notes "First published Ecosystem Governance Framework for the DPP demo. Do not replace this asset; corrections ship as egf-v2."
```

### D. Verify download and digest

```bash
URL="https://github.com/verana-labs/demo-dpp/releases/download/egf-v1/dpp-ecosystem-egf-v1.pdf"

# 1) File must download
curl -sfL "$URL" -o /tmp/dpp-ecosystem-egf-v1.pdf
ls -la /tmp/dpp-ecosystem-egf-v1.pdf

# 2) Same digest the scripts compute
DIGEST="sha384-$(openssl dgst -sha384 -binary /tmp/dpp-ecosystem-egf-v1.pdf | openssl base64 -A)"
echo "$DIGEST"
```

- [ ] `curl` succeeds (HTTP 200, non-empty PDF).
- [ ] Digest prints as `sha384-` followed by base64 (no error).

### E. Pin the digest in config (recommended)

In `dpp-vs/config.env`:

```bash
EGF_DOC_URL="https://github.com/verana-labs/demo-dpp/releases/download/egf-v1/dpp-ecosystem-egf-v1.pdf"
EGF_DOC_DIGEST="sha384-<paste-from-step-D>"
```

- [ ] Commit that pin on the deployment branch before first Corporation create.
- [ ] Confirm local setup / workflow still sources the variable (empty vs set).

### F. Gate for first deploy

- [ ] Only after A–E: run `dpp-vs` bootstrap / create-ecosystem.
- [ ] If digest computation fails, stop — fix the release URL or asset name;
      do not point at a temporary or Pages URL as a shortcut without updating
      the locked D5 decision.

---

## 6. Follow-up checklist from the Discord review

These items came out of the team discussion (feegrant thread + EGF reply).
They sit next to EGF hosting so the first deploy is coherent.

### EGF-specific

| # | Action | Status / owner |
|---|---|---|
| E1 | Publish PDF as release asset `egf-v1` / `dpp-ecosystem-egf-v1.pdf` | To do |
| E2 | Enable immutable release if the repo supports it | To do |
| E3 | Pin `EGF_DOC_DIGEST` in `dpp-vs/config.env` after publish | To do (recommended) |
| E4 | Document correction path = new tag + new digest + on-chain GF version bump (not edit-in-place) | This doc §7 |
| E5 | Do not depend on `governance-docs` or Pages for DPP | Locked (D5) |

### Related ops (corporation fee grants — same Discord thread)

Not EGF hosting, but needed for a working demo of corporation-pays agents:

| # | Action | Notes |
|---|---|---|
| F1 | Keep `--vs-operator-authz-with-feegrant` (already in `common.sh` child provisioning) | Corporation pays agent fees; daily cap ~50 VNA default |
| F2 | Fund the Corporation **policy address**, not only the agent wallet | Agent txs do **not** fall back to the agent balance if the policy address is empty |
| F3 | Record policy-address funding in the Phase 0 / first-deploy runbook | Faucet or Keplr plain send; no “Fund corporation” UI yet |
| F4 | Optional playground feature request: “Fund corporation” button | Product ask from GenAris |

---

## 7. Corrections after `egf-v1` is on-chain

Never replace the file on the `egf-v1` release.

1. Edit Markdown → e.g. `egf/dpp-ecosystem-egf-v2.md`.
2. Build `dpp-ecosystem-egf-v2.pdf`.
3. Create release tag `egf-v2` with that asset (immutable if possible).
4. Compute and pin the new digest.
5. Update on-chain governance document / active version for the Corporation
   and/or Ecosystem (chain messages for increasing the governance framework
   version — not a silent URL rewrite under `egf-v1`).
6. Point `EGF_DOC_URL` / digest in config at the new release for **future**
   creates; existing on-chain records keep the old URL+digest until explicitly
   updated.

GenAris’s wording: a correction is a **new governance-framework version** and
an **increase of the active version**, not an edit of the published bytes.

---

## 8. Mental model (one diagram)

```text
  egf/dpp-ecosystem-egf-v1.md     ← edit in git / PR
           │
           ▼
  dpp-ecosystem-egf-v1.pdf        ← build offline
           │
           ▼
  GitHub Release tag egf-v1       ← attach PDF (prefer immutable)
           │
           ▼
  EGF_DOC_URL  (+ optional EGF_DOC_DIGEST)
           │
           ├──────────────► create_corporation  ──► chain stores url + digest
           └──────────────► create_ecosystem    ──► chain stores url + digest

  Later verify:  curl URL | sha384  ==  on-chain digest
```

---

## 9. Quick reference

| Item | Value |
|---|---|
| Source | `egf/dpp-ecosystem-egf-v1.md` |
| Release tag | `egf-v1` |
| Asset name | `dpp-ecosystem-egf-v1.pdf` |
| URL | `https://github.com/verana-labs/demo-dpp/releases/download/egf-v1/dpp-ecosystem-egf-v1.pdf` |
| Config | `dpp-vs/config.env` → `EGF_DOC_URL`, `EGF_DOC_DIGEST` |
| Digest algorithm | SHA-384, SRI form `sha384-<base64>` |
| Used by | `create_corporation`, `create_ecosystem` in `common/common.sh` |
| Decision | D5 in `docs/implementation-plan.md` |

---

## 10. References

- `docs/implementation-plan.md` — decision D5, Phase 2 exit criteria
- `egf/dpp-ecosystem-egf-v1.md` — EGF source text
- `dpp-vs/config.env` — URL (and optional digest)
- `common/common.sh` — `compute_sri_digest`, `create_corporation`, `create_ecosystem`
- [`verana-labs/governance-docs`](https://github.com/verana-labs/governance-docs) — demos’ Pages-based approach (not used here)
- Team review (Discord): Release asset approved; prefer immutable releases; pin digest; corrections = new GF version + active version increase
