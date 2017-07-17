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

end
