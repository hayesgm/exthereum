defmodule EVM.VM do
  @moduledoc """
  The core of the EVM which runs operations based on the
  opcodes of a contract during a transfer or message call.
  """

  alias EVM.SubState
  alias EVM.MachineState
  alias EVM.ExecEnv
  alias EVM.Functions
  alias EVM.Gas
  alias MerklePatriciaTrie.Trie

  @type state :: Trie.t
  @type output :: <<>>

  @spec run(state, MachineState.t, SubState.t, ExecEnv.t) :: {state, Gas.t, SubState.t, output}
  def run(state, machine_state, sub_state, exec_env) do
    {n_state, n_gas, _n_machine_state, n_sub_state, n_output} = exec(state, machine_state, sub_state, exec_env)

    # Note, we drop machine state from return value

    {n_state, n_gas, n_sub_state, n_output}
  end

  @doc """
  Runs a cycle of our VM in a recursive fashion. Halts when return
  or exception is hit.

  TODO: Add gas to return
  """
  @spec exec(state, MachineState.t, SubState.t, ExecEnv.t) :: {state, MachineState.t, SubState.t, output}
  def exec(state, machine_state, sub_state, exec_env) do
    case Functions.is_exception_halt?(state, machine_state, exec_env) do
      {:halt, _reason} ->
        # We're exception halting, undo it all.
        {nil, machine_state, sub_state, exec_env, <<>>} # original sub-state?
      :continue ->
        {n_state, n_machine_state, n_sub_state, n_exec_env} = cycle(state, machine_state, sub_state, exec_env)

        case Functions.is_normal_halting?(machine_state, exec_env) do
          nil -> exec(n_state, n_machine_state, n_sub_state, n_exec_env) # continue execution
          output -> {n_state, n_machine_state, n_sub_state, output}      # break execution and return
        end
    end
  end

  @doc """
  Runs a single cycle of our VM returning the new state
  """
  @spec cycle(state, MachineState.t, SubState.t, ExecEnv.t) :: {state, MachineState.t, SubState.t, ExecEnv.t}
  def cycle(state, machine_state, sub_state, exec_env) do
    cost = Gas.cost(state, machine_state, exec_env)

    # TODO: these are the other changes
    # TODO: Replace with some variety of VM.run_instruction()
    {state, machine_state, sub_state, exec_env} = {state, machine_state, sub_state, exec_env}

    machine_state = machine_state
      |> MachineState.subtract_gas(cost)
      |> MachineState.next_pc(exec_env)

    {state, machine_state, sub_state, exec_env}
  end

end