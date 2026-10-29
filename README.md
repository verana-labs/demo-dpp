# demo-dpp
Digital Product Passport Demo

A Verana Verifiable Service that operates a shared Digital Product Passport
ecosystem (development network first), following the `verana-demos` pattern
with a new, dedicated organization. Design and decisions are documented in
[docs/implementation-plan.md](docs/implementation-plan.md).

## Minimum coherent set

First delivery is three agents under one Corporation:

| Service | Role | Workflow |
|---|---|---|
| `dpp-vs` | Ecosystem operator (standalone) | `1_deploy-dpp-vs.yml` |
| `issuer-grantor-vs` | Issuer grantor (delegated) | `2_deploy-issuer-grantor-vs.yml` |
| `verifier-vs` | Verification service (delegated) | `3_deploy-verifier-vs.yml` |

Deploy order (after merge and secrets): `dpp-vs` → `issuer-grantor-vs` → `verifier-vs`, from branch `vs/devnet-dpp`.

## Status

Scaffolding for the minimum set is in progress on the feature branch:

- `common/` — provisioning helpers vendored from `verana-labs/verana-demos`
- `dpp-vs/` — ecosystem operator
- `issuer-grantor-vs/` — operator-run Issuer grantor (agent only; no web UI yet)
- `verifier-vs/` — operator-run verification service (agent only; no web UI yet)
- `passport/` — Papapo product passport schema (single source of truth)
- `egf/` — governance framework source; PDF must be published as release `egf-v1` before first deploy (step-by-step: [docs/egf-hosting.md](docs/egf-hosting.md))

## Secrets required

| Secret | Used by |
|---|---|
| `KUBECONFIG` | All workflows |
| `K8S_NAMESPACE` | All workflows (`demo-dpp`) |
| `DPP_VS_MNEMONIC` | Corporation operator (all three workflows) |
| `DPP_VS_AGENT_MNEMONIC` | `dpp-vs` agent |
| `ISSUER_GRANTOR_VS_AGENT_MNEMONIC` | Issuer grantor agent |
| `VERIFIER_VS_AGENT_MNEMONIC` | Verifier agent |

## Schema checks

```bash
cd passport
npm install
npm run validate
```
