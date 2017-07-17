defmodule EVM do
  @moduledoc """
  Documentation for EVM.
  """

  @type state :: Trie.t
  @type trie_root :: <<_::256>>
  @type val :: integer()
  @type address :: <<_::160>>
  @type hash :: <<_::256>>
  @type timestamp :: integer()

  @max_int round(:math.pow(2, 256))

  @doc """
  Returns maximum allowed integer size.
  """
  def max_int(), do: @max_int

  @doc """
  Hello world.

  ## Examples

      iex> EVM.hello
      :world

  """
  def hello do
    :world
  end
end
