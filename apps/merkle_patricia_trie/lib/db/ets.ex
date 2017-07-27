defmodule MerklePatriciaTrie.DB.ETS do
  @moduledoc """
  Implementation of `MerklePatriciaTrie.DB` which
  is backed by :ets.
  """

  alias MerklePatriciaTrie.DB
  alias MerklePatriciaTrie.Trie

  @behaviour MerklePatriciaTrie.DB

  @doc """
  Performs initialization for this db.
  """
  @spec init(DB.db_name) :: DB.db
  def init(db_name) do
    :ets.new(db_name, [:set, :public, :named_table])

    {__MODULE__, db_name}
  end

  @doc """
  Retrieves a key from the database.
  """
  @spec get(DB.db_ref, Trie.key) :: {:ok, DB.value} | :not_found
  def get(db_ref, key) do
    case :ets.lookup(db_ref, key) do
      [{^key,v}|_rest] -> {:ok, v}
      _ -> :not_found
    end
  end

  @doc """
  Stores a key in the database.
  """
  @spec put!(DB.db_ref, Trie.key, DB.value) :: :ok
  def put!(db_ref, key, value) do
    case :ets.insert(db_ref, {key, value}) do
      true -> :ok
    end
  end
end