# Ecosystem Governance Framework (source)

- **Source text:** [`dpp-ecosystem-egf-v1.md`](dpp-ecosystem-egf-v1.md)
- **Build PDF:** [`build-pdf.sh`](build-pdf.sh) — re-run after Markdown edits
- **How to publish the PDF, digests, and releases:** [`../docs/egf-hosting.md`](../docs/egf-hosting.md)

```bash
# Prerequisites: brew install pandoc tectonic
./egf/build-pdf.sh          # → egf/dpp-ecosystem-egf-v1.pdf (+ prints sha384 digest)
./egf/build-pdf.sh v2       # when egf/dpp-ecosystem-egf-v2.md exists
```

Do not replace a published release asset. Corrections use a new version
(`egf-v2`, …) as described in that guide.
