defmodule EVM.Instruction.Impl do
  @moduledoc """
  Reference implementation for all opcodes in the Ethereum VM.
  """

  require Logger
  alias EVM.Stack

  @raise_for_unknown false

  @doc """
  Takes an instruction, stack arguments and the current
  state, and returns an updated state.

  The function expects the arguments for the instruction have already
  been popped off the stack.

  ## Examples

      iex> EVM.Instruction.Impl.exec(:ADD, [1,2], %{}, %EVM.MachineState{stack: []}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [3]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Instruction.Impl.exec(:MISSING, [], %{}, %EVM.MachineState{stack: []}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: []}, %EVM.SubState{}, %EVM.ExecEnv{}}
  """
  # TODO: Add test cases how?
  def exec(:ADD, [s0, s1], state, machine_state, sub_state, exec_env) do
    {state, machine_state |> push(s0+s1), sub_state, exec_env}
  end

  # Fallback
  def exec(instruction, args, state, machine_state, sub_state, exec_env) do
    Logger.warn("Unknown instruction encountered: #{instruction} with args #{inspect args}")
    if @raise_for_unknown, do: raise "Unknown instruction: #{instruction}"

    {state, machine_state, sub_state, exec_env}
  end

  # Helper function to push to the stack within machine_state.
  defp push(machine_state, val) do
    %{machine_state| stack: machine_state.stack |> Stack.push(val)}
  end
end