defmodule MerklePatriciaTrie.Trie.Inspector do
  @moduledoc """
  A simple module to inspect and print the structure
  of tries.

  TODO: Test
  """
  alias MerklePatriciaTrie.Trie
  alias MerklePatriciaTrie.Trie.Node
  require Logger

  @doc """
  Prints a visual depiction of a trie, returns trie itself.
  """
  @spec inspect_trie(Trie.t) :: Trie.t
  def inspect_trie(trie) do
    IO.puts("~~~Trie~~~")
    IO.puts(do_inspect_trie(trie, 0))
    IO.puts("~~~/Trie/~~~\n")

    trie
  end

  defp do_inspect_trie(trie, depth, prefix \\ "") do
    whitespace = if depth > 0, do: for _ <- 1..(2*depth), do: " ", else: ""
    trie_node = Node.decode_trie(trie)
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

  defp inspect_trie_node({:branch, branches}, trie, depth) do
    base = "branch (value: #{List.last(branches) |> inspect})"

    Enum.reduce(0..15, base, fn (el, acc) ->
      acc <> "\n" <> do_inspect_trie(%{trie| root_hash: Enum.at(branches, el)}, depth + 1, "[#{el}] ")
    end)
  end

  @doc """
  Helper function to print an instruction message.
  """
  def inspect(msg, prefix) do
    Logger.debug(inspect [prefix, ":", msg])

    msg
  end
end
