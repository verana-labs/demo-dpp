#!/usr/bin/env node
/**
 * Regression checks for the passport schemas.
 *
 * The vs-agent validates claims by compiling ONLY the credentialSubject
 * subschema (AJV 2020, `schemaViolations` in vs-agent's setupSelfTr.ts), so a
 * schema whose credentialSubject references top-level $defs compiles as a
 * whole document but throws at issuance time. This script therefore checks
 * BOTH compile paths, exactly as the agent exercises them:
 *
 *   1. full-document compile        — what generic JSON Schema tooling does
 *   2. credentialSubject-only compile — what the vs-agent does with claims
 *
 * Run: npm install && npm run validate   (in this directory)
 */
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import Ajv2020 from 'ajv/dist/2020.js'
import addFormats from 'ajv-formats'

const here = dirname(fileURLToPath(import.meta.url))
const load = (name) => JSON.parse(readFileSync(join(here, name), 'utf8'))

const full = load('papapo-product-passport.schema.json')
const fullExample = load('papapo-product-passport.example.json')
const min = load('papapo-product-passport.min.schema.json')
const minExample = load('papapo-product-passport.min.example.json')

let failures = 0
const check = (label, fn) => {
  try {
    fn()
    console.log(`OK   ${label}`)
  } catch (error) {
    failures += 1
    console.error(`FAIL ${label}: ${error.message}`)
  }
}
const assert = (condition, message) => {
  if (!condition) throw new Error(message)
}
const newAjv = () => {
  const ajv = new Ajv2020({ strict: false, allErrors: true })
  addFormats(ajv)
  return ajv
}

// The full schema must be self-contained: no $ref may survive the inlining
// refactor, or the agent's credentialSubject-only compile breaks again.
check('full schema contains no $ref (self-contained credentialSubject)', () => {
  assert(!JSON.stringify(full).includes('"$ref"'), 'found a $ref in the full schema')
})

for (const [name, schema, example] of [
  ['full', full, fullExample],
  ['min', min, minExample],
]) {
  check(`${name}: full-document compile validates its example`, () => {
    const validate = newAjv().compile(schema)
    assert(validate(example), JSON.stringify(validate.errors?.slice(0, 3)))
  })
  check(`${name}: credentialSubject-only compile (agent path) validates its example`, () => {
    const validate = newAjv().compile(schema.properties.credentialSubject)
    assert(
      validate(structuredClone(example.credentialSubject)),
      JSON.stringify(validate.errors?.slice(0, 3)),
    )
  })
}

check('full example also validates against the min schema', () => {
  const validate = newAjv().compile(min)
  assert(validate(structuredClone(fullExample)), JSON.stringify(validate.errors?.slice(0, 3)))
})

check('min example fails the full schema (missing required claims)', () => {
  const validate = newAjv().compile(full)
  assert(!validate(structuredClone(minExample)), 'min example unexpectedly valid against full schema')
})

check('negative: model-level passport with a singular gtin is rejected (full)', () => {
  const bad = structuredClone(fullExample)
  bad.credentialSubject.gtin = '7701234567890'
  const validate = newAjv().compile(full)
  assert(!validate(bad), 'model + gtin unexpectedly valid')
})

check('example demonstrates the material-lot join key (materials[].materialLotId)', () => {
  const lots = (fullExample.credentialSubject.materials ?? []).map((m) => m.materialLotId)
  assert(lots.some(Boolean), 'no materials[].materialLotId in the full example')
})

if (failures > 0) {
  console.error(`\n${failures} check(s) failed`)
  process.exit(1)
}
console.log('\nAll passport schema checks passed')
