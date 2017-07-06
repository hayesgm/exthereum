defmodule EVM.VM do
  @moduledoc """
  The core of the EVM which runs operations based on the
  opcodes of a contract during a transfer or message call.
  """

  alias EVM.SubState
  alias EVM.MachineCode
  alias EVM.MachineState
  alias EVM.ExecEnv
  alias EVM.Functions
  alias EVM.Gas
  alias EVM.Instruction
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

  ## Examples

      # TODO: How to handle trie state in tests?
      iex> EVM.VM.cycle(%{}, %EVM.MachineState{pc: 0, gas: 5, stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:ADD)>>})
      {%{}, %EVM.MachineState{pc: 1, gas: 5, stack: [3]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:ADD)>>}}
  """
  @spec cycle(state, MachineState.t, SubState.t, ExecEnv.t) :: {state, MachineState.t, SubState.t, ExecEnv.t}
  def cycle(state, machine_state, sub_state, exec_env) do
    cost = Gas.cost(state, machine_state, exec_env)

    instruction = MachineCode.current_instruction(machine_state, exec_env) |> Instruction.decode

    {state, machine_state, sub_state, exec_env} = Instruction.run_instruction(instruction, state, machine_state, sub_state, exec_env)

    machine_state = machine_state
      |> MachineState.subtract_gas(cost)
      |> MachineState.next_pc(exec_env)

    {state, machine_state, sub_state, exec_env}
  end

end