defmodule MerklePatriciaTrie.DB.ETS do
  @moduledoc """
  Implementation of MerklePatriciaTrie.DB which
  is backed by :ets.

  TODO: Test
  """

  alias MerklePatriciaTrie.Trie

  @behaviour MerklePatriciaTrie.DB

  @doc """
  Performs initialization for this db.

  TODO: Test
  """
  @spec init() :: :ok
  def init() do
    :ets.new(__MODULE__, [:set, :public, :named_table])
  end

  @doc """
  Pulls a key out of ets, if it exists.
  """
  @spec get(key :: Trie.key) :: {:ok, binary()} | :not_found
  def get(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key,v}|_rest] -> {:ok, v}
      _ -> :not_found
    end
  end

  @doc """
  Pulls a key out of ets, if it exists, or raises if not.
  """
  @spec get!(key :: Trie.key) :: binary()
  def get!(key) do
    case get(key) do
      {:ok, value} -> value
    end
  end

  @doc """
  Puts a key into :ets.
  """
  @spec put!(key :: Trie.key, binary()) :: :ok
  def put!(key, value) do
    case :ets.insert(__MODULE__, {key, value}) do
      true -> :ok
    end
  end
end