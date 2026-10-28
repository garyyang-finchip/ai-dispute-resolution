#!/usr/bin/env node
'use strict';
// Validates every worked example against the JSON Schemas of the assets and re-checks the manifest hashes.
//
//   node tools/validate.js

const fs = require('fs');
const path = require('path');
const Ajv = require('ajv/dist/2020');
const addFormats = require('ajv-formats');
const C = require('./lib/canonical');
const L = require('./lib/adrf');

const ROOT = path.join(__dirname, '..');
const SCHEMAS = path.join(ROOT, 'assets', 'erc-adrf', 'schemas');
const EX = path.join(ROOT, 'assets', 'erc-adrf', 'examples');

const ajv = new Ajv({ strict: false, allErrors: true });
addFormats(ajv);
for (const f of fs.readdirSync(SCHEMAS)) {
  const s = JSON.parse(fs.readFileSync(path.join(SCHEMAS, f), 'utf8'));
  ajv.addSchema(s, f);
}

const byKind = {
  'adrf-policy': 'policy.schema.json',
  'adrf-binding': 'binding.schema.json',
  'adrf-case': 'case.schema.json',
  'adrf-finding': 'finding.schema.json',
  'adrf-ruling': 'ruling.schema.json',
  'adrf-enactment': 'enactment.schema.json',
};

let failures = 0;
let count = 0;
const manifest = JSON.parse(fs.readFileSync(path.join(EX, 'manifest.json'), 'utf8'));
for (const f of fs.readdirSync(EX).filter((x) => x.endsWith('.json') && x !== 'manifest.json').sort()) {
  const doc = JSON.parse(fs.readFileSync(path.join(EX, f), 'utf8'));
  const schema = byKind[doc.kind];
  if (!schema) { failures++; console.log(`FAIL ${f}: unknown kind ${doc.kind}`); continue; }
  const ok = ajv.validate(schema, doc);
  count++;
  if (!ok) {
    failures++;
    console.log(`FAIL ${f}`);
    for (const e of ajv.errors) console.log(`   ${e.instancePath || '/'} ${e.message}`);
  }
  const entry = manifest.files[f];
  if (!entry) { failures++; console.log(`FAIL ${f}: not in manifest`); continue; }
  if (C.canonicalHash(doc) !== entry.contentHash) { failures++; console.log(`FAIL manifest contentHash of ${f}`); }
}

// the policy document and the economic declaration are bound into the spec; the spec hashes to the policy id
const policyDoc = JSON.parse(fs.readFileSync(path.join(EX, 'policy-service-call.json'), 'utf8'));
if (C.canonicalHash(policyDoc) !== manifest.policySpec.descriptorHash) { failures++; console.log('FAIL policySpec.descriptorHash'); }
if (C.canonicalHash(policyDoc.economicDeclaration) !== manifest.policySpec.economicDeclaration) { failures++; console.log('FAIL policySpec.economicDeclaration'); }
if (L.policyId(manifest.policySpec) !== manifest.policyId) { failures++; console.log('FAIL policyId'); }
const bindingDoc = JSON.parse(fs.readFileSync(path.join(EX, 'binding-service-escrow.json'), 'utf8'));
if (C.canonicalHash(bindingDoc) !== manifest.termsHash) { failures++; console.log('FAIL termsHash'); }
if (bindingDoc.policyId !== manifest.policyId) { failures++; console.log('FAIL binding policyId'); }
for (const f of ['case-duplicate-charge.json', 'case-delivery-quality.json']) {
  const doc = JSON.parse(fs.readFileSync(path.join(EX, f), 'utf8'));
  if (doc.rules.policyId !== manifest.policyId) { failures++; console.log(`FAIL ${f} policyId`); }
  if (manifest.caseDocumentHashes[f] !== C.canonicalHash(doc)) { failures++; console.log(`FAIL ${f} documentHash`); }
}

console.log(`validated ${count} example documents against ${Object.keys(byKind).length} schemas; manifest re-checked; ${failures} failure(s)`);
process.exit(failures ? 1 : 0);
