defmodule MerklePatriciaTrie.DB do
  @type t :: module()
  @type db_name :: any()
  @type db_ref :: any()
  @type db :: {t, db_ref}
  @type value :: binary()

  @callback init(db_name) :: {:ok, db_ref}
  @callback get(db_ref, MerklePatriciaTrie.Trie.key) :: {:ok, value} | :not_found
  @callback get!(db_ref, MerklePatriciaTrie.Trie.key) :: value
  @callback put!(db_ref, MerklePatriciaTrie.Trie.key, value) :: :ok
end