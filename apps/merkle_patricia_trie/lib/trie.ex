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

  defmodule Tree do
    defstruct [db: nil, root_hash: nil]

    @type t :: %Tree{
      db: any(),
      root_hash: any(),
    }
  end

  @type key :: <<_::32>>

  @doc """
  Contructs a new trie.

  ## Examples

    iex> MerklePatriciaTrie.Trie.new(db: :ets)
    %MerklePatriciaTrie.Trie{}
  """
  @spec new([]) :: __MODULE__.Tree.t
  def new(opts \\ []) do
    db = case opts[:db] do
      :ets -> MerklePatriciaTrie.DB.ETS
      _ -> MerklePatriciaTrie.DB.ETS
    end

    %__MODULE__.Tree{db: db, root_hash: opts[:root_hash]}
  end

  @doc """
  Given a trie, returns the value associated with key.
  """
  @spec get(__MODULE__.Tree.t, __MODULE__.key) :: {:ok, binary()} | :not_found
  def get(trie, key) do
    do_get(trie, Helper.get_nibbles(key))
  end

  defp do_get(nil, _), do: nil
  defp do_get(trie, nibbles=[nibble| rest]) do
    # Let's decode c(I, i)

    case Node.decode_trie(trie) do
      :empty -> nil # no node, bail
      {:branch, branches, _} ->
        # branch node
        case Enum.at(branches, nibble) do
          [] -> nil
          node_hash -> do_get(%{trie| root_hash: node_hash}, rest)
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
          rest -> do_get(%{trie| root_hash: next_node}, rest)
        end
    end
  end

  defp do_get(trie, []) do
    # Only branch nodes can have values for a nil lookup
    case Node.decode_trie(trie) do
      {:branch, branches, _} -> List.last(branches)
      {:leaf, [], v} -> v # TODO: Add a test for this
      _ -> nil
    end
  end

  @doc """
  Updates a trie by setting key equal to value
  """
  @spec update(__MODULE__.Tree.t, __MODULE__.key, RLP.t) :: :ok
  def update(trie, key, value) do
    # We're going to recursively walk toward our key,
    # then we'll add our value (either a new leaf or the value
    # on a branch node), then we'll walk back up the tree and
    # update all previous ndes. This may require changing the
    # type of the node.

    node_hash = Node.decode_trie(trie)
    |> Builder.put_key(Helper.get_nibbles(key), value, trie)
    |> Node.encode_node(trie)

    %{trie|root_hash: node_hash}
  end

end
