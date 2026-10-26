require "openssl"
require "base64"

module Messengerr
  # AES-256-GCM encryption. Encrypted payload is base64(iv + ciphertext + tag).
  module Crypto
    CIPHER = "aes-256-gcm"
    IV_LENGTH = 12
    TAG_LENGTH = 16

    def self.encrypt(plaintext, key)
      cipher = OpenSSL::Cipher.new(CIPHER).encrypt
      cipher.key = key
      iv = cipher.random_iv
      ciphertext = cipher.update(plaintext) + cipher.final
      Base64.strict_encode64(iv + ciphertext + cipher.auth_tag)
    end

    def self.decrypt(payload, key)
      data = Base64.strict_decode64(payload)
      iv, rest = data[0, IV_LENGTH], data[IV_LENGTH..]
      ciphertext, tag = rest[0...-TAG_LENGTH], rest[-TAG_LENGTH..]

      cipher = OpenSSL::Cipher.new(CIPHER).decrypt
      cipher.key = key
      cipher.iv = iv
      cipher.auth_tag = tag
      cipher.auth_data = ""
      cipher.update(ciphertext) + cipher.final
    rescue ArgumentError, OpenSSL::Cipher::CipherError
      raise CredentialsError, "credentials could not be decrypted — master key is missing or incorrect"
    end
  end
end
