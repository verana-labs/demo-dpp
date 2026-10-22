# Digital Product Passport Ecosystem Governance Framework

| | |
|---|---|
| Version | 1.0 — Draft |
| Date | 21 October 2026 |
| Status | Draft for the development-network demonstration. This document must be reviewed before any production or public regulated use. |
| Ecosystem | DPP Ecosystem (demo) |
| Ecosystem operator (demonstration identity) | Verana DPP Example Organization |
| Network (first deployment) | Verana development network |
| Published form | Portable Document Format (PDF) file attached to the `egf-v1` release of the `verana-labs/demo-dpp` repository |

## 1. Purpose

This framework defines how participants join and operate in the Digital
Product Passport Ecosystem, which credential schemas may be used, and how
trust decisions are made. It is deliberately neutral: it favours neither a
brand, nor a product category, nor a technology vendor.

## 2. Scope and demonstration status

1. The ecosystem supports digital product passports and related evidence
   credentials (for example material compliance, test attestations,
   manufacturing attestations, repair records and end-of-life records) for
   multiple brands and multiple product categories.
2. This deployment is a **demonstration**. Credentials issued in the
   demonstration do not by themselves establish compliance with the European
   Union Ecodesign for Sustainable Products Regulation, any product-specific
   delegated act, the REACH Regulation, or any other law. Each brand or other
   issuer remains responsible for the legal accuracy of its own claims.
3. No credential issued under this framework may contain personal data about
   customers or children.

## 3. Roles

- **Ecosystem operator** — operates the ecosystem agent (`dpp-vs`), creates
  the ecosystem and its credential schemas, and holds the ecosystem root
  participant position. The operator also runs two services of its own under
  the same organisation: the Issuer grantor service and the verification
  service below. The operator does **not** issue product credentials and
  does not hold any participant's keys.
- **Issuer grantor service** — a service run by the ecosystem operator
  holding the issuer-grantor participant position for a credential schema.
  It receives onboarding requests from prospective issuers, checks them
  against the admission rules of section 4 (including the per-schema
  accreditation categories), and validates or rejects them. Granting is an
  accreditation decision only: the service issues no credentials and holds
  no issuer's keys.
- **Verification service** — a service run by the ecosystem operator holding
  a verifier participant position. It requests presentations and checks
  them as described in section 7. It is one verifier among potentially many;
  any other party may onboard as a verifier where the schema permits it.
- **Brand issuer** — a brand (or a service provider explicitly accredited to
  issue using the brand's own decentralised identifier) that issues product
  passport credentials for its own products. A brand is both issuer and
  holder of its passports; the product is the credential subject and is
  normally identified by a stable web address (no product-held keys).
- **Third-party issuer** — an independent organisation issuing evidence
  credentials within its competence, for example a material supplier issuing
  a compliance credential for a material lot, an accredited testing
  laboratory issuing a test attestation, a factory issuing a manufacturing
  attestation, or a repairer or recycler issuing a lifecycle record.
  Third-party issuers operate under their own identity and keys; the
  operator validates their participation but never issues in their name.
- **Verifier** — any party checking a presentation (for example a consumer
  application, retailer, marketplace, repairer or authority).
- **Holder** — the wallet or agent storing credentials, normally the brand's
  agent for brand-issued passports.

## 4. Participant admission

1. An applicant must control the decentralised identifier it registers and
   hold a valid Service credential for that identifier.
2. Onboarding requests for issuers are validated by the operator's Issuer
   grantor service for that schema (or, where no grantor service is
   designated, by the operator as root). Verifier participation may be open
   where a schema permits it.
3. Brand admission (first brand: Papapo) requires identifying the legal or
   trading identity behind the brand and the product categories it will
   issue for. Admission of one brand confers no rights over any other brand.
4. Issuer accreditation is **per credential schema**. Being an issuer for one
   schema grants no rights on another.
5. Third-party issuer accreditation follows the category for that schema:
   - material declarations: the material supplier itself;
   - test attestations: a laboratory accredited for the relevant test scope
     (for example under ISO/IEC 17025);
   - manufacturing attestations: the factory that produced the batch.
6. The operator may refuse, suspend or revoke participation where claims are
   false, evidence is missing, keys are compromised, or this framework is
   violated. Suspension and revocation are effective for future trust
   decisions; previously issued credentials are handled under section 9.

## 5. Credential schemas

1. Schemas are admitted per product or evidence type; one ecosystem may host
   many schemas (for example one product passport schema per product family,
   one material compliance schema, one test attestation schema).
2. A schema proposal must state its purpose, the claims it carries, which
   issuer categories may use it, and how its claims can be evidenced.
3. Published schemas are immutable. A change to meaning requires a new
   version, identified in the schema identifier (for example `…/v1` to
   `…/v2`). Silent replacement of schema content under an existing
   identifier is prohibited.
4. The operator may deprecate a schema. Deprecation stops new onboarding and
   must state how existing credentials are treated.
5. First schema admitted: the Papapo product passport schema (source in the
   `passport/` directory of the demonstration repository), initially used by
   Papapo for self-issued product passports.

## 6. Data quality and evidence

1. Issuers sign only claims they can support. Self-issued brand claims (for
   example intended use or marketing claims) are acceptable where the schema
   marks them as such, and verifiers may display them as self-attested.
2. Regulated or measurable claims should be supported by evidence
   credentials from the competent third party (section 4.5), linked by
   shared identifiers — for example a product passport's material entry
   carries the material lot identifier that the supplier's compliance
   credential and the laboratory's test attestation are about.
3. External documents referenced by credentials (care, repair, test reports)
   should be referenced together with a content digest, so a verifier can
   confirm the document has not changed.
4. One evidence credential may cover many products where its subject is the
   shared thing — for example one material compliance credential per
   material lot covers every product manufactured from that lot.

## 7. Presentation and verification

A verifier should check, at minimum: the issuer's signature; that the issuer
holds an active issuer participation for the credential's schema in this
ecosystem; the credential's validity period and revocation status; and,
where an evidence chain is presented, that the linked credentials share the
expected identifiers and that referenced document digests match.

## 8. Costs

The demonstration charges no ecosystem-level validation, issuance or
verification fees. Network transaction fees remain payable as configured in
the deployment. Any future change to this section requires a new version of
this framework (section 10).

## 9. Corrections, suspension and disputes

1. An issuer that discovers an error must revoke or supersede the affected
   credential and, where the error is material, notify the operator.
2. Participants may report false claims or misuse to the operator. Contact
   point: to be published with the demonstration (repository issue tracker
   for the duration of the demonstration).
3. The operator decides on suspension or revocation of participation after
   giving the participant an opportunity to respond, except where immediate
   action is needed to stop ongoing harm.

## 10. Changes to this framework

Changes are published as a new version of this document at a new, permanent
address (a new release of the demonstration repository), and the ecosystem
record is updated to the new address and content digest. Earlier versions
remain available at their original addresses. Changing the file at an
existing address without a new version is prohibited.

## Appendix A — Initial participants and schemas (demonstration)

| Item | Initial value |
|---|---|
| Ecosystem operator | `dpp-vs` agent acting for "Verana DPP Example Organization" |
| First brand issuer | Papapo (self-issued product passports; footwear) |
| First credential schema | Papapo product passport (see section 5.5) |
| Future schema families | Material compliance, test attestation, manufacturing attestation, repair and end-of-life records |
