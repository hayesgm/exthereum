defmodule MerklePatriciaTrie.DB.ETS do
  @behaviour MerklePatriciaTrie.DB

  # TODO: Test
  @spec init() :: :ok
  def init() do
    :ets.new(__MODULE__, [:set, :public, :named_table])
  end

  @spec get(key :: MerklePatriciaTrie.Trie.key) :: {:ok, binary()} | :not_found
  def get(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key,v}|_rest] -> {:ok, v}
      _ -> :not_found
    end
  end

  @spec get!(key :: MerklePatriciaTrie.Trie.key) :: binary()
  def get!(key) do
    case get(key) do
      {:ok, value} -> value
    end
  end

  @callback put!(key :: MerklePatriciaTrie.Trie.key, binary()) :: :ok
  def put!(key, value) do
    case :ets.insert(__MODULE__, {key, value}) do
      true -> :ok
    end
  end
end