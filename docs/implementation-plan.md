# DPP Demo — Implementation Plan (Option C: New Organization)

| | |
|---|---|
| Status | **Draft — started 2026-10-21, not yet implemented** |
| Decision | **Option C**: create a *new* organization for DPP in this repo (`demo-dpp`), reusing `verana-demos/organization-vs` as the code template. Do **not** reuse the live "Verana Example Organization" Corporation or its "example" Ecosystem. |
| Reference implementation | [`verana-labs/verana-demos`](https://github.com/verana-labs/verana-demos), `organization-vs/` + `.github/workflows/1_deploy-organization-vs.yml` (cloned locally at commit `e2b9983`) |
| Target (first) | Verana **devnet**, Verifiable Trust **v4**, `vs-agent v2.0.0-dev.97`, `veranad v0.10.6` |
| Deliverable of this plan | One standalone vs-agent at a `*.dpp.demos.*` host, controller of its own **DPP Ecosystem** with a DPP credential schema |
| DPP schema draft | **`passport/` in this repo** — Papapo Product Passport (see §6.2): full schema `passport/papapo-product-passport.schema.json` is the canonical first draft; `passport/papapo-product-passport.min.schema.json` is the issuance-testing variant |

---

## 1. Objective

Deploy a Verifiable Service (VS) for the Digital Product Passport (DPP) demo that:

1. Runs the Verana **vs-agent** in Kubernetes via GitHub Actions, following the exact deployment pattern of `verana-demos`.
2. Is a **standalone** agent (`agentMode: standalone`) that owns its own **Corporation** and its own **Ecosystem** ("DPP Ecosystem") with a DPP credential schema, so DPP issuers/verifiers can later onboard as `delegated` children (same pattern as `issuer-*/verifier-*` in verana-demos).
3. Obtains its own ECS **Organization** and **Service** credentials by onboarding against the shared `ecs-ecosystem` operated by [`verana-labs/verana-deploy`](https://github.com/verana-labs/verana-deploy) (it does *not* issue those to itself).
4. Is discoverable in [Verana Search (devnet)](https://search.devnet.verana.network) / the [Trust Graph API](https://graph.devnet.verana.network/docs) under a DPP identity.

### Non-goals (this phase)

- DPP issuer/verifier applications (web or chatbot) — deferred to Phase 6.
- A playground/tutorial front-end — deferred.
- Testnet deployment — devnet first; testnet promotion is Phase 6 and needs the cross-cluster ECS onboarding validation done from the `verana-deploy` cluster (see §9).

---

## 2. How the reference works (what we are copying)

From `verana-demos` (see its README for the full description):

```text
ecs-ecosystem               ← shared ECS authority (verana-deploy, NOT in scope here)
└── organization-vs         ← standalone agent, owns the deployment's only Corporation
    └── "example" Ecosystem ← created by organization-vs, children onboard against it
        ├── issuer-*        ← delegated children (AGENT_MODE=delegated)
        └── verifier-*      ← delegated children
```

Key properties we deliberately preserve:

- **One Corporation per deployment**, created by the standalone agent's `bootstrap-corporation` step; children (later) join it instead of creating their own.
- **Two distinct accounts**: a Corporation *operator* (blanket `OperatorAuthorization`, signs all provisioning transactions, never seen by the agent) and the *agent account* (`vs_operator` of the agent's Participant entries, holds a `VSOperatorAuthorization`). The chain forbids one account holding both. They **must** be different mnemonics — this cannot be merged or skipped (vs-agent refuses to start without `VERANA_ACCOUNT_MNEMONIC`).
- **Scripts create on-chain objects; the agent reacts.** Workflows only create the Corporation, Participant entries, Ecosystem, schema and root participant. The agent publishes its VTJSCs, self-issues what it may, and drives onboarding flows itself.
- **vs-agent v2 Admin API only** (`/v2/...`). The Admin API is never exposed via ingress; workflows reach it with `kubectl port-forward`.
- **Hostname = identity.** The chart sets the public API base URL from the ingress host, and the agent's `did:webvh` public DID is anchored to it.

---

## 3. Target architecture

```text
ecs-ecosystem                      ← shared, from verana-deploy (prerequisite, unchanged)
└── dpp-vs                         ← NEW standalone agent in this repo (clone of organization-vs)
    │   Corporation: <new DPP corporation>          (bootstrap-corporation)
    │   ECS credentials: Organization + Service     (via ecs-org-issuer onboarding)
    └── "DPP" Ecosystem            ← NEW, created by dpp-vs (create-dpp-ecosystem)
        │   DPP credential schema  (`passport/papapo-product-passport.schema.json`, CUSTOM_SCHEMA_BASE_ID=dpp)
        │   Root participant: dpp-vs (ECOSYSTEM role)
        ├── (Phase 6) DPP issuer   ← delegated child (per brand; Papapo is the first brand)
        └── (Phase 6) DPP verifier ← delegated child
```

**Multi-brand by design (decided 2026-10-21):** the DPP Ecosystem is *shared between multiple brands*. `dpp-vs` is therefore a **brand-neutral ecosystem operator**, not a brand. Papapo (a footwear brand) is the first participating brand — its passport schema (§6.2) is the ecosystem's first credential schema and Papapo will onboard later as a brand issuer (Phase 6), on the same footing as any future brand. This disqualifies making Papapo the ecosystem's legal entity (D2 Proposal 1). The operator identity is D2 Proposal 2, locked in §10: `ORG_NAME="Verana DPP Example Organization"` with the remaining `ORG_*` claims inherited unchanged from `organization-vs`.

**Multi-product, multi-schema by design (decided 2026-10-21):** the same DPP Ecosystem will host *different credential schemas for different products* over time. The Papapo footwear passport is schema #1, not the ecosystem's definition: a future product (another footwear line, textiles, electronics, …) gets its **own** credential schema (`create_credential_schema` under the same `ECOSYSTEM_ID`, plus its own root participant and its own issuer/verifier participants) — no new ecosystem, corporation, or agent. Consequences: (a) the ecosystem identity (D3) and the EGF (D5) must be **product-agnostic**; (b) issuer/verifier onboarding and schema discovery (Phase 6) must address schemas by ID/type, never by assuming "the" DPP schema; and (c) D3 Proposal 3 (`Footwear DPP Ecosystem`) is ❌ rejected as too narrow.

### 3.1 Naming and domains

Following the verana-demos branch convention, create branch **`vs/devnet-dpp`**:

| Derived value | Value |
|---|---|
| `NETWORK` | `devnet` |
| `VS_NAME` | `dpp` |
| `global.domain` | `dpp.demos.devnet.verana.network` |
| Agent host (`ingress.host`) | `dpp-vs.dpp.demos.devnet.verana.network` |
| Helm release name | `dpp` (as in demos, `deployment.yaml: name: __VS_NAME__`) |
| DID document | `https://dpp-vs.dpp.demos.devnet.verana.network/.well-known/did.json` |

> ✅ **Decision D1 — locked 2026-10-21 (Proposal 1, demos-native):** use the verana-demos scheme above, network segment included. Rejected alternatives: literal network-less `*.dpp.demos.verana.network` (Proposal 2 — devnet/testnet cannot coexist, environment invisible in the URL, extra DNS zone) and network-first `*.<network>.dpp.demos.verana.network` (Proposal 3 — template + DNS changes for cosmetic gain only). No workflow/template deviation is needed for naming. Note the host is baked into the agent's `did:webvh`: changing it later means a new DID, new Participant entries, and re-issued credentials. A network-less vanity host may still be adopted later **for testnet only** as a deliberate launch event (fresh DID/ecosystem), not a migration.

Prerequisites outside this repo: DNS for `*.dpp.demos.devnet.verana.network` pointing at the cluster ingress, and `cert-manager` with the `letsencrypt-prod` cluster issuer (the chart/workflow rely on it for `<host>-cert` TLS secrets).

---

## 4. Proposed repository layout

```text
demo-dpp/
├── README.md
├── docs/
│   └── implementation-plan.md        ← this document
├── egf/                              ← EGF source (Markdown/LaTeX); PDF published as a GitHub Release asset (D5, §6.3)
├── passport/                         ← DPP schema (SINGLE source of truth, see §5.4)
│   ├── papapo-product-passport.schema.json        ← canonical schema — deployment reads it in place
│   ├── papapo-product-passport.example.json       ← example credentialSubject (model level)
│   ├── papapo-product-passport.min.schema.json    ← minimal variant for issuance testing
│   └── papapo-product-passport.min.example.json
├── common/
│   ├── common.sh                     ← copied from verana-demos (see §5)
│   └── faucet-fund.sh                ← copied from verana-demos
├── dpp-vs/
│   ├── config.env                    ← adapted from organization-vs/config.env
│   ├── deployment.yaml               ← adapted from organization-vs/deployment.yaml
│   ├── docker/
│   │   └── docker-compose.yml        ← copied (local dev)
│   └── scripts/
│       └── setup.sh                  ← adapted from organization-vs/scripts/setup.sh
└── .github/
    └── workflows/
        └── 1_deploy-dpp-vs.yml       ← adapted from 1_deploy-organization-vs.yml
```

Sync strategy for `common/`: copy once, pinned to verana-demos commit `e2b9983`; record the source commit in `common/README` or a comment header. Re-sync deliberately (diff review) when upstream fixes land — do not auto-track `main`.

---

## 5. File-by-file work breakdown

### 5.1 `common/common.sh`, `common/faucet-fund.sh`
- [ ] Copy unchanged. The network helpers (`set_network_vars`), Corporation/Ecosystem/schema/Participant helpers, `validate_pending_flow`, `fetch_did_from_log`, etc. are generic.
- [ ] Verify no `example`-specific defaults need changing for DPP (EGF defaults are parameterised at call sites).

### 5.2 `dpp-vs/config.env` (from `organization-vs/config.env`)
- [ ] `USER_ACC="dpp-vs-devnet-admin"`, `AGENT_ACC="dpp-vs-devnet-agent"` (veranad key names — **names only, never mnemonics**).
- [ ] `CORPORATION_ID="${CORPORATION_ID:-}"` — keep the override form, empty until first `bootstrap-corporation` run; afterwards commit the printed ID.
- [ ] `VS_AGENT_CONTAINER_NAME="dpp-vs"`, keep image pin `veranalabs/vs-agent:v2.0.0-dev.97`.
- [ ] Identity claims (D2 locked, §10): set only `ORG_NAME="Verana DPP Example Organization"`. Inherit all other `ORG_*` claims unchanged from `organization-vs/config.env` (`ORG_ORGANIZATION_KIND="PUBLIC"`, `ORG_COUNTRY_CODE="CH"`, `ORG_REGISTRY_ID="CH-CHE-123.456.789"`, `ORG_REGISTRY_URI="https://www.zefix.ch"`, `ORG_ADDRESS="Bahnhofstrasse 42, 8001 Zurich, Switzerland"`, `ORG_LOGO_URI="https://verana.io/logo.svg"` — the logo must stay publicly reachable and stable, as the agent hashes it into `logoDigestSri`). Apply the same `ORG_NAME` to `ECS_CLAIMS_ORG_NAME` in `deployment.yaml` and the fallback default in `scripts/setup.sh`.
- [ ] Service claims (D3 locked, §10): `SERVICE_NAME="DPP Ecosystem (demo)"` (names the service, is the DIDComm label, **and** is what explorers/Graph Search show for the ecosystem), `SERVICE_TYPE="WEB_PORTAL"`, `SERVICE_DESCRIPTION="Multi-brand, multi-product Digital Product Passport ecosystem"`. Inherit `SERVICE_LOGO_URI="https://verana.io/logo.svg"`. Apply identically to `ECS_CLAIMS_SERVICE_*` in `deployment.yaml`.
- [ ] `CUSTOM_SCHEMA_BASE_ID="dpp"`, `EGF_DOC_URL=<DPP governance framework PDF>` (digest auto-computed if `EGF_DOC_DIGEST` empty).
- [ ] `PASSPORT_SCHEMA_FILE` pointing at the single schema location in `passport/` (§5.4).

### 5.3 `dpp-vs/deployment.yaml` (from `organization-vs/deployment.yaml`)
- [ ] Keep placeholder mechanism: `__NETWORK__`, `__VS_NAME__`, `__CORPORATION_ID__`, `__ECS_ECOSYSTEM_DID__`.
- [ ] `agentMode: "standalone"`, `trustedEcsEcosystemDids: "__ECS_ECOSYSTEM_DID__"` (resolved live at deploy time, never pinned).
- [ ] `ingress.host: "dpp-vs.__VS_NAME__.demos.__NETWORK__.verana.network"`, matching `tlsSecret`.
- [ ] `adminApiAuthMode: "internal"`, `adminApiTrustedNetworks: "127.0.0.0/8,::1/128,10.2.0.0/16"`, `EXPOSE_ADMIN_API=false` behaviour (no admin ingress — non-negotiable, see verana-demos README "Ingresses").
- [ ] `extraEnv.ECS_CLAIMS_*`: mirror the identity from `config.env` (org group + service group, incl. `TERMS_AND_CONDITIONS_URI` / `PRIVACY_POLICY_URI` under the new `dpp-vs` host). A standalone agent requires the full service claim set at boot.
- [ ] `VERANA_ACCOUNT_MNEMONIC` via `secretKeyRef: { name: dpp-vs-secrets, key: DPP_VS_AGENT_MNEMONIC }`.
- [ ] Keep resource requests/limits and `storage: 1Gi / csi-cinder-high-speed` unless the DPP namespace has a different storage class (confirm in Phase 0).

### 5.4 DPP credential schema location — single source of truth (§6.2)

**There is exactly one copy of the DPP schema: `passport/papapo-product-passport.schema.json`. There is no `dpp-vs/schema.json`** (this deviates deliberately from verana-demos, where `organization-vs/schema.json` is the only schema the demo has. Here the passport schema is a standalone domain artefact — shared with the Papapo storefront/Medusa side — so the deployment references it in place rather than duplicating it into `dpp-vs/`).

Wire it by path, in the two places that read a schema file:

- [ ] `dpp-vs/config.env`: add `PASSPORT_SCHEMA_FILE="${PASSPORT_SCHEMA_FILE:-passport/papapo-product-passport.schema.json}"` (repo-relative). Switching to the fallback min schema is then a one-line change to `passport/papapo-product-passport.min.schema.json` — still no copy.
- [ ] `dpp-vs/scripts/setup.sh`: resolve `CUSTOM_SCHEMA_FILE` against `REPO_ROOT` + `$PASSPORT_SCHEMA_FILE` instead of the reference default `${SERVICE_DIR}/schema.json`.
- [ ] `.github/workflows/1_deploy-dpp-vs.yml`: in the `create-dpp-ecosystem` step, build `SCHEMA_JSON` with `jq -c '.' "$PASSPORT_SCHEMA_FILE"` instead of `organization-vs/schema.json`.

Rules:
- Edit the schema only in `passport/`; the example JSONs next to it are its test fixtures. Any PR changing the schema should re-validate the examples (§6.2).
- The on-chain credential schema is immutable once created: editing `passport/` after Phase 4 creates a *new* schema on the next ecosystem (re)creation, it does not mutate the deployed one. Version changes go through `$id` (`…/v1` → `…/v2`) plus a new `create_credential_schema`, exactly as with any schema evolution.

### 5.5 `dpp-vs/scripts/setup.sh` and `docker/docker-compose.yml`
- [ ] Copy and rename (accounts, ports, container name, output `ids.env`). This gives a local Docker+ngrok path that performs the same steps as the workflow — useful to validate config before CI exists.
- [ ] Keep the guard that aborts if `AGENT_MNEMONIC == MNEMONIC`.

### 5.6 `.github/workflows/1_deploy-dpp-vs.yml` (from `1_deploy-organization-vs.yml`)
Steps, in order (same step model as demos; `step=all` runs the whole chain):

| Step | Change vs. reference |
|---|---|
| Branch validation | Unchanged logic (`main` → testnet/`main`, `vs/<net>-<name>`). Deploy DPP from `vs/devnet-dpp`. |
| Load configuration | Source `dpp-vs/config.env`. |
| Resolve ECS Ecosystem DID | Unchanged — read live from `https://ecs-ecosystem.<network>.verana.network/.well-known/did.jsonl`. Fails if `verana-deploy` ECS is not up on that network. |
| `bootstrap-corporation` | Step name unchanged. Uses `DPP_VS_MNEMONIC` + `DPP_VS_AGENT_MNEMONIC` (see §7). Keep the "re-resolve `deployment.yaml` after bootstrap on `all` runs" step — the agent needs `VERANA_CORPORATION_ID` at boot. |
| `deploy` | K8s secret `dpp-vs-secrets`; Helm release `dpp`. |
| `validate-ecs-onboarding` | Unchanged logic: operator creates Service `ISSUER` (self-create, OPEN schema) + Organization `HOLDER` (`StartParticipantOP`) entries naming the agent account as `vs_operator`; validate the agent's pending flow on `ecs-org-issuer` (port-forwarded `3101` on devnet, same cluster). |
| `create-example-ecosystem` → **`create-dpp-ecosystem`** | Renamed. `create_ecosystem` → `create_credential_schema` (schema JSON read in place from `$PASSPORT_SCHEMA_FILE` under `passport/` — §5.4, no `dpp-vs/schema.json` copy; same mode constants as the reference: issuer `ONBOARDING_MODE_ECOSYSTEM`, verifier `ONBOARDING_MODE_OPEN`, holder `HOLDER_MODE_ISSUER_OP` from `common/common.sh`) → `create_root_participant`. Must stay idempotent (`find_ecosystem_for_did` check first). |

---

## 6. On-chain objects and content to design

### 6.1 Objects created by the first `step=all` run

1. **Corporation** (`verana.co.v1`) + blanket `OperatorAuthorization` for the operator account (`OA_MSGS_ECOSYSTEM`).
2. **Participant entries on the shared ECS schemas** (operator-signed, agent account as `vs_operator`):
   - `ISSUER` on the ECS *Service* schema (self-created, OPEN).
   - `HOLDER` on the ECS *Organization* schema (`StartParticipantOP`, validated by `ecs-org-issuer`).
3. **ECS credentials**: Organization credential (issued by `ecs-org-issuer` after validation of the agent's `ECS_CLAIMS_ORG_*`) and Service credential (self-issued by the agent against its Service `ISSUER` entry).
4. **DPP Ecosystem** + **DPP credential schema** + **root participant** (ECOSYSTEM role, dpp-vs DID). The agent then publishes the schema's VTJSC in its DID document.

### 6.2 DPP credential schema — first draft: `passport/`

The first draft already exists in this repo under `passport/`, authored for **Papapo** (barefoot children's footwear). It becomes the DPP Ecosystem's credential schema. The schema is explicitly a *voluntary* DPP — not an EU ESPR-compliant DPP until a footwear/textiles delegated act exists (schema `description`).

**Files:**

| File | Role |
|---|---|
| `passport/papapo-product-passport.schema.json` | **Canonical schema, single location** (`PapapoProductPassport`, `$id: https://papapo.shoes/verana/schemas/papapo-product-passport/v1`). Read in place by the deployment via `$PASSPORT_SCHEMA_FILE` (§5.4) — never copied to `dpp-vs/`. |
| `passport/papapo-product-passport.example.json` | Full example `credentialSubject` at `model` level (stone colorway, EU sizes 24–26). |
| `passport/papapo-product-passport.min.schema.json` | Minimal variant (`additionalProperties: true`, reduced `required`) for issuance testing / fallback. |
| `passport/papapo-product-passport.min.example.json` | Minimal example. |

**Schema summary** (already in the verana-demos shape: top-level `type: object`, `required: ["credentialSubject"]`, claims under `credentialSubject`):

- **Granularity** — `passportLevel: model | variant | instance`. Colour lives once at product level (one passport per colourway, `color`); size lives on `variants[]` at model level, or as singular `size`/`gtin`/`sku`/`variantId` at variant/instance level. Conditional `allOf`/`if`/`then` rules enforce this (model ⇒ `color`+`variants`, no singular fields; variant ⇒ `color`+`size`; instance ⇒ + `serialNumber`).
- **Identity** — `id` (subject DID/URI), `type: "PapapoProductPassport"` (const), `productId`/`variantId` (Medusa ids), GTIN pattern `^([0-9]{8}|[0-9]{12}|[0-9]{13}|[0-9]{14})$`, `productName`, `model`, `category`, `intendedUse`.
- **Required claims (full schema)** — `id`, `type`, `passportLevel`, `productName`, `materials`, `manufacturer`, `brandOwner`, `countryOfOrigin`, `passportUri`.
- **Materials & actors** — `materials[]` per shoe part (`upper`, `lining`, `insole`, `outsole`, …) with `description`, `composition`, `recycledContentPercent`; `manufacturer{name, countryCode, registryId?}` and `brandOwner{name, countryCode, website?}`; `countryOfOrigin` (ISO 3166-1 alpha-2).
- **Lifecycle links** — `careUri`, `repairUri`, `endOfLifeUri`, `passportUri`, `imageUri`, each with an optional `*DigestSri` companion; `batchOrLot`, `serialNumber`, `manufacturedAt`.
- **Discovery claims & privacy** — `claims[]` enum (`barefoot`, `wide_toe_box`, `zero_drop`, `flexible_sole`, `children`, `leather_free`, `handmade`, `other`; non-regulatory, for filtering only) and free-text `notes` which **MUST NOT contain personal data of customers or children** (schema `description`). `additionalProperties: false` on the full schema.

**Validation status (2026-10-21, local `jsonschema` check):**

- ✅ `papapo-product-passport.example.json` validates against the full schema.
- ✅ `papapo-product-passport.min.example.json` validates against the min schema.
- ✅ The full example also validates against the min schema; the min example correctly **fails** the full schema (missing `materials`/`manufacturer`/`brandOwner`).

**Agent compatibility status (2026-10-21, tested with the agent's own validator — AJV 2020, `schemaViolations` in vs-agent `setupSelfTr.ts`):**

- ❌ **Full schema as-is fails on the agent's claims-validation path.** The agent compiles *only* the `credentialSubject` subschema (`ajv.compile(schema.properties.credentialSubject)` — vt-flow `assertClaims` and the OpenID4VC offer validation both do this), so the top-level `$defs` (`gtin`, `sizeSystem`, `variantEntry`) are out of scope: `COMPILE FAILED: can't resolve reference #/$defs/variantEntry from id #`. The full schema compiles fine as a whole document — chain-level storage would likely succeed — but *issuing or validating passport claims with it would throw*. 
- ✅ **Min schema passes both paths** (agent subschema compile and full-document compile, examples valid). It inlines its patterns and has no `$refs`.
- ✅ **Full schema with `$defs` inlined passes both paths** (verified by simulation: every `#/$defs/*` reference expanded inline, `$defs` dropped — agent-path compile OK, example valid, and a negative test with `passportLevel: model` + a singular `gtin` correctly fails). Semantics are unchanged; only the representation changes.

**D4 resolution — schema variant (locked 2026-10-21):**

1. **Refactor the full schema before deployment** (still in the single file `passport/papapo-product-passport.schema.json`, no copy): inline the `#/$defs/*` definitions (or move them under `credentialSubject.$defs` and re-point the references) so the `credentialSubject` subschema is self-contained. Keep titles, `type` const, required sets, and conditionals identical.
2. **Use the refactored full schema as the on-chain v1 schema.** The min schema is *not* deployed; it stays in `passport/` as a test fixture and emergency fallback (`PASSPORT_SCHEMA_FILE` one-line switch, §5.4) if the chain itself — not the agent — rejects the full document at `create_credential_schema` time. That devnet submission remains a Phase 4 gate: if it fails, deploy the min schema, record the exact chain error, and treat fixing the full schema as a follow-up schema creation under the same ecosystem.
3. **Re-run both AJV paths as a regression test** after the refactor (positive: both examples; negative: `model` + singular `gtin` must fail) — add this as a small script/CI check in Phase 2 so future `passport/` edits can't silently break agent compatibility again.

**D4 resolution — `$id` (locked 2026-10-21):**

- **Keep `$id: https://papapo.shoes/verana/schemas/papapo-product-passport/v1` unchanged.** Code inspection shows the Verana flow does not dereference it: `create_credential_schema` stores the JSON document itself, the agent's `readJsonSchema` reads only `title`/`description`/`credentialSubject` properties, and the VTJSC points at the schema via `vpr:verana:<chain-id>:cs:<schemaId>` (see `common/vt-schema` in verana-demos), not via `$id`. AJV only uses `$id` as an identifier when compiling the full document, and there are no external `$ref`s to resolve.
- Therefore **no hosting action is required for the devnet deployment**, and no other repo/website needs modifying for `$id`. Publishing the schema JSON at that Papapo URL is a production/interoperability follow-up (external JSON-Schema tooling may dereference `$id`); if the schema's semantics ever change, bump `$id` to `…/v2` — never silently change content under an existing `$id`.

**Remaining Phase 2 tasks:**

- [ ] Apply the `$defs`-inlining refactor to `passport/papapo-product-passport.schema.json` and add the two-path AJV regression check (above).
- [ ] **Add the material-lot join key to `materials[]` before the schema is deployed** (on-chain schemas are immutable): a `materialId` / `materialLotId` (and optionally `supplierId` and evidence-credential references). Today `materials[]` only carries `part`/`description`/`composition`/`recycledContentPercent`, so a product passport can *assert* composition in text but cannot be machine-joined to a supplier's lot credential — see §6.4.
- [ ] Replace placeholder data in examples before any real issuance (example GTINs `7701234567890…`, `materials[].composition: "TBD"`, Medusa ids `prod_01EXAMPLE`/`variant_01EX*`).
- [ ] Decide AnonCreds support (decision D7). The standalone agent creates no cred-def, but a later DPP issuer will need one — and AnonCreds' flat attribute model does not natively carry nested objects/arrays such as `materials[]`, `variants[]`, `manufacturer{}`. If AnonCreds issuance is required, design a flattened companion schema/encoding; W3C/VTJSC (JSON-schema) credentials carry the nested draft natively.

### 6.3 Governance document (EGF) — D5 locked: minimal DPP EGF, Release-asset hosting

- [ ] Write a **minimal DPP EGF** (D5 Proposal 2): a short, brand- and product-agnostic governance document for the DPP Ecosystem — purpose/scope (demo status explicit), operator (D2 identity), participant roles and onboarding, brand admission (Papapo first), schema governance (proposal/versioning/deprecation for the multi-schema roadmap), **per-schema ISSUER accreditation categories** (e.g. suppliers may issue material declarations, ISO 17025-accredited labs may issue test attestations — see §6.4), data-quality and no-personal-data rules, revocation/suspension, and the EGF change process.
- [ ] **Hosting (locked): GitHub Release asset in this repo (`demo-dpp`) only** — do not require changes to another repo (e.g. a governance-docs or website repo), and do not use GitHub Pages or raw/tag URLs. Keep the EGF source (Markdown/LaTeX) in `egf/` in this repo so the PDF is reproducible; attach the built PDF to a release tagged e.g. `egf-v1` and set `EGF_DOC_URL="https://github.com/verana-labs/demo-dpp/releases/download/egf-v1/dpp-ecosystem-egf-v1.pdf"`. (This replaces the demos' `https://verana-labs.github.io/governance-docs/EGF/example.pdf`.)
- [ ] **Immutability discipline:** never replace an asset on an existing release — its SHA-384 SRI digest is recorded on-chain at Corporation/ecosystem creation. Corrections ship as a new release (`egf-v2`, new URL) plus an on-chain update. Rejected: Proposal 1 (reuse the Example EGF — governs the wrong ecosystem) as the permanent value (acceptable only as a temporary bootstrap placeholder), and Proposal 3 (full Council Template-EGF — pre-incorporation DRAFT 0.1, weeks of work; the minimal EGF may adopt its headings so it can grow into it).

### 6.4 Credential issuance roadmap — start with the brand's self-issued passport

**Phase ordering (decided 2026-10-21):**

1. **First credential in the ecosystem: the brand's self-issued `ProductPassport`.** Papapo (as the first brand) issues one ProductPassport credential per product (Medusa product / colourway, `passportLevel: model`), with the product as subject identified by a stable URI (e.g. `https://papapo.shoes/passport/…` — no product DID; products are passive subjects and hold no keys, §6.2). Papapo's agent is both issuer and holder. These are **self-attested** claims (identity, colourway, variants/GTINs, materials as text, lifecycle links) — the correct starting point, and the weakest trust level by construction.
2. **Later: third-party credentials about the same subjects/materials.** Independent issuers accredited by the ecosystem root under the EGF (§6.3), each on its **own schema** under the same DPP Ecosystem. The canonical first case (below) is a material supplier's lot-level compliance credential, followed by lab test attestations, factory manufacturing attestations, and repair/end-of-life lifecycle credentials. The ecosystem operator (`dpp-vs`) accredits these issuers; it does not itself issue product claims.

**The batch/material model — one credential covering many products (REACH leather example):**

The unit of issuance for supply-chain credentials is the **material lot**, not the product. A leather supplier issues a single MaterialCompliance credential per leather lot, and every product built from that lot references it:

```json
{
  "credentialSubject": {
    "id": "https://supplier.example/materials/leather-lot-2026-014",
    "type": "MaterialComplianceCredential",
    "materialType": "leather",
    "composition": "100% bovine leather, chrome-free tanning",
    "standard": "REACH Regulation (EC) No 1907/2006",
    "complianceStatus": "compliant",
    "svhcAboveThreshold": false,
    "testReportUri": "https://supplier.example/reports/lot-2026-014.pdf",
    "testReportDigestSri": "sha384-…",
    "validFrom": "2026-01-15",
    "validUntil": "2027-01-15"
  }
}
```

| Credential (future schemas) | Issuer (third party) | Subject | Holder |
|---|---|---|---|
| MaterialCompliance | Material supplier (per lot) | Material lot URI | Every brand using that lot |
| TestAttestation | Accredited test lab (per report) | Material lot / test report | Brand, supplier |
| ManufacturingAttestation | Contract factory (per batch) | Production batch | Brand |
| Repair / End-of-life credentials | Repairer / recycler (per event) | Product instance URI | Brand / owner |

**The join:** a ProductPassport must reference the lot (`materials[].materialLotId`), and verifiers join passport → lot credential → test report by that shared identifier, checking each issuer's accreditation on its own schema. This is why the `materialLotId` field is a *Phase 2, pre-deployment* schema change (§6.2) even though supplier issuance is a later phase: the on-chain schema is immutable, and without the join key the passport can only assert composition as free text.

**Scope choice for supplier credentials:** per **material lot** (recommended — matches how REACH testing works, precise revocation), per material type/SKU over a validity window (weaker, assumes process stability), or per facility/annual declaration (weakest, background only).

**Trust caveats to state in the EGF:** (a) a supplier credential is a *declaration* — the lab's test attestation about the same lot is the stronger, independent evidence; (b) legal responsibility under REACH stays with the brand/importer placing the product on the EU market — third-party credentials are verifiable supporting evidence, not a transfer of liability.

**Independent third parties are not operator services:** unlike the demos' children (services of one organization joining its Corporation), a real supplier/lab/factory is its own organization with its own agent/DID. The DPP operator's role is limited to validating its ISSUER participation against the relevant schema under the EGF — it neither holds the third party's keys nor issues in its name. Operator-hosted issuer services remain appropriate for brand passports issued *on behalf of* a brand only where the brand's own DID signs (or the delegation is explicitly accredited and visible to verifiers).

---

## 7. Secrets and accounts

Two **new, distinct, funded** devnet accounts. Add as **repository secrets** in `verana-labs/demo-dpp` (Settings → Secrets and variables → Actions → *Repository secrets* — not Environment secrets; the job declares no `environment`):

| GitHub secret (this repo) | Content | Used by |
|---|---|---|
| `KUBECONFIG_VERANA_DEV` | Kubeconfig for the target cluster | Workflow → `~/.kube/config` |
| `K8S_NAMESPACE` | `demo-dpp` (D6 locked — dedicated namespace, §10) | Helm + K8s secret creation |
| `DPP_VS_MNEMONIC` | Corporation operator mnemonic | Workflow only (`veranad` signing). **Never mounted into the agent pod.** |
| `DPP_VS_AGENT_MNEMONIC` | Agent account mnemonic | Workflow (Participant provisioning) + agent pod via K8s secret |

Rename consistently in 3 places: the workflow (`secrets.*` refs, K8s-secret creation), `dpp-vs/deployment.yaml` (`secretKeyRef`), and `dpp-vs/config.env` (account *names* only).

Behaviour inherited from the demos, to keep:

- The workflow auto-creates the K8s secret `dpp-vs-secrets` from the GitHub secrets if absent. **Rotation caveat:** because creation is `get … || create`, changing a GitHub secret does *not* update an existing K8s secret — delete it and re-run `deploy`.
- The demos put *both* mnemonics in the K8s secret even though the pod only mounts the agent key. **Improvement to make in DPP:** store only `DPP_VS_AGENT_MNEMONIC` in the cluster secret; keep the operator mnemonic solely in GitHub.
- Fund both accounts before the first run (faucet: `https://faucet.devnet.verana.network` or `common/faucet-fund.sh devnet`, max 50 VNA/account/hour). Generate with `veranad keys add dpp-vs-devnet-admin|dpp-vs-devnet-agent --keyring-backend test` and back the mnemonics up outside GitHub — GitHub never displays them again.
- No other secrets needed for Phase 1–4. `DOCKER_HUB_LOGIN`/`DOCKER_HUB_PWD` only become necessary when building app images (Phase 6). `CORPORATION_ID`, ECS DID, RPC/indexer URLs are **not** secrets.

---

## 8. Implementation phases

### Phase 0 — Prerequisites & decisions
- [ ] No open decisions block this phase: D1 (domain, §3.1), D2 (organization, §10), D3 (service identity, §10), D4 (schema + `$id`, §6.2), D5 (EGF, §6.3) and D6 (dedicated namespace `demo-dpp`, §10) are all locked. D7 (AnonCreds) is deferred to Phase 6 by design.
- [ ] **Verify namespace RBAC with the `KUBECONFIG_VERANA_DEV` kubeconfig** (store it outside any repo, `chmod 600`; never commit or echo it). Point `KUBECONFIG` at it, confirm `kubectl config current-context`, then:

  ```bash
  # 1) Cluster-scoped gate: may this identity create the dedicated namespace?
  kubectl auth can-i create namespaces                    # want: yes
  kubectl create namespace demo-dpp --dry-run=server -o name   # want: namespace/demo-dpp (creates nothing)

  # 2) Namespaced gate: may Helm + the workflow operate inside demo-dpp?
  for r in deployments statefulsets services ingresses secrets persistentvolumeclaims configmaps; do
    printf '%-25s %s\n' "$r" "$(kubectl auth can-i create $r -n demo-dpp)"   # want: all yes
  done
  kubectl auth can-i patch deployments -n demo-dpp        # want: yes (helm upgrade)
  kubectl auth can-i create pods/portforward -n demo-dpp  # want: yes (Admin API access)
  kubectl auth can-i get pods/log -n demo-dpp             # want: yes (debugging)
  ```

  | Outcome | Action |
  |---|---|
  | All `yes` | Proceed — the workflow self-creates `demo-dpp` on first `deploy`; set `K8S_NAMESPACE="demo-dpp"` (§7). |
  | `create namespaces` = `no` | A cluster admin pre-creates `demo-dpp` once **and** grants the step-2 permissions via a Role/RoleBinding in it; then re-run step 2 (must be all `yes`). |
  | Step 2 partly `no` after pre-creation | Admin grants the missing verbs/resources in `demo-dpp`; re-run step 2. |
  | No local copy of the kubeconfig | GitHub secrets are write-only — get the file from whoever set `KUBECONFIG_VERANA_DEV`, or (last resort) print these `can-i` results from a throwaway Actions run in this repo. Never print the kubeconfig itself. |

- [ ] Confirm cluster, storage class (`kubectl get storageclass csi-cinder-high-speed`), ingress class and cert-manager issuer (existence only; `Forbidden` just means no cluster-scope read — an admin can confirm), DNS + cert-manager for `*.dpp.demos.devnet.verana.network` (D1 naming: hosts under `dpp.demos.devnet.verana.network`).
- [ ] Confirm `ecs-ecosystem` + `ecs-org-issuer` are live on devnet (check ECS Ecosystem DID endpoint).
- [ ] Create + fund the two accounts; add the 4 repository secrets (§7).

**Exit criteria:** RBAC checks above all `yes` (directly or after the one-time admin pre-creation), secrets present, DNS resolves to the ingress, ECS endpoints answer.

### Phase 1 — Scaffold repository
- [ ] Copy `common/`, create `dpp-vs/` + workflow per §5 (content TBDs left as explicit placeholders).
- [ ] Local dry check: `./dpp-vs/scripts/setup.sh` against devnet with local mnemonics (optional but recommended before first CI run).

**Exit criteria:** repo layout of §4 exists; `setup.sh` reaches a running agent locally or the workflow parses (`step=deploy` not yet run is fine).

### Phase 2 — DPP content
- [ ] Adopt `passport/` as the DPP schema draft (§6.2): point `$PASSPORT_SCHEMA_FILE` at the full schema (no copy anywhere), replace example placeholder data, test chain/agent acceptance (fallback: point the same variable at the min schema).
- [ ] Produce the EGF per D5 (§6.3): write the minimal DPP EGF source in `egf/`, build the PDF, publish it as the `egf-v1` GitHub Release asset in this repo, and set `EGF_DOC_URL` to the release-asset URL (verify the digest computes with `curl -sfL`). Apply the locked organization (D2) and service (D3) claims identically in `config.env` + `deployment.yaml`.

**Exit criteria:** identities are exactly `Verana DPP Example Organization` (org) and `DPP Ecosystem (demo)` (service) — no `Verana Example Ecosystem` service identity or `example` schema/EGF references remain; both `passport/` examples validate against their schemas; the chosen schema is accepted by `create_credential_schema` on devnet.

### Phase 3 — Workflow adaptation
- [ ] Apply §5.6 changes; rename `create-example-ecosystem` → `create-dpp-ecosystem`; update workflow summary URLs to the DPP host.

**Exit criteria:** workflow YAML valid; a `bootstrap-corporation`-only run on `vs/devnet-dpp` prints a `CORPORATION_ID`.

### Phase 4 — First deployment
Runbook (from branch `vs/devnet-dpp`, Actions → `1_ Deploy DPP VS`):
1. [ ] Run `step=all`. Expected chain: bootstrap → (re-resolve) → deploy → validate ECS onboarding → create DPP ecosystem.
2. [ ] Commit the printed `CORPORATION_ID` into `dpp-vs/config.env` (`CORPORATION_ID="${CORPORATION_ID:-<id>}"`).
3. [ ] Verify (§9). If the chain is later wiped, empty `CORPORATION_ID` again and re-run `step=all` (the workflow detects a missing Corporation, but a stale committed ID makes `bootstrap-corporation` fail its "already set" path — same caveat as the demos).

**Exit criteria:** all §9 checks pass; DPP agent visible in Verana Search (devnet).

### Phase 5 — Hardening & docs
- [ ] README: architecture, runbook, secret-rotation procedure, recovery from chain wipe.
- [ ] Decide wallet/storage backup expectations for the agent PVC; document that losing the wallet changes the `did:webvh` SCID and invalidates Participant entries.
- [ ] (Optional) Split workflows so routine `deploy`-only runs don't require the operator mnemonic.

### Phase 6 — Extensions (deferred, separate plans)
- [ ] **First issuance use case — the brand's self-issued ProductPassport (§6.4, step 1).** Delegated DPP issuers (web and/or chatbot) — **one per brand**, Papapo first — and verifier(s), cloned from verana-demos workflows 2–5, onboarding against the **DPP schema** (issuers: `StartParticipantOP(ISSUER)`; verifiers: self-create OPEN) + AnonCreds cred-def if required. The brand's own DID signs its passports (one credential per product/colourway, product = URI subject, brand agent = issuer + holder); the ecosystem operator issues no product credentials. Brands are participants of the shared ecosystem; none of them is the ecosystem operator (see §3).
- [ ] **Third-party credential schemas (§6.4, step 2):** design the MaterialCompliance schema (supplier-issued, **one credential per material lot** covering every product using that lot — REACH leather case), then TestAttestation (accredited labs) and ManufacturingAttestation (factories), each as its own schema under the DPP `ECOSYSTEM_ID` with its own root participant. Onboard each third party as an *independent organization* (its own agent/DID; the operator only validates its ISSUER participation per the EGF's per-schema accreditation categories) — do not model real third parties as operator-hosted children. Verifier/presentation flows join passport → lot credential → test evidence via `materials[].materialLotId`.
- [ ] Additional product schemas: for each new product, add its credential schema under the existing DPP `ECOSYSTEM_ID` (`create_credential_schema` + `create_root_participant` per schema) — the ecosystem, `dpp-vs` agent, and Corporation are reused unchanged. Schema-specific issuers/verifiers onboard against that schema's root participant. The demos code assumes one custom schema per ecosystem (single `CUSTOM_SCHEMA_ID`, single-schema discovery), so this step includes generalising schema handling to a per-schema config (name → schema file → base ID).
- [ ] Playground-style front-end tying issuer/verifier together.
- [ ] Testnet promotion (branch `vs/testnet-dpp`) — note ECS Organization onboarding validation must then be performed from the `verana-deploy` cluster, as on testnet the issuer is not reachable from the demos cluster.

---

## 9. Verification checklist

```bash
# Agent DID document (public)
curl -s https://dpp-vs.dpp.demos.devnet.verana.network/.well-known/did.json | jq

# Health and DID via port-forwarded Admin API (no admin ingress by design)
kubectl port-forward -n demo-dpp svc/dpp 3000:3000
curl -s http://localhost:3000/v2/agent/health/live
curl -s http://localhost:3000/v2/agent/info | jq .did

# Trust resolution: trusted? which ECS credentials? which participations?
curl -s -X POST https://idx.devnet.verana.network/v4/verifiable-trust/resolve \
  -H 'Content-Type: application/json' \
  -d '{"did":"<agent did>","ecsCredentials":true}' | jq
```

Plus UI checks:
- [ ] Agent/service appears in [Verana Search — devnet](https://search.devnet.verana.network) (Services / Ecosystems / Corporations) with the DPP `SERVICE_NAME`.
- [ ] DPP Ecosystem + schema + root participant visible via the indexer/Graph API ([graph.devnet docs](https://graph.devnet.verana.network/docs)).
- [ ] GitHub Actions summary shows the correct DPP host, network, and `CORPORATION_ID`.

---

## 10. Open decisions

| # | Decision | Default / recommendation | Needed by |
|---|---|---|---|
| D1 | Domain scheme | ✅ **Resolved 2026-10-21 — Proposal 1 (demos-native):** `dpp-vs.dpp.demos.devnet.verana.network` (testnet: `…demos.testnet…`). Proposals 2 (literal `*.dpp.demos.verana.network`) and 3 (network-first) rejected — see §3.1 | — |
| D2 | Legal entity behind the DPP Organization credential (name, kind, country, registry ID/URI, address) | ✅ **Resolved 2026-10-21 — Proposal 2 (Verana as neutral operator), name-only change:** `ORG_NAME="Verana DPP Example Organization"`; all other `ORG_*` claims inherited unchanged from `organization-vs` (PUBLIC / CH / `CH-CHE-123.456.789` / zefix / Zurich address / verana.io logo) in both `config.env` and `deployment.yaml` (`ECS_CLAIMS_ORG_NAME`). ❌ Proposal 1 (Papapo as operator) rejected — ecosystem is multi-brand, Papapo is first participating brand only. ❌ Proposal 3 (fictional consortium) rejected — fabricated registry identity. Caveat: this is devnet/demo identity; a public testnet presentation claiming a real operator must replace the whole `ORG_*` set with real legal data together. | — |
| D3 | `SERVICE_NAME` / description / logo URI (Graph Search-visible identity) | ✅ **Resolved 2026-10-21:** `SERVICE_NAME="DPP Ecosystem (demo)"`, `SERVICE_TYPE="WEB_PORTAL"`, `SERVICE_DESCRIPTION="Multi-brand, multi-product Digital Product Passport ecosystem"`, logo inherited (`https://verana.io/logo.svg`). ❌ Proposal 2 (`Verana DPP Example Ecosystem`) rejected — "Example" branding does not scale as brands/schemas accumulate. ❌ Proposal 3 (`Footwear DPP Ecosystem`) rejected — product-agnostic ecosystem, footwear is only schema #1. Note: renaming the service later means re-issuing the Service credential and updating everything displaying the DIDComm label. | — |
| D4 | DPP schema + `$id` (§6.2) | ✅ **Fully resolved 2026-10-21.** (a) *Variant:* refactor the full `passport/` schema first — inline the `#/$defs/*` definitions so the `credentialSubject` subschema is self-contained (agent AJV test proved the as-is full schema fails claims validation with `can't resolve reference #/$defs/…`, while the inlined form and the min schema pass both compile paths) — then deploy the **refactored full schema** as on-chain v1. Min schema = undeployed test fixture / emergency fallback only; devnet `create_credential_schema` acceptance of the full document is a Phase 4 gate. (b) *`$id`:* keep `https://papapo.shoes/verana/schemas/papapo-product-passport/v1` unchanged — the Verana chain/agent flow never dereferences it (schema is referenced on-chain as `vpr:verana:<chain>:cs:<id>`), so no hosting or other-repo change is needed for devnet; publishing at that URL is a production follow-up, and any semantic change bumps `$id` to `…/v2`. | Phase 2 |
| D5 | EGF document | ✅ **Resolved 2026-10-21 — Proposal 2 + same-repo Release hosting:** write a minimal, brand/product-agnostic DPP EGF; source in `demo-dpp/egf/`, PDF published as a GitHub Release asset in `demo-dpp` (tag `egf-v1`), `EGF_DOC_URL` pointing at the release asset. Never overwrite a release asset (digest is on-chain); corrections = new release + on-chain update. ❌ Proposal 1 (reuse Example EGF) rejected as permanent value (temporary bootstrap placeholder only); ❌ Proposal 3 (full Council Template-EGF) rejected for now (DRAFT 0.1, overkill) — minimal EGF may follow its headings as an upgrade path | Phase 2 |
| D6 | K8s namespace | ✅ **Resolved 2026-10-21 — Proposal 2 (dedicated namespace):** `K8S_NAMESPACE="demo-dpp"` in this repo's secrets, same cluster/kubeconfig as verana-demos. Gated by the Phase 0 RBAC verification (workflow self-creates the namespace if `kubectl auth can-i create namespaces` is `yes`; otherwise an admin pre-creates `demo-dpp` once with the required RoleBinding). ❌ Proposal 1 (reuse verana-demos namespace) rejected — shared blast radius incl. the wallet PVC. ❌ Proposal 3 (namespace per environment) rejected — the workflows use one static `K8S_NAMESPACE` secret; a later namespace move would strand the wallet PVC (new DID, re-onboarding). | Phase 0 |
| D7 | AnonCreds required for DPP credentials? Nested `passport/` claims (`materials[]`, `variants[]`, `manufacturer{}`) do not map natively to AnonCreds' flat attributes | Default: W3C/VTJSC format for the nested draft; design a flattened AnonCreds companion only if AnonCreds issuance becomes a requirement | Phase 6 |

---

## 11. Risks and caveats (inherited from the pattern)

- **Chain wipes (devnet):** committed `CORPORATION_ID` and `did:webvh` SCIDs go stale. Recovery = empty `CORPORATION_ID`, fresh `step=all`, re-onboard any children. Credentials issued before a wipe do not migrate.
- **Single-operator blast radius:** the operator mnemonic can archive the ecosystem and revoke participants. Keep it out of the cluster (see §7 improvement) and consider a separate operator account per network.
- **`common.sh` drift:** vendored copy will diverge from verana-demos upstream; schedule deliberate re-syncs with diff review.
- **Admin API exposure:** never publish an admin ingress — the agent authenticates by TCP peer address and the ingress controller sits inside the trusted pod CIDR, so an admin ingress would serve the Admin API unauthenticated.
- **ECS dependency:** the shared `ecs-ecosystem`/`ecs-org-issuer` must be deployed and reachable on the target network before Phase 4; its DID changes on wallet wipes, which is why it is always resolved live.
- **DPP schema complexity:** the full `passport/` draft uses JSON Schema 2020-12 features the demos' flat `example` schema does not (`$defs`/`$ref`, `allOf`/`if`/`then`, `pattern`, `additionalProperties: false`, nested arrays/objects). Agent-side, this is now understood and resolved (D4, §6.2): the `$defs` must be inlined or the agent's `credentialSubject`-only AJV compile throws at issuance time — covered by a two-path regression check. Chain-side, on-chain `MsgCreateCredentialSchema` acceptance of the full document is still only proven by submitting it — hence the Phase 4 gate with the min schema as the staged fallback. See also D7 (AnonCreds flatness).

---

## 12. References

- `passport/` in this repo — DPP schema first draft (§6.2): `papapo-product-passport.schema.json` (+ `.min.` variant and examples).
- [`verana-demos` README](https://github.com/verana-labs/verana-demos) — architecture, workflow order, ingress rules, local development.
- `verana-demos/.github/workflows/1_deploy-organization-vs.yml` — the workflow this plan adapts.
- `verana-demos/common/common.sh` — shared provisioning helpers.
- [`verana-labs/verana-deploy`](https://github.com/verana-labs/verana-deploy) — the shared `ecs-ecosystem` and `ecs-org-issuer`.
- [`verana-labs/vs-agent`](https://github.com/verana-labs/vs-agent) — the agent (v2 Admin API, `ECS_CLAIMS_*` configuration).
- [Verana Search (devnet)](https://search.devnet.verana.network) · [Trust Graph API (devnet)](https://graph.devnet.verana.network/docs) · [Indexer trust resolution](https://idx.devnet.verana.network)
