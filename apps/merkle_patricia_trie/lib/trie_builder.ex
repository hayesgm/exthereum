defmodule MerklePatriciaTrie.Trie.Builder do
  alias MerklePatriciaTrie.Trie.NodeEncoder
  alias MerklePatriciaTrie.Trie.Helper

  # TODO: Doc and spec
  # and thoroughly test

  def put_key(trie_node, key, value, trie) do
    trie_put_key(trie_node, key, value, trie)
  end

  # Merge into a leaf with identical key (overwrite)
  def trie_put_key({:leaf, old_prefix, _value}, new_prefix, new_value, trie) when old_prefix == new_prefix do
    {:leaf, new_prefix, new_value}
  end

  # Merge leafs that share some prefix, this will cause us to construct an extension followed by a branch
  def trie_put_key({:leaf, [old_prefix_hd|old_prefix_tl]=old_prefix, old_value}, [new_prefix_hd|new_prefix_tl]=new_prefix, new_value, trie) when old_prefix_hd == new_prefix_hd do
    {matching_prefix, old_tl, new_tl} = ListHelper.overlap(old_prefix, new_prefix)

    {:ext, matching_prefix, build_branch([{old_tl, old_value}, {new_tl, new_value}], trie) |> NodeEncoder.encode_node(trie)}
  end

  # Merge into a leaf with no matches (i.e. create a branch)
  def trie_put_key({:leaf, old_prefix, old_value}, new_prefix, new_value, trie) do
    build_branch([{old_prefix, old_value}, {new_prefix, new_value}], trie)
  end

  # Merge right onto an extension node, we'll need to push this down to our value
  def trie_put_key({:ext, shared_prefix, node_hash}, new_prefix, new_value, trie) when shared_prefix == new_prefix do
    {:ext, shared_prefix, NodeEncoder.decode_trie(node_hash, trie) |> put_key([], new_value, trie)}
  end

  # Merge leafs that share some prefix, this will cause us to construct an extension followed by a branch
  def trie_put_key({:ext, [old_prefix_hd|old_prefix_tl]=old_prefix, old_value}, [new_prefix_hd|new_prefix_tl]=new_prefix, new_value, trie) when old_prefix_hd == new_prefix_hd do
    {matching_prefix, old_tl, new_tl} = ListHelper.overlap(old_prefix, new_prefix)

    # TODO: Simplify logic?
    if old_tl == [] do
      # We are merging directly into an ext node (frustrating!)
      # Since ext nodes must be followed by branches, let's just merge
      # the new value into the branch
      {:ext, matching_prefix, put_key(old_value |> NodeEncoder.decode_trie(trie), new_tl, new_value, trie) |> NodeEncoder.encode_node(trie)}
    else
      # TODO: Handle when we need to add an extension after this
      # TODO: Standardize with below
      first = case old_tl do
        # [] -> {16, {:encoded, old_value}} # TODO: Is this right?
        [h|[]] -> {h, {:encoded, old_value}}
        [h|t] -> {h, {:encoded, {:ext, t, {:leaf, [], old_value} |> NodeEncoder.encode_node(trie)} |> NodeEncoder.encode_node(trie)}}
      end
      {:ext, matching_prefix, build_branch([first, {new_tl, new_value}], trie) |> NodeEncoder.encode_node(trie)}
    end
  end

  # Merge into a ext with no matches (i.e. create a branch)
  def trie_put_key({:ext, old_prefix, old_value}, new_prefix, new_value, trie) do
    # TODO: Standardize with above
    first = case old_prefix do
      # [] -> {16, {:encoded, old_value}} # TODO: Is this right?
      [h|[]] -> {h, {:encoded, old_value}}
      [h|t] -> {h, {:encoded, {:ext, t, old_value} |> NodeEncoder.encode_node(trie)}}
    end
    build_branch([first, {new_prefix, new_value}], trie)
  end

  # Merge into a branch with empty prefix to store branch value
  def trie_put_key({:branch, branches, _}, [], value, trie) when length(branches) == 17 do
    {:branch, List.replace_at(branches, 16, value), 5}
  end

  # Merge down a branch node (recursively)
  def trie_put_key({:branch, branches, _}, [prefix_hd|prefix_tl], value, trie) do
    {:branch,
      List.update_at(branches, prefix_hd, fn branch ->
        put_key(branch |> NodeEncoder.decode_trie(trie), prefix_tl, value, trie) |> NodeEncoder.encode_node(trie)
      end), 6
    }
  end

  # Merge into empty to create a leaf
  def trie_put_key(:empty, prefix, value, trie) do
    {:leaf, prefix, value}
  end

  # Builds a branch node with starter values
  def build_branch(branch_options, trie) do
    empty_branch = RLP.encode([])
    base = {:branch, (for _ <- 0..16, do: empty_branch), 1}

    Enum.reduce(branch_options, base,
        fn
          ({prefix, {:encoded, value}}, {:branch, branches, _}=acc) ->
            # IO.inspect(["putting encoded branch", acc, "prefix", prefix, "value", value, "trie", trie])
            {:branch, List.replace_at(branches, prefix, value), 7}

          ({prefix, value}, acc) ->
            # IO.inspect(["adding branch", acc, "prefix", prefix, "value", value, "trie", trie])
            put_key(acc, prefix, value, trie)
        end
    )
  end

end