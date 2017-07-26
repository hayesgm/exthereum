defmodule MerklePatriciaTrie.DB.ETS do
  @moduledoc """
  Implementation of MerklePatriciaTrie.DB which
  is backed by :ets.

  """

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
  Pulls a key out of ets, if it exists.
  """
  @spec get(DB.db, Trie.key) :: {:ok, DB.value} | :not_found
  def get({_, db_ref}, key) do
    case :ets.lookup(db_ref, key) do
      [{^key,v}|_rest] -> {:ok, v}
      _ -> :not_found
    end
  end

  @doc """
  Pulls a key out of ets, if it exists, or raises if not.
  """
  @spec get!(DB.db, Trie.key) :: DB.value
  def get!(db, key) do
    case get(db, key) do
      {:ok, value} -> value
      :not_found -> raise "cannot find key `#{key}`"
    end
  end

  @doc """
  Puts a key into :ets.
  """
  @spec put!(DB.db, Trie.key, DB.value) :: :ok
  def put!({_, db_ref}, key, value) do
    case :ets.insert(db_ref, {key, value}) do
      true -> :ok
    end
  end
end