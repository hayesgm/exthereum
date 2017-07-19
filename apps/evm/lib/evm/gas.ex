defmodule EVM.Gas do
  @moduledoc """
  Functions for interacting wth gas and costs of opscodes.
  """

  alias EVM.MachineState
  alias EVM.ExecEnv
  alias MerklePatriciaTrie.Trie

  @type t :: EVM.val
  @type gas_price :: EVM.Wei.t

  @doc """
  Returns the cost to execute the given ??.

  ## Examples

      # TODO: Figure out how to hand in state
      iex> EVM.Gas.cost(%{}, %EVM.MachineState{}, %EVM.ExecEnv{})
      0
  """
  @spec cost(Trie.t, MachineState.t, ExecEnv.t) :: t
  def cost(_state, _machine_state, _exec_env) do
    0
  end

  @doc """
  Returns the gas cost for G_txdata{zero, nonzero} as defined in
  Appendix G (Fee Schedule) of the Yellow Paper.

  This implements `g_txdatazero` and `g_txdatanonzero`

  ## Examples

      iex> EVM.Gas.g_txdata(<<1, 2, 3, 0, 4, 5>>)
      5 * 68 + 4

      iex> EVM.Gas.g_txdata(<<0>>)
      4

      iex> EVM.Gas.g_txdata(<<0, 0>>)
      8

      iex> EVM.Gas.g_txdata(<<>>)
      0
  """
  @spec g_txdata(binary()) :: t
  def g_txdata(data) do
    for <<byte <- data>> do
      case byte do
        0 -> 4
        _ -> 68
      end
    end |> Enum.sum
  end

  @doc "Paid by all contract-creating transactions after the Homestead transition."
  @spec g_txcreate() :: t
  def g_txcreate, do: 32000

  @doc "Paid for every transaction."
  @spec g_transaction() :: t
  def g_transaction, do: 21000

end
