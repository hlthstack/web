"""hlthstack PWA SSO: build the `message` and `auth_tag` form fields (Python 3.8+).

Requires the `cryptography` package:  pip install cryptography

Run:  HLTHSTACK_ENCODED_KEY=... HLTHSTACK_ENCODED_IV=... HLTHSTACK_ENTITY_ID=... python encrypt.py
Prints {"message": "...", "auth_tag": "..."} as JSON.
"""
import base64
import json
import os
import time

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

TAG_LENGTH = 16  # AESGCM appends a 16-byte tag to the ciphertext


def build_sso_params(payload, encoded_key, encoded_iv):
    """Encrypt an SSO payload with AES-256-GCM and return {"message", "auth_tag"}."""
    key = base64.b64decode(encoded_key)
    iv = base64.b64decode(encoded_iv)
    if len(key) != 32:
        raise ValueError("encoded_key must decode to 32 bytes")

    sealed = AESGCM(key).encrypt(iv, json.dumps(payload).encode("utf-8"), None)
    ciphertext, tag = sealed[:-TAG_LENGTH], sealed[-TAG_LENGTH:]
    # URL-safe Base64 with padding, the same as Ruby's Base64.urlsafe_encode64.
    return {
        "message": base64.urlsafe_b64encode(ciphertext).decode("ascii"),
        "auth_tag": base64.urlsafe_b64encode(tag).decode("ascii"),
    }


if __name__ == "__main__":
    payload = {
        "entity_id": os.environ["HLTHSTACK_ENTITY_ID"],
        "email": "jane.doe@example.com",
        "member_id": "EMP-0001",
        "first_name": "Jane",
        "last_name": "Doe",
        "gender": "F",
        "deeplink": "benefits",
        "requested_at": int(time.time()),  # Unix time in SECONDS, set right before launch
    }
    params = build_sso_params(payload, os.environ["HLTHSTACK_ENCODED_KEY"], os.environ["HLTHSTACK_ENCODED_IV"])
    print(json.dumps(params))
