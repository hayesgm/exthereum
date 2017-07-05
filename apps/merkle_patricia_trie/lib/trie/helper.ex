defmodule MerklePatriciaTrie.Trie.Helper do
  @moduledoc """
  Functions to help with manipulating or working
  with tries.
  """
  require Logger

  @doc """
  Returns the nibbles of a given binary as a list

  ## Examples

  iex> MerklePatriciaTrie.Trie.Helper.get_nibbles(<<0x1e, 0x2f>>)
  [0x01, 0x0e, 0x02, 0x0f]

  iex> MerklePatriciaTrie.Trie.Helper.get_nibbles(<<0x1::4, 0x02::4, 0x03::4>>)
  [1, 2, 3]
  """
  @spec get_nibbles(<<>>) :: []
  def get_nibbles(k), do: (for <<nibble::4 <- k>>, do: nibble)

end