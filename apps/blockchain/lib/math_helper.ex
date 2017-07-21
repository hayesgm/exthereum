defmodule MathHelper do
  @moduledoc """
  Simple functions to help with common
  math functions.
  """

  @doc """
  Simple floor function that makes sure
  we return an integer type.

  ## Examples

      iex> MathHelper.floor(3.5)
      3

      iex> MathHelper.floor(-3.5)
      -4

      iex> MathHelper.floor(5)
      5
  """
  @spec floor(number()) :: integer()
  def floor(x), do: round(:math.floor(x))
end