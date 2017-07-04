defmodule MerklePatriciaTrie.Trie.Helper do
  alias MerklePatriciaTrie.Trie.NodeEncoder
  require Logger

  # TODO: Test

  # Returns nibbles of a given key
  def get_nibbles(k), do: (for <<nibble::4 <- k>>, do: nibble)

  def inspect_trie(trie) do
    IO.puts("~~~Tree~~~")
    IO.puts(do_inspect_trie(trie, 0))
    IO.puts("~~~/Tree/~~~\n")

    trie
  end

  defp do_inspect_trie(trie, depth, prefix \\ "") do
    whitespace = if depth > 0, do: for _ <- 1..(2*depth), do: " ", else: ""
    trie_node = NodeEncoder.decode_trie(trie)
    node_info = inspect_trie_node(trie_node, trie, depth)
    "#{whitespace}#{prefix}Node: #{node_info}"
  end

  defp inspect_trie_node(:empty, _trie, _depth) do
    "<empty>"
  end

  defp inspect_trie_node({:leaf, k, v}, _trie, _depth) do
    "leaf (#{k |> inspect}=#{v |> inspect})"
  end

  defp inspect_trie_node({:ext, shared_prefix, v}, trie, depth) do
    sub = do_inspect_trie(%{trie| root_hash: v}, depth + 1)

    "ext (prefix: #{shared_prefix |> inspect})\n#{sub}"
  end

  defp inspect_trie_node({:branch, branches, _i}, trie, depth) do
    base = "branch (value: #{List.last(branches) |> inspect})"

    Enum.reduce(0..15, base, fn (el, acc) ->
      acc <> "\n" <> do_inspect_trie(%{trie| root_hash: Enum.at(branches, el)}, depth + 1, "[#{el}] ")
    end)
  end

  def inspect(msg, prefix) do
    Logger.debug(inspect [prefix, ":", msg])

    msg
  end

  defmodule Verifier do

    # We can do more tests, this is going to be a starter
    def verify_well_formed(trie, dict) do
      values = for {_, v} <- dict, do: v

      do_verify_well_formed(trie, dict, values)
    end

    def do_verify_well_formed(trie, dict, values) do
      case trie |> NodeEncoder.decode_trie do
        :empty -> :ok
        {:leaf, k, v} ->
          if v == "" do
            {:error, "empty leaf value at #{inspect k}"}
          else
            if not Enum.member?(values, v) do
              {:error, "leaf value v does not appear in values (#{inspect v})"}
            else
              :ok
            end
          end
        {:branch, all_branches, _} ->
          {v, branches} = List.pop_at(all_branches, 16)

          branch_tries = for branch <- branches do
            %{trie|root_hash: branch}
          end

          branches_well_formed = for branch_trie <- branch_tries do
            do_verify_well_formed(branch_trie, dict, values)
          end

          not_okay_branches = Enum.filter(branches_well_formed, &(&1 != :ok))

          if Enum.count(not_okay_branches) > 0 do
            {:error, "malformed branches: #{inspect not_okay_branches}"}
          else
            # All branches are technically okay, let's verify that

            # Let's verify we have at least one non-empty branch
            if Enum.count(branches, &(&1 != <<192>>)) < 2 do
              {:error, "branch with only zero or one exits"}
            else
              # also check the value is okay
              if v != <<192>> and not Enum.member?(values, v) do
                {:error, "branch value v does not appear in values (#{inspect v})"}
              else
                :ok
              end
            end
          end
        {:ext, shared_prefix, node_hash} ->
          if shared_prefix == [] do
            {:error, "empty shared prefix"}
          else
            do_verify_well_formed(%{trie|root_hash: node_hash}, dict, values)

            # TODO: Check we can't extend the ext?
          end
      end
    end
  end

end