defmodule EVM.Instruction do
  @moduledoc """
  Code to handle encoding and decoding
  instructions from opcodes.
  """

  alias EVM.ExecEnv
  alias EVM.MachineState

  @type instruction :: binary()
  @type opcode :: byte()

  @instructions [
    %EVM.Instruction.Metadata{id: 0x00, sym: :STOP, d: 0, a: 0, description: "Halts execution"},
    %EVM.Instruction.Metadata{id: 0x01, sym: :ADD, d: 2, a: 1, description: "Addition operation"},
    %EVM.Instruction.Metadata{id: 0x01, sym: :ADD, d: 2, a: 1, description: "Addition operation"},
    %EVM.Instruction.Metadata{id: 0x02, sym: :MUL, d: 2, a: 1, description: "Multiplication operation."},
    %EVM.Instruction.Metadata{id: 0x03, sym: :SUB, d: 2, a: 1, description: "Subtraction operation."},
    %EVM.Instruction.Metadata{id: 0x04, sym: :DIV, d: 2, a: 1, description: "Integer division operation."},
    %EVM.Instruction.Metadata{id: 0x05, sym: :SDIV, d: 2, a: 1, description: "Signed integer division operation (truncated)."},
    %EVM.Instruction.Metadata{id: 0x06, sym: :MOD, d: 2, a: 1, description: "Modulo remainder operation."},
    %EVM.Instruction.Metadata{id: 0x07, sym: :SMOD, d: 2, a: 1, description: "Signed modulo remainder operation."},
    %EVM.Instruction.Metadata{id: 0x08, sym: :ADDMOD, d: 3, a: 1, description: "Modulo addition operation."},
    %EVM.Instruction.Metadata{id: 0x09, sym: :MULMOD, d: 3, a: 1, description: "Modulo multiplication operation."},
    %EVM.Instruction.Metadata{id: 0x0a, sym: :EXP, d: 2, a: 1, description: "Exponential operation"},
    %EVM.Instruction.Metadata{id: 0x0b, sym: :SIGNEXTEND, d: 2, a: 1, description: "Extend length of two’s complement signed integer."},
    %EVM.Instruction.Metadata{id: 0x10, sym: :LT, d: 2, a: 1, description: "Less-than comparision."},
    %EVM.Instruction.Metadata{id: 0x11, sym: :GT, d: 2, a: 1, description: "Greater-than comparision."},
    %EVM.Instruction.Metadata{id: 0x12, sym: :SLT, d: 2, a: 1, description: "Signed less-than comparision."},
    %EVM.Instruction.Metadata{id: 0x13, sym: :SGT, d: 2, a: 1, description: "Signed greater-than comparision"},
    %EVM.Instruction.Metadata{id: 0x14, sym: :EQ, d: 2, a: 1, description: "Equality comparision."},
    %EVM.Instruction.Metadata{id: 0x15, sym: :ISZERO, d: 1, a: 1, description: "Simple not operator."},
    %EVM.Instruction.Metadata{id: 0x16, sym: :AND, d: 2, a: 1, description: "Bitwise AND operation."},
    %EVM.Instruction.Metadata{id: 0x17, sym: :OR, d: 2, a: 1, description: "Bitwise OR operation."},
    %EVM.Instruction.Metadata{id: 0x18, sym: :XOR, d: 2, a: 1, description: "Bitwise XOR operation."},
    %EVM.Instruction.Metadata{id: 0x19, sym: :NOT, d: 1, a: 1, description: "Bitwise NOT operation."},
    %EVM.Instruction.Metadata{id: 0x1a, sym: :BYTE, d: 2, a: 1, description: "Retrieve single byte from word."},
    %EVM.Instruction.Metadata{id: 0x20, sym: :SHA3, d: 2, a: 1, description: "Compute Keccak-256 hash."},
    %EVM.Instruction.Metadata{id: 0x30, sym: :ADDRESS, d: 0, a: 1, description: "Get address of currently executing account."},
    %EVM.Instruction.Metadata{id: 0x31, sym: :BALANCE, d: 1, a: 1, description: "Get balance of the given account."},
    %EVM.Instruction.Metadata{id: 0x32, sym: :ORIGIN, d: 0, a: 1, description: "Get execution origination address."},
    %EVM.Instruction.Metadata{id: 0x33, sym: :CALLER, d: 0, a: 1, description: "Get caller address."},
    %EVM.Instruction.Metadata{id: 0x34, sym: :CALLVALUE, d: 0, a: 1, description: "Get deposited value by the instruction/transaction responsible for this execution."},
    %EVM.Instruction.Metadata{id: 0x35, sym: :CALLDATALOAD, d: 1, a: 1, description: "Get input data of current environment."},
    %EVM.Instruction.Metadata{id: 0x36, sym: :CALLDATASIZE, d: 0, a: 1, description: "Get size of input data in current environment."},
    %EVM.Instruction.Metadata{id: 0x37, sym: :CALLDATACOPY, d: 3, a: 0, description: "Copy input data in current environment to memory."},
    %EVM.Instruction.Metadata{id: 0x38, sym: :CODESIZE, d: 0, a: 1, description: "Get size of code running in current environment."},
    %EVM.Instruction.Metadata{id: 0x39, sym: :CODECOPY, d: 3, a: 0, description: "Copy code running in current environment to memory."},
    %EVM.Instruction.Metadata{id: 0x3a, sym: :GASPRICE, d: 0, a: 1, description: "Get price of gas in current environment."},
    %EVM.Instruction.Metadata{id: 0x3b, sym: :EXTCODESIZE, d: 1, a: 1, description: "Get size of an account’s code."},
    %EVM.Instruction.Metadata{id: 0x3c, sym: :EXTCODECOPY, d: 4, a: 0, description: "Copy an account’s code to memory."},
    %EVM.Instruction.Metadata{id: 0x40, sym: :BLOCKHASH, d: 1, a: 1, description: "Get the hash of one of the 256 most recent complete blocks"},
    %EVM.Instruction.Metadata{id: 0x41, sym: :COINBASE, d: 0, a: 1, description: "Get the block’s beneficiary address"},
    %EVM.Instruction.Metadata{id: 0x42, sym: :TIMESTAMP, d: 0, a: 1, description: "Get the block’s timestamp"},
    %EVM.Instruction.Metadata{id: 0x43, sym: :NUMBER, d: 0, a: 1, description: "Get the block’s number."},
    %EVM.Instruction.Metadata{id: 0x44, sym: :DIFFICULTY, d: 0, a: 1, description: "Get the block’s difficulty."},
    %EVM.Instruction.Metadata{id: 0x45, sym: :GASLIMIT, d: 0, a: 1, description: "Get the block’s gas limit."},
    %EVM.Instruction.Metadata{id: 0x50, sym: :POP, d: 1, a: 0, description: "Remove item from stack."},
    %EVM.Instruction.Metadata{id: 0x51, sym: :MLOAD, d: 1, a: 1, description: "Load word from memory"},
    %EVM.Instruction.Metadata{id: 0x52, sym: :MSTORE, d: 2, a: 0, description: "Save word to memory."},
    %EVM.Instruction.Metadata{id: 0x53, sym: :MSTORE8, d: 2, a: 0, description: "Save byte to memory."},
    %EVM.Instruction.Metadata{id: 0x54, sym: :SLOAD, d: 1, a: 1, description: "Load word from storage"},
    %EVM.Instruction.Metadata{id: 0x55, sym: :SSTORE, d: 2, a: 0, description: "Save word to storage"},
    %EVM.Instruction.Metadata{id: 0x56, sym: :JUMP, d: 1, a: 0, description: "Alter the program counter."},
    %EVM.Instruction.Metadata{id: 0x57, sym: :JUMPI, d: 2, a: 0, description: "Conditionally alter the program counter."},
    %EVM.Instruction.Metadata{id: 0x58, sym: :PC, d: 0, a: 1, description: "Get the value of the program counter prior to the increment corresponding to this instruction."},
    %EVM.Instruction.Metadata{id: 0x59, sym: :MSIZE, d: 0, a: 1, description: "Get the size of active memory in bytes"},
    %EVM.Instruction.Metadata{id: 0x5a, sym: :GAS, d: 0, a: 1, description: "Get the amount of available gas, including the corresponding reduction for the cost of this instruction."},
    %EVM.Instruction.Metadata{id: 0x5b, sym: :JUMPDEST, d: 0, a: 0, description: "Mark a valid destination for jumps."},
    %EVM.Instruction.Metadata{id: 0x60, sym: :PUSH1, d: 0, a: 1, description: "Place 1-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x61, sym: :PUSH2, d: 0, a: 1, description: "Place 2-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x62, sym: :PUSH3, d: 0, a: 1, description: "Place 3-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x63, sym: :PUSH4, d: 0, a: 1, description: "Place 4-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x64, sym: :PUSH5, d: 0, a: 1, description: "Place 5-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x65, sym: :PUSH6, d: 0, a: 1, description: "Place 6-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x66, sym: :PUSH7, d: 0, a: 1, description: "Place 7-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x67, sym: :PUSH8, d: 0, a: 1, description: "Place 8-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x68, sym: :PUSH9, d: 0, a: 1, description: "Place 9-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x69, sym: :PUSH10, d: 0, a: 1, description: "Place 10-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x6a, sym: :PUSH11, d: 0, a: 1, description: "Place 11-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x6b, sym: :PUSH12, d: 0, a: 1, description: "Place 12-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x6c, sym: :PUSH13, d: 0, a: 1, description: "Place 13-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x6d, sym: :PUSH14, d: 0, a: 1, description: "Place 14-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x6e, sym: :PUSH15, d: 0, a: 1, description: "Place 15-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x6f, sym: :PUSH16, d: 0, a: 1, description: "Place 16-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x70, sym: :PUSH17, d: 0, a: 1, description: "Place 17-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x71, sym: :PUSH18, d: 0, a: 1, description: "Place 18-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x72, sym: :PUSH19, d: 0, a: 1, description: "Place 19-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x73, sym: :PUSH20, d: 0, a: 1, description: "Place 20-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x74, sym: :PUSH21, d: 0, a: 1, description: "Place 21-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x75, sym: :PUSH22, d: 0, a: 1, description: "Place 22-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x76, sym: :PUSH23, d: 0, a: 1, description: "Place 23-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x77, sym: :PUSH24, d: 0, a: 1, description: "Place 24-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x78, sym: :PUSH25, d: 0, a: 1, description: "Place 25-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x79, sym: :PUSH26, d: 0, a: 1, description: "Place 26-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x7a, sym: :PUSH27, d: 0, a: 1, description: "Place 27-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x7b, sym: :PUSH28, d: 0, a: 1, description: "Place 28-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x7c, sym: :PUSH29, d: 0, a: 1, description: "Place 29-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x7d, sym: :PUSH30, d: 0, a: 1, description: "Place 30-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x7e, sym: :PUSH31, d: 0, a: 1, description: "Place 31-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x7f, sym: :PUSH32, d: 0, a: 1, description: "Place 32-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x80, sym: :DUP1, d: 1, a: 2, description: "Duplicate 1st stack item."},
    %EVM.Instruction.Metadata{id: 0x81, sym: :DUP2, d: 1, a: 2, description: "Duplicate 2nd stack item."},
    %EVM.Instruction.Metadata{id: 0x82, sym: :DUP3, d: 1, a: 2, description: "Duplicate 3rd stack item."},
    %EVM.Instruction.Metadata{id: 0x83, sym: :DUP4, d: 1, a: 2, description: "Duplicate 4th stack item."},
    %EVM.Instruction.Metadata{id: 0x84, sym: :DUP5, d: 1, a: 2, description: "Duplicate 5th stack item."},
    %EVM.Instruction.Metadata{id: 0x85, sym: :DUP6, d: 1, a: 2, description: "Duplicate 6th stack item."},
    %EVM.Instruction.Metadata{id: 0x86, sym: :DUP7, d: 1, a: 2, description: "Duplicate 7th stack item."},
    %EVM.Instruction.Metadata{id: 0x87, sym: :DUP8, d: 1, a: 2, description: "Duplicate 8th stack item."},
    %EVM.Instruction.Metadata{id: 0x88, sym: :DUP9, d: 1, a: 2, description: "Duplicate 9th stack item."},
    %EVM.Instruction.Metadata{id: 0x89, sym: :DUP10, d: 1, a: 2, description: "Duplicate 10th stack item."},
    %EVM.Instruction.Metadata{id: 0x8a, sym: :DUP11, d: 1, a: 2, description: "Duplicate 11th stack item."},
    %EVM.Instruction.Metadata{id: 0x8b, sym: :DUP12, d: 1, a: 2, description: "Duplicate 12th stack item."},
    %EVM.Instruction.Metadata{id: 0x8c, sym: :DUP13, d: 1, a: 2, description: "Duplicate 13th stack item."},
    %EVM.Instruction.Metadata{id: 0x8d, sym: :DUP14, d: 1, a: 2, description: "Duplicate 14th stack item."},
    %EVM.Instruction.Metadata{id: 0x8e, sym: :DUP15, d: 1, a: 2, description: "Duplicate 15th stack item."},
    %EVM.Instruction.Metadata{id: 0x8f, sym: :DUP16, d: 1, a: 2, description: "Duplicate 16th stack item."},
    %EVM.Instruction.Metadata{id: 0x90, sym: :SWAP1, d: 2, a: 2, description: "Exchange 1st and 2nd stack items."},
    %EVM.Instruction.Metadata{id: 0x91, sym: :SWAP2, d: 2, a: 2, description: "Exchange 2nd and 3rd stack items."},
    %EVM.Instruction.Metadata{id: 0x92, sym: :SWAP3, d: 2, a: 2, description: "Exchange 3rd and 4th stack items."},
    %EVM.Instruction.Metadata{id: 0x93, sym: :SWAP4, d: 2, a: 2, description: "Exchange 4th and 5th stack items."},
    %EVM.Instruction.Metadata{id: 0x94, sym: :SWAP5, d: 2, a: 2, description: "Exchange 5th and 6th stack items."},
    %EVM.Instruction.Metadata{id: 0x95, sym: :SWAP6, d: 2, a: 2, description: "Exchange 6th and 7th stack items."},
    %EVM.Instruction.Metadata{id: 0x96, sym: :SWAP7, d: 2, a: 2, description: "Exchange 7th and 8th stack items."},
    %EVM.Instruction.Metadata{id: 0x97, sym: :SWAP8, d: 2, a: 2, description: "Exchange 8th and 9th stack items."},
    %EVM.Instruction.Metadata{id: 0x98, sym: :SWAP9, d: 2, a: 2, description: "Exchange 9th and 10th stack items."},
    %EVM.Instruction.Metadata{id: 0x99, sym: :SWAP10, d: 2, a: 2, description: "Exchange 10th and 11th stack items."},
    %EVM.Instruction.Metadata{id: 0x9a, sym: :SWAP11, d: 2, a: 2, description: "Exchange 11th and 12th stack items."},
    %EVM.Instruction.Metadata{id: 0x9b, sym: :SWAP12, d: 2, a: 2, description: "Exchange 12th and 13th stack items."},
    %EVM.Instruction.Metadata{id: 0x9c, sym: :SWAP13, d: 2, a: 2, description: "Exchange 13th and 14th stack items."},
    %EVM.Instruction.Metadata{id: 0x9d, sym: :SWAP14, d: 2, a: 2, description: "Exchange 14th and 15th stack items."},
    %EVM.Instruction.Metadata{id: 0x9e, sym: :SWAP15, d: 2, a: 2, description: "Exchange 15th and 16th stack items."},
    %EVM.Instruction.Metadata{id: 0x9f, sym: :SWAP16, d: 2, a: 2, description: "Exchange 16th and 17th stack items."},
    %EVM.Instruction.Metadata{id: 0xa0, sym: :LOG0, d: 2, a: 0, description: "Append log record with no topics."},
    %EVM.Instruction.Metadata{id: 0xa1, sym: :LOG1, d: 3, a: 0, description: "Append log record with one topic."},
    %EVM.Instruction.Metadata{id: 0xa2, sym: :LOG2, d: 4, a: 0, description: "Append log record with two topics."},
    %EVM.Instruction.Metadata{id: 0xa3, sym: :LOG3, d: 5, a: 0, description: "Append log record with three topics."},
    %EVM.Instruction.Metadata{id: 0xa4, sym: :LOG4, d: 6, a: 0, description: "Append log record with four topics."},
    %EVM.Instruction.Metadata{id: 0xf0, sym: :CREATE, d: 3, a: 1, description: "Create a new account with associated code."},
    %EVM.Instruction.Metadata{id: 0xf1, sym: :CALL, d: 7, a: 1, description: "Message-call into an account.,"},
    %EVM.Instruction.Metadata{id: 0xf2, sym: :CALLCODE, d: 7, a: 1, description: "Message-call into this account with an alternative account’s code.,"},
    %EVM.Instruction.Metadata{id: 0xf3, sym: :RETURN, d: 2, a: 0, description: "Halt execution returning output data,"},
    %EVM.Instruction.Metadata{id: 0xf4, sym: :DELEGATECALL, d: 6, a: 1, description: "Message-call into this account with an alternative account’s code, but persisting the current values for sender and value."},
    %EVM.Instruction.Metadata{id: 0xff, sym: :SUICIDE, d: 1, a: 0, description: "Halt execution and register account for later deletion."},
  ]

  @opcodes_to_metadata (for i <- @instructions, do: {i.id, i}) |> Enum.into(%{})
  @opcodes_to_instructions (for {id, i} <- @opcodes_to_metadata, do: {id, i.sym}) |> Enum.into(%{})
  @instructions_to_opcodes EVM.Helpers.invert(@opcodes_to_instructions)
  @push1  Map.get(@instructions_to_opcodes, :PUSH1)
  @push32 Map.get(@instructions_to_opcodes, :PUSH32)
  @stop Map.get(@instructions_to_opcodes, :STOP)

  @doc """
  Returns the current instruction at a given program counter address.

  ## Examples

      iex> EVM.Instruction.get_instruction_at(<<0x11, 0x01, 0x02>>, 0)
      0x11

      iex> EVM.Instruction.get_instruction_at(<<0x11, 0x01, 0x02>>, 1)
      0x01

      iex> EVM.Instruction.get_instruction_at(<<0x11, 0x01, 0x02>>, 2)
      0x02

      iex> EVM.Instruction.get_instruction_at(<<0x11, 0x01, 0x02>>, 3)
      0x00
  """
  @spec get_instruction_at(ExecEnv.t, MachineState.pc) :: opcode
  def get_instruction_at(machine_code, pc) when is_binary(machine_code) and is_integer(pc) do
    if pc < byte_size(machine_code) do
      EVM.Helpers.binary_get(machine_code, pc)
    else
      @stop # Every other position is an implicit STOP code
    end
  end

  @doc """
  Returns the next instruction position given a current position
  and the type of instruction. This is to bypass push operands.

  ## Examples

      iex> EVM.Instruction.next_instr_pos(10, :ADD)
      11

      iex> EVM.Instruction.next_instr_pos(20, :MUL)
      21

      iex> EVM.Instruction.next_instr_pos(10, :PUSH1)
      12

      iex> EVM.Instruction.next_instr_pos(10, :PUSH32)
      43
  """
  @spec next_instr_pos(MachineState.pc, opcode) :: MachineState.pc
  def next_instr_pos(pos, instr) do
    encoded_instruction = instr |> encode

    pos + case encoded_instruction do
      i when i in @push1..@push32 ->
        2 + encoded_instruction - @push1
      _ -> 1
    end
  end

  @doc """
  Returns the given instruction for a given opcode.

  ## Examples

      iex> EVM.Instruction.decode(0x00)
      :STOP

      iex> EVM.Instruction.decode(0x01)
      :ADD

      iex> EVM.Instruction.decode(0x02)
      :MUL

      iex> EVM.Instruction.decode(0xffff)
      nil
  """
  @spec decode(opcode) :: instruction | nil
  def decode(opcode) when is_integer(opcode) do
    Map.get(@opcodes_to_instructions, opcode)
  end

  @doc """
  Returns the given opcode for an instruction.

  ## Examples

      iex> EVM.Instruction.encode(:STOP)
      0x00

      iex> EVM.Instruction.encode(:ADD)
      0x01

      iex> EVM.Instruction.encode(:MUL)
      0x02

      iex> EVM.Instruction.encode(:SALMON)
      nil
  """
  @spec encode(instruction) :: opcode | nil
  def encode(instruction) when is_atom(instruction) do
    Map.get(@instructions_to_opcodes, instruction)
  end

  @doc """
  Returns metadata about a given instruction or opcode, or nil.

  ## Examples

      iex> EVM.Instruction.metadata(:STOP)
      %EVM.Instruction.Metadata{id: 0x00, sym: :STOP, d: 0, a: 0, description: "Halts execution"}

      iex> EVM.Instruction.metadata(0x00)
      %EVM.Instruction.Metadata{id: 0x00, sym: :STOP, d: 0, a: 0, description: "Halts execution"}

      iex> EVM.Instruction.metadata(:ADD)
      %EVM.Instruction.Metadata{id: 0x01, sym: :ADD,  d: 2, a: 1, description: "Addition operation"}

      iex> EVM.Instruction.metadata(0xff)
      nil

      iex> EVM.Instruction.metadata(nil)
      nil
  """
  @spec metadata(instruction | opcode) :: Metadata.t | nil
  def metadata(nil), do: nil
  def metadata(instruction) when is_atom(instruction) do
    instruction |> encode |> metadata
  end

  def metadata(opcode) when is_integer(opcode) do
    Enum.at(@instructions, opcode)
  end

  @doc """
  Executes a single instruction. This simply does the effects of the instruction itself,
  ignoring the rest of the actions of an instruction cycle. This will effect, for instance,
  the stack, but will not effect the gas, etc.

  ## Examples

      # TODO: How to handle trie state in tests?
      iex> EVM.Instruction.run_instruction(:ADD, %{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [3]}, %EVM.SubState{}, %EVM.ExecEnv{}}
  """
  @spec run_instruction(instruction, EVM.VM.state, MachineState.t, SubState.t, ExecEnv.t) :: {EVM.VM.state, MachineState.t, SubState.t, ExecEnv.t}
  def run_instruction(instruction, state, machine_state, sub_state, exec_env) do
    # TODO: Make better
    instruction_metadata = metadata(instruction)
    dw = if instruction_metadata, do: Map.get(instruction_metadata, :d), else: nil
    {args, stack} = if dw, do: EVM.Stack.pop_n(machine_state.stack, dw), else: {[], machine_state.stack}

    EVM.Instruction.Impl.exec(instruction, args, state, %{machine_state| stack: stack}, sub_state, exec_env)
  end
end