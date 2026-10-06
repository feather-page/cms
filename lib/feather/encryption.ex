defmodule Feather.Encryption do
  @moduledoc """
  AES-256-GCM encryption for secrets stored in the database.

  The key is `config :feather, :config_encryption_key`, 32 bytes encoded as
  base64 (env `CONFIG_ENCRYPTION_KEY` in production). The stored format is
  `version (1 byte) <> iv (12 bytes) <> tag (16 bytes) <> ciphertext`.
  """

  @version 1
  @aad "feather-config-v1"
  @iv_size 12
  @tag_size 16

  @doc """
  Encrypts a binary.
  """
  @spec encrypt(binary()) :: binary()
  def encrypt(plaintext) when is_binary(plaintext) do
    iv = :crypto.strong_rand_bytes(@iv_size)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key(), iv, plaintext, @aad, @tag_size, true)

    <<@version, iv::binary, tag::binary, ciphertext::binary>>
  end

  @doc """
  Decrypts a binary produced by `encrypt/1`.
  """
  @spec decrypt(binary()) :: {:ok, binary()} | :error
  def decrypt(
        <<@version, iv::binary-size(@iv_size), tag::binary-size(@tag_size), ciphertext::binary>>
      ) do
    case :crypto.crypto_one_time_aead(:aes_256_gcm, key(), iv, ciphertext, @aad, tag, false) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      :error -> :error
    end
  end

  def decrypt(_other), do: :error

  defp key do
    encoded =
      Application.get_env(:feather, :config_encryption_key) ||
        raise "config :feather, :config_encryption_key is not set"

    case Base.decode64(encoded) do
      {:ok, <<key::binary-size(32)>>} -> key
      _ -> raise "config :feather, :config_encryption_key must be 32 bytes encoded as base64"
    end
  end
end
