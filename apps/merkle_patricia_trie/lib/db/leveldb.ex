defmodule MerklePatriciaTrie.DB.LevelDB do
  @moduledoc """
  Implementation of MerklePatriciaTrie.DB which
  is backed by leveldb.

  TODO: db name / ref etc.
  """

  alias MerklePatriciaTrie.Trie

  alias MerklePatriciaTrie.DB
  @behaviour MerklePatriciaTrie.DB

  @doc """
  Performs initialization for this db.
  """
  @spec init(DB.db_name) :: DB.db
  def init(db_name) do
    {:ok, db_ref} = Exleveldb.open(db_name, create_if_missing: true)

    {__MODULE__, db_ref}
  end

  @doc """
  Pulls a key out of leveldb, if it exists.
  """
  @spec get(DB.db, Trie.key) :: {:ok, DB.value} | :not_found
  def get({_, db_ref}, key) do
    case Exleveldb.get(db_ref, key) do
      {:ok, v} -> {:ok, v}
      :not_found -> :not_found
    end
  end

  @doc """
  Pulls a key out of leveldb, if it exists, or raises if not.
  """
  @spec get!(DB.db, Trie.key) :: DB.value
  def get!(db, key) do
    case get(db, key) do
      {:ok, value} -> value
      :not_found -> raise "cannot find key `#{key}`"
    end
  end

  @doc """
  Puts a key into leveldb.
  """
  @spec put!(DB.db, Trie.key, DB.value) :: :ok
  def put!({_, db_ref}, key, value) do
    case Exleveldb.put(db_ref, key, value) do
      :ok -> :ok
    end
  end
end