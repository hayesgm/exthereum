defmodule MerklePatriciaTrie.Trie.Node do
  @moduledoc """
  This module encode or decodes nodes from our
  trie form into RLP form. Effectively implements
  c(I, i) from http://gavwood.com/Paper.pdf.

  TODO: Test
  """

  alias MerklePatriciaTrie.Trie
  alias MerklePatriciaTrie.Trie.Storage

  @type trie_node ::
    :empty |
    {:leaf, binary(), binary()} |
    {:ext, binary(), binary()} |
    {:branch, [binary()]}

  @doc """
  Given a node, this function will encode the node
  and put the value to storage (for nodes that are
  greater than 32 bytes encoded).

  ## Examples

  iex> encode_node({:leaf, [5,6,7], "ok"})
  "abc"
  """
  @spec encode_node(trie_node, Trie.t) :: nil | binary()
  def encode_node(trie_node, trie) do
    trie_node
    |> encode_node_type()
    |> RLP.encode()
    |> Storage.put_node(trie)
  end

  defp encode_node_type({:leaf, key, value}) do
    [HexPrefix.encode({key, true}), value]
  end

  defp encode_node_type({:branch, branches}) when length(branches) == 17 do
    branches
  end

  defp encode_node_type({:ext, shared_prefix, next_node}) do
    [HexPrefix.encode({shared_prefix, false}), next_node]
  end

  defp encode_node_type(:empty) do
    <<>>
  end

  @doc """
  Decodes the root of a given trie, effectively
  undoing the encoding of c(I, i).

  ## Examples

  iex> MerklePatriciaTrie.Trie.Node.decode_trie(trie)
  {:leaf, [5,6,7], "ok"}
  """
  @spec decode_trie(Trie.Tree.t) :: trie_node
  def decode_trie(trie) do
    case Storage.get_node(trie) do
      nil -> :empty # TODO: Should this be here, either?
      [] -> :empty # TODO: I think we should remove this.
      <<>> -> :empty
      branches when length(branches) == 17 ->
        {:branch, branches}
      [hp_k, v] ->
        # extension or leaf node
        {prefix, is_leaf} = HexPrefix.decode(hp_k)

        if is_leaf do
          {:leaf, prefix, v}
        else
          {:ext, prefix, v}
        end
      end
  end
end