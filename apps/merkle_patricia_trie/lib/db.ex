defmodule MerklePatriciaTrie.DB do
  @callback get(key :: MerklePatriciaTrie.Trie.key) :: {:ok, binary()} | :not_found
  @callback get!(key :: MerklePatriciaTrie.Trie.key) :: binary()
  @callback put!(key :: MerklePatriciaTrie.Trie.key, binary()) :: :ok

  @type t :: module()
end