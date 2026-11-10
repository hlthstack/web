// hlthstack PWA SSO: build the `message` and `auth_tag` form fields (Node.js >= 16, no dependencies).
//
// Run:  HLTHSTACK_ENCODED_KEY=... HLTHSTACK_ENCODED_IV=... HLTHSTACK_ENTITY_ID=... node encrypt.js
// Prints {"message": "...", "auth_tag": "..."} as JSON.
'use strict';

const crypto = require('crypto');

// URL-safe Base64 with padding (RFC 4648 section 5), the same as Ruby's Base64.urlsafe_encode64.
function urlsafeBase64(buf) {
  return buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_');
}

/**
 * Encrypt an SSO payload with AES-256-GCM.
 * @param {object} payload      the user payload (see README, "Payload")
 * @param {string} encodedKey   Base64 key issued by hlthstack (32 bytes once decoded)
 * @param {string} encodedIv    Base64 IV issued by hlthstack
 * @returns {{message: string, auth_tag: string}}
 */
function buildSsoParams(payload, encodedKey, encodedIv) {
  const key = Buffer.from(encodedKey, 'base64');
  const iv = Buffer.from(encodedIv, 'base64');
  if (key.length !== 32) throw new Error('encoded_key must decode to 32 bytes');

  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv); // 16-byte auth tag by default
  const ciphertext = Buffer.concat([cipher.update(JSON.stringify(payload), 'utf8'), cipher.final()]);
  return { message: urlsafeBase64(ciphertext), auth_tag: urlsafeBase64(cipher.getAuthTag()) };
}

module.exports = { buildSsoParams };

if (require.main === module) {
  const payload = {
    entity_id: process.env.HLTHSTACK_ENTITY_ID,
    email: 'jane.doe@example.com',
    member_id: 'EMP-0001',
    first_name: 'Jane',
    last_name: 'Doe',
    gender: 'F',
    deeplink: 'benefits',
    requested_at: Math.floor(Date.now() / 1000), // Unix time in SECONDS, set right before launch
  };
  const params = buildSsoParams(payload, process.env.HLTHSTACK_ENCODED_KEY, process.env.HLTHSTACK_ENCODED_IV);
  process.stdout.write(JSON.stringify(params) + '\n');
}
