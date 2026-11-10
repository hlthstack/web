# hlthstack PWA SSO: build the `message` and `auth_tag` form fields (Ruby 2.7+, standard library only).
#
# Run:  HLTHSTACK_ENCODED_KEY=... HLTHSTACK_ENCODED_IV=... HLTHSTACK_ENTITY_ID=... ruby encrypt.rb
# Prints {"message": "...", "auth_tag": "..."} as JSON.
require 'openssl'
require 'base64'
require 'json'

module HlthstackSso
  # Encrypt an SSO payload with AES-256-GCM and return { 'message' => ..., 'auth_tag' => ... }.
  def self.build_sso_params(payload, encoded_key, encoded_iv)
    key = Base64.decode64(encoded_key)
    raise ArgumentError, 'encoded_key must decode to 32 bytes' unless key.bytesize == 32

    cipher = OpenSSL::Cipher.new('aes-256-gcm')
    cipher.encrypt
    cipher.key = key
    cipher.iv = Base64.decode64(encoded_iv)
    ciphertext = cipher.update(JSON.generate(payload)) + cipher.final

    { 'message' => Base64.urlsafe_encode64(ciphertext), 'auth_tag' => Base64.urlsafe_encode64(cipher.auth_tag) }
  end
end

if $PROGRAM_NAME == __FILE__
  payload = {
    entity_id: ENV.fetch('HLTHSTACK_ENTITY_ID'),
    email: 'jane.doe@example.com',
    member_id: 'EMP-0001',
    first_name: 'Jane',
    last_name: 'Doe',
    gender: 'F',
    deeplink: 'benefits',
    requested_at: Time.now.to_i # Unix time in SECONDS, set right before launch
  }
  puts JSON.generate(HlthstackSso.build_sso_params(payload, ENV.fetch('HLTHSTACK_ENCODED_KEY'),
                                                   ENV.fetch('HLTHSTACK_ENCODED_IV')))
end
