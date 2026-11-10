# Round-trip check for the encryption examples.
#
# Runs each example with a FAKE test key/IV, then decrypts its output exactly the way the
# hlthstack backend does (AES-256-GCM, key/IV Base64-decoded, message and auth_tag URL-safe
# Base64-decoded, 30-second requested_at window). Also checks that both values survive the
# form POST -> 302 -> query-string hop unchanged, and that a tampered tag is rejected.
#
# Usage (from the repo root):  ruby examples/verify/verify.rb
# Set PYTHON to an interpreter that has `cryptography` installed (default: python3).
require 'openssl'
require 'base64'
require 'json'
require 'open3'

ROOT = File.expand_path('../..', __dir__)

# Clearly fake test values: they decode to "hlthstack-example-key-NOT-REAL!!" and "example-iv12".
TEST_ENV = {
  'HLTHSTACK_ENCODED_KEY' => 'aGx0aHN0YWNrLWV4YW1wbGUta2V5LU5PVC1SRUFMISE=',
  'HLTHSTACK_ENCODED_IV' => 'ZXhhbXBsZS1pdjEy',
  'HLTHSTACK_ENTITY_ID' => '1234'
}.freeze

EXPECTED = {
  'entity_id' => '1234', 'email' => 'jane.doe@example.com', 'member_id' => 'EMP-0001',
  'first_name' => 'Jane', 'last_name' => 'Doe', 'gender' => 'F', 'deeplink' => 'benefits'
}.freeze

EXAMPLES = {
  'node' => ['node', File.join(ROOT, 'examples/node/encrypt.js')],
  'python' => [ENV.fetch('PYTHON', 'python3'), File.join(ROOT, 'examples/python/encrypt.py')],
  'ruby' => ['ruby', File.join(ROOT, 'examples/ruby/encrypt.rb')],
  'java' => ['java', File.join(ROOT, 'examples/java/HlthstackSso.java')]
}.freeze

# Same steps as the backend's GCM decrypt.
def backend_decrypt(message, auth_tag)
  decipher = OpenSSL::Cipher.new('AES-256-GCM')
  decipher.decrypt
  decipher.key = Base64.decode64(TEST_ENV['HLTHSTACK_ENCODED_KEY'])
  decipher.iv = Base64.decode64(TEST_ENV['HLTHSTACK_ENCODED_IV'])
  decipher.auth_tag = Base64.urlsafe_decode64(auth_tag)
  decipher.update(Base64.urlsafe_decode64(message)) + decipher.final
end

def check(name, cmd)
  out, err, status = Open3.capture3(TEST_ENV, *cmd)
  return "command failed: #{err.strip}" unless status.success?

  params = JSON.parse(out.lines.last)
  message = params.fetch('message')
  auth_tag = params.fetch('auth_tag')

  # The values are relayed through a redirect query string and read back without decoding,
  # so they must use only the URL-safe Base64 alphabet.
  bad = [message, auth_tag].find { |v| v !~ /\A[A-Za-z0-9_=-]+\z/ }
  return "non URL-safe characters in #{bad.inspect}" if bad

  parsed = JSON.parse(backend_decrypt(message, auth_tag))
  diff = EXPECTED.reject { |k, v| parsed[k] == v }
  return "payload mismatch: #{diff.keys.join(', ')}" unless diff.empty?

  requested_at = parsed['requested_at']
  return 'requested_at must be an integer (seconds)' unless requested_at.is_a?(Integer)
  return 'request already expired (backend rejects after 30s)' if Time.at(requested_at) + 30 <= Time.now
  return 'requested_at looks like milliseconds' if requested_at > Time.now.to_i + 60

  tampered = Base64.urlsafe_encode64(Base64.urlsafe_decode64(auth_tag).bytes.tap { |b| b[0] ^= 1 }.pack('C*'))
  begin
    backend_decrypt(message, tampered)
    return 'tampered auth_tag was accepted'
  rescue OpenSSL::Cipher::CipherError
    # expected
  end

  nil
end

failures = 0
EXAMPLES.each do |name, cmd|
  error = check(name, cmd)
  failures += 1 if error
  puts format('%-7s %s', name, error ? "FAIL  #{error}" : 'OK    decrypted by backend logic, payload intact, tamper rejected')
end
exit(failures.zero? ? 0 : 1)
