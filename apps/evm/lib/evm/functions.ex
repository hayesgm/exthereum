defmodule EVM.Functions do
  @moduledoc """
  Set of functions defined in the Yellow Paper that do not logically
  fit in other modules.
  """
  alias EVM.ExecEnv
  alias EVM.MachineCode
  alias EVM.MachineState
  alias EVM.Gas
  alias EVM.Instruction
  alias EVM.Stack

  @max_stack 1024

  @doc """
  Returns whether or not the current program is halting due to a
  `return` or terminal statement.

  # Examples

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{pc: 0}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:ADD)>>})
      nil

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{pc: 0}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:MUL)>>})
      nil

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{pc: 0}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:STOP)>>})
      <<>>

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{pc: 0}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:SUICIDE)>>})
      <<>>

      iex> EVM.Functions.is_normal_halting?(%EVM.MachineState{pc: 0}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:RETURN)>>})
      "return"

      # TODO: Handle proper return state
  """
  @spec is_normal_halting?(MachineState.t, ExecEnv.t) :: nil | binary()
  def is_normal_halting?(machine_state, exec_env) do
    case MachineCode.current_instruction(machine_state, exec_env) |> Instruction.decode do
      :RETURN -> h_return(machine_state)
      x when x == :STOP or x == :SUICIDE -> <<>>
      _ -> nil
    end
  end

  # Defined in Appendix H of the Yellow Paper
  # TODO: Implement
  defp h_return(_machine_state) do
    "return"
  end

  @doc """
  Returns whether or not the current program is in an exceptional
  halting state. This may be due to running out of gas,
  having an invalid instruction, having a stack underflow,
  having an invalid jump destination or having a stack overflow.

  ## Examples

      # TODO: Once we add gas cost, make this more reasonable
      # TODO: How do we pass in state?
      iex> EVM.Functions.is_exception_halt?(%{}, %EVM.MachineState{pc: 0, gas: -1}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:ADD)>>})
      {:halt, :insufficient_gas}

      iex> EVM.Functions.is_exception_halt?(%{}, %EVM.MachineState{pc: 0, gas: 0xffff}, %EVM.ExecEnv{machine_code: <<0xfe>>})
      {:halt, :undefined_instruction}

      iex> EVM.Functions.is_exception_halt?(%{}, %EVM.MachineState{pc: 0, gas: 0xffff, stack: []}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:ADD)>>})
      {:halt, :stack_underflow}

      iex> EVM.Functions.is_exception_halt?(%{}, %EVM.MachineState{pc: 0, gas: 0xffff, stack: [5]}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:JUMP)>>})
      {:halt, :invalid_jump_destination}

      iex> EVM.Functions.is_exception_halt?(%{}, %EVM.MachineState{pc: 0, gas: 0xffff, stack: [1]}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:JUMP), EVM.Instruction.encode(:JUMPDEST)>>})
      :continue

      iex> EVM.Functions.is_exception_halt?(%{}, %EVM.MachineState{pc: 0, gas: 0xffff, stack: [1, 5]}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:JUMPI)>>})
      {:halt, :invalid_jump_destination}

      iex> EVM.Functions.is_exception_halt?(%{}, %EVM.MachineState{pc: 0, gas: 0xffff, stack: [1, 5]}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:JUMPI), EVM.Instruction.encode(:JUMPDEST)>>})
      :continue

      iex> EVM.Functions.is_exception_halt?(%{}, %EVM.MachineState{pc: 0, gas: 0xffff, stack: (for _ <- 1..1024, do: 0x0)}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:STOP)>>})
      :continue

      iex> EVM.Functions.is_exception_halt?(%{}, %EVM.MachineState{pc: 0, gas: 0xffff, stack: (for _ <- 1..1024, do: 0x0)}, %EVM.ExecEnv{machine_code: <<EVM.Instruction.encode(:PUSH1)>>})
      {:halt, :stack_overflow}
  """
  @spec is_exception_halt?(EVM.VM.state, MachineState.t, ExecEnv.t) :: :continue | {:halt, String.t}
  def is_exception_halt?(state, machine_state, exec_env) do
    instruction = MachineCode.current_instruction(machine_state, exec_env) |> Instruction.decode
    metadata = Instruction.metadata(instruction)
    dw = if metadata, do: Map.get(metadata, :d), else: nil
    aw = if metadata, do: Map.get(metadata, :a), else: nil
    s0 = Stack.peek(machine_state.stack)

    cond do
      machine_state.gas < Gas.cost(state, machine_state, exec_env) ->
        {:halt, :insufficient_gas}
      metadata == nil || dw == nil ->
        {:halt, :undefined_instruction}
      length(machine_state.stack) < dw ->
        {:halt, :stack_underflow}
      Enum.member?([:JUMP, :JUMPI], instruction) and
        not MachineCode.valid_jump_dest?(s0, exec_env.machine_code) ->
          {:halt, :invalid_jump_destination}
      Stack.length(machine_state.stack) - dw + aw > @max_stack ->
        {:halt, :stack_overflow}
      true ->
        :continue
    end
  end

end