defmodule EVM.MachineCode do
  @moduledoc """
  Functions for helping read a contract's machine code.
  """
  alias EVM.Instruction
  alias EVM.MachineState

  @type t :: binary()

  @doc """
  Returns the current instruction being executed. In the
  Yellow Paper, this is often referred to as `w`.

  ## Examples

      iex> EVM.MachineCode.current_instruction(%EVM.MachineState{pc: 0}, %EVM.ExecEnv{machine_code: <<0x15::8, 0x11::8, 0x12::8>>})
      0x15

      iex> EVM.MachineCode.current_instruction(%EVM.MachineState{pc: 1}, %EVM.ExecEnv{machine_code: <<0x15::8, 0x11::8, 0x12::8>>})
      0x11

      iex> EVM.MachineCode.current_instruction(%EVM.MachineState{pc: 2}, %EVM.ExecEnv{machine_code: <<0x15::8, 0x11::8, 0x12::8>>})
      0x12
  """
  @spec current_instruction(MachineState.t, ExecEnv.t) :: Instruction.opcode
  def current_instruction(machine_state, exec_env) do
    Instruction.get_instruction_at(exec_env.machine_code, machine_state.pc)
  end

  @doc """
  Returns true if the given new pc is a valid jump
  destination for the machine code, false otherwise.

  TODO: Memoize
  TODO: Convert test to use encode...

  ## Examples

      iex> EVM.MachineCode.valid_jump_dest?(0, <<0x00, 0x01, 0x02, 0x5B, 0x00, 0x5B, 0x00>>)
      false

      iex> EVM.MachineCode.valid_jump_dest?(3, <<0x00, 0x01, 0x02, 0x5B, 0x00, 0x5B, 0x00>>)
      true

      iex> EVM.MachineCode.valid_jump_dest?(4, <<0x00, 0x01, 0x02, 0x5B, 0x00, 0x5B, 0x00>>)
      false

      iex> EVM.MachineCode.valid_jump_dest?(5, <<0x00, 0x01, 0x02, 0x5B, 0x00, 0x5B, 0x00>>)
      true

      iex> EVM.MachineCode.valid_jump_dest?(6, <<0x00, 0x01, 0x02, 0x5B, 0x00, 0x5B, 0x00>>)
      false
  """
  @spec valid_jump_dest?(MachineState.pc, t) :: boolean()
  def valid_jump_dest?(pc, machine_code) do
    # TODO: This should be sorted for quick lookup
    Enum.member?(machine_code |> valid_jump_destinations, pc)
  end

  @doc """
  Returns the legal jump locations in the given machine code.

  TODO: Memoize
  TODO: Convert test to use encode([:STOP, ADD, :MUL]) or such

  ## Example

      iex> EVM.MachineCode.valid_jump_destinations(<<0x00, 0x01, 0x02, 0x5B, 0x00, 0x5B, 0x00>>)
      [3, 5]
  """
  @spec valid_jump_destinations(t) :: [MachineState.pc]
  def valid_jump_destinations(machine_code) do
    do_valid_jump_destinations(machine_code, 0)
  end

  # Returns the valid jump destinations by scanning through
  # entire set of machine code
  defp do_valid_jump_destinations(machine_code, pos) do
    instruction = Instruction.get_instruction_at(machine_code, pos) |> Instruction.decode
    next_pos = Instruction.next_instr_pos(pos, instruction)

    cond do
      pos >= byte_size(machine_code) -> []
      instruction == :JUMPDEST ->
        [pos | do_valid_jump_destinations(machine_code, next_pos)]
      true -> do_valid_jump_destinations(machine_code, next_pos)
    end
  end

end