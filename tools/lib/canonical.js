'use strict';
// JCS (RFC 8785) canonicalization and Keccak-256 content hashes of the ADRF documents.
const canonicalize = require('canonicalize');
const { keccak256, toUtf8Bytes } = require('ethers');

function canonicalString(doc) {
  return canonicalize(doc);
}

function canonicalHash(doc) {
  return keccak256(toUtf8Bytes(canonicalString(doc)));
}

module.exports = { canonicalString, canonicalHash };
