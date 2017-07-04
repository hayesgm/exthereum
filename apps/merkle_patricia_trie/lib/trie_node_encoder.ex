defmodule MerklePatriciaTrie.Trie.NodeEncoder do
  alias MerklePatriciaTrie.Trie
  alias MerklePatriciaTrie.Trie.Storage

  # TODO: Doc spec and test

  def encode_node(trie_node, trie) do
    trie_node
    |> encode_node_type()
    |> RLP.encode()
    |> Storage.put_node(trie)
  end

  defp encode_node_type({:leaf, key, value}) do
    [HexPrefix.encode({key, true}), value]
  end

  defp encode_node_type({:branch, branches, _}) when length(branches) == 17 do
    branches
  end

  defp encode_node_type({:ext, shared_prefix, next_node}) do
    [HexPrefix.encode({shared_prefix, false}), next_node]
  end

  defp encode_node_type(:empty) do
    []
  end

  # TODO: Spec
  def decode_trie(node_hash, trie) do
    decode_trie(%{trie| root_hash: node_hash})
  end

  @spec decode_trie(Trie.Tree.t) :: Trie.trie_node
  def decode_trie(trie) do
    case Storage.get_node(trie) do
      [] -> :empty
      branches when length(branches) == 17 ->
        {:branch, branches, 2}
      [hp_k,v] ->
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