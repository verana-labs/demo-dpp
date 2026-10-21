# demo-dpp
Digital Product Passport Demo

A Verana Verifiable Service that operates a shared Digital Product Passport
ecosystem (development network first), following the `verana-demos` pattern
with a new, dedicated organization. Design and decisions are documented in
[docs/implementation-plan.md](docs/implementation-plan.md).

## Status

Implementation in progress (phases 1–2 of the plan):

- `common/` — provisioning helpers vendored from `verana-labs/verana-demos`
  (see `common/README.md`).
- `dpp-vs/` — the standalone ecosystem operator agent (configuration, Helm
  values, local setup script), adapted from `organization-vs`.
- `.github/workflows/1_deploy-dpp-vs.yml` — deployment workflow
  (bootstrap corporation → deploy → validate onboarding → create ecosystem).
- `passport/` — the Papapo product passport credential schema (single source
  of truth; the deployment reads it in place).
- `egf/` — source draft of the ecosystem governance framework; the compiled
  document will be published as a GitHub Release asset (see the plan).

First deployment has not been run yet: it needs the repository secrets and
external checks listed in the plan (Phase 0 and Phase 4).

## Schema checks

The passport schemas carry regression checks that reproduce how the Verana
agent validates credential claims:

```bash
cd passport
npm install
npm run validate
```
