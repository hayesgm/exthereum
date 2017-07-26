defmodule MerklePatriciaTrie.Trie do
  @moduledoc """
  The modified patricia merkle trie allows arbitrary storage of
  key, value pairs with the benefits of a merkle trie in O(n*log(n))
  time for insert, lookup and delete.

  For further inforamtion, please read the Yellow Paper spec:
  https://ethereum.github.io/yellowpaper/paper.pdf (Appendix D)
  """

  alias MerklePatriciaTrie.Trie.Helper
  alias MerklePatriciaTrie.Trie.Builder
  alias MerklePatriciaTrie.Trie.Node
  alias MerklePatriciaTrie.DB
  alias MerklePatriciaTrie.ListHelper

  defstruct [db: nil, root_hash: nil]

  @type t :: %__MODULE__{
    db: DB.db,
    root_hash: EVM.trie_root,
  }

  @type key :: <<_::32>>

  @doc """
  Contructs a new unitialized trie.

  ## Examples

    iex> MerklePatriciaTrie.Trie.new(MerklePatriciaTrie.Test.random_ets_db(:trie_test_1))
    %MerklePatriciaTrie.Trie{db: {MerklePatriciaTrie.DB.ETS, :trie_test_1}, root_hash: nil}

    iex> MerklePatriciaTrie.Trie.new(MerklePatriciaTrie.Test.random_ets_db(:trie_test_2), <<1, 2, 3>>)
    %MerklePatriciaTrie.Trie{db: {MerklePatriciaTrie.DB.ETS, :trie_test_2}, root_hash: <<1, 2, 3>>}

    iex> MerklePatriciaTrie.Trie.new(MerklePatriciaTrie.DB.LevelDB.init("/tmp/#{MerklePatriciaTrie.Test.random_string(20)}"), <<1, 2, 3>>)
    %MerklePatriciaTrie.Trie{db: {MerklePatriciaTrie.DB.LevelDB, ""}, root_hash: <<1, 2, 3>>}
  """
  @spec new(DB.db, EVM.trie_root | nil) :: __MODULE__.t
  def new(db={_, _}, root_hash \\ nil) do
    %__MODULE__{db: db, root_hash: root_hash}
  end

  @doc """
  Moves trie down to be rooted at `next_node`,
  this is effectively (and literally) just changing
  the root_hash to `node_hash`.
  """
  def into(next_node, trie) do
    %{trie| root_hash: next_node}
  end

  @doc """
  Given a trie, returns the value associated with key.
  """
  @spec get(__MODULE__.t, __MODULE__.key) :: {:ok, binary()} | :not_found
  def get(trie, key) do
    do_get(trie, Helper.get_nibbles(key))
  end

  defp do_get(nil, _), do: nil
  defp do_get(trie, nibbles=[nibble| rest]) do
    # Let's decode `c(I, i)`

    case Node.decode_trie(trie) do
      :empty -> nil # no node, bail
      {:branch, branches} ->
        # branch node
        case Enum.at(branches, nibble) do
          [] -> nil
          node_hash -> node_hash |> into(trie) |> do_get(rest)
        end
      {:leaf, prefix, value} ->
        # leaf, value is second value if match first
        case nibbles do
          ^prefix -> value
          _ -> nil
        end
      {:ext, shared_prefix, next_node} ->
        # extension, continue walking tree if we match
        case ListHelper.get_postfix(nibbles, shared_prefix) do
          nil -> nil # did not match extension node
          rest -> next_node |> into(trie) |> do_get(rest)
        end
    end
  end

  defp do_get(trie, []) do
    # Only branch nodes can have values for a nil lookup
    case Node.decode_trie(trie) do
      {:branch, branches} -> List.last(branches)
      {:leaf, [], v} -> v
      _ -> nil
    end
  end

  @doc """
  Updates a trie by setting key equal to value.
  """
  @spec update(__MODULE__.t, __MODULE__.key, RLP.t) :: __MODULE__.t
  def update(trie, key, value) do
    # We're going to recursively walk toward our key,
    # then we'll add our value (either a new leaf or the value
    # on a branch node), then we'll walk back up the tree and
    # update all previous ndes. This may require changing the
    # type of the node.
    Node.decode_trie(trie)
    |> Builder.put_key(Helper.get_nibbles(key), value, trie)
    |> Node.encode_node(trie)
    |> into(trie)
  end

end
