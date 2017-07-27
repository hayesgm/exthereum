defmodule MerklePatriciaTrie.DB do
  @moduledoc """
  Defines a general key-value storage to back and persist
  out Merkle Patricia Trie. This is generally LevelDB in the
  community, but for testing, we'll generally use `:ets`.

  We define a callback that can be implemented by a number
  of potential backends.
  """
  defmodule KeyNotFoundError do
    defexception [:message]
  end

  @type t :: module()
  @type db_name :: any()
  @type db_ref :: any()
  @type db :: {t, db_ref}
  @type value :: binary()

  @callback init(db_name) :: {:ok, db}
  @callback get(db_ref, MerklePatriciaTrie.Trie.key) :: {:ok, value} | :not_found
  @callback put!(db_ref, MerklePatriciaTrie.Trie.key, value) :: :ok

  @doc """
  Retrieves a key from the database.

  ## Examples

      iex> db = MerklePatriciaTrie.Test.random_ets_db()
      iex> MerklePatriciaTrie.DB.get(db, "name")
      :not_found

      iex> db = MerklePatriciaTrie.Test.random_ets_db()
      iex> MerklePatriciaTrie.DB.put!(db, "name", "bob")
      iex> MerklePatriciaTrie.DB.get(db, "name")
      {:ok, "bob"}
  """
  @spec get(db, MerklePatriciaTrie.Trie.key) :: {:ok, value} | :not_found
  def get(_db={db_mod, db_ref}, key) do
    db_mod.get(db_ref, key)
  end

  @doc """
  Retrieves a key from the database, but raises if that key does not exist.

  ## Examples

      iex> db = MerklePatriciaTrie.Test.random_ets_db()
      iex> MerklePatriciaTrie.DB.get!(db, "name")
      ** (MerklePatriciaTrie.DB.KeyNotFoundError) cannot find key `name`

      iex> db = MerklePatriciaTrie.Test.random_ets_db()
      iex> MerklePatriciaTrie.DB.put!(db, "name", "bob")
      iex> MerklePatriciaTrie.DB.get!(db, "name")
      "bob"
  """
  @spec get!(db, MerklePatriciaTrie.Trie.key) :: value
  def get!(db, key) do
    case get(db, key) do
      {:ok, value} -> value
      :not_found -> raise KeyNotFoundError, message: "cannot find key `#{key}`"
    end
  end

  @doc """
  Stores a key in the database.

  ## Examples

      ## Examples

      iex> db = MerklePatriciaTrie.Test.random_ets_db()
      iex> MerklePatriciaTrie.DB.put!(db, "name", "bob")
      iex> MerklePatriciaTrie.DB.get(db, "name")
      {:ok, "bob"}
      iex> MerklePatriciaTrie.DB.put!(db, "name", "tom")
      iex> MerklePatriciaTrie.DB.get(db, "name")
      {:ok, "tom"}
  """
  @spec put!(db, MerklePatriciaTrie.Trie.key, value) :: :ok
  def put!(_db={db_mod, db_ref}, key, value) do
    db_mod.put!(db_ref, key, value)
  end

end