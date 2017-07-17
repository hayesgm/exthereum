defmodule Blockchain.Contract do
  @moduledoc """
  Contract?
  """

  @doc """
  Creates a new contract, as defined in Section 7 Eq.(81) and Eq.(87) of the Yellow Paper as Λ.

  # TODO: Add examples
  """
  @spec create_contract(EVM.state, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.MachineCode.t, integer()) :: {EVM.state, EVM.Gas.t, SubState.t, EVM.MachineCode.t}
  def create_contract(state, sender, originator, available_gas, gas_price, endowment, init_code, stack_depth) do

    address = new_contract_address(sender, sender.nonce) # This has to be pulled

  end

  @doc """
  Executes a message call to a contract, defiend in Section 8 Eq.(99) of the Yellow Paper as Θ.

  TODO: Block header?
  TODO: Add examples
  """
  @spec message_call(EVM.state, EVM.address, EVM.address, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.Wei.t, binary(), integer(), Blockchain.Block.Header.t) :: { EVM.state, EVM.Gas.t, SubState.t, EVM.VM.output }
  def message_call(state, sender, originator, recipient, contract, available_gas, gas_price, value, apparent_value, data, stack_depth, block_header) do
    state_1 = Account.transfer(state, sender, recipient, value)
    machine_code = get_machine_code(state, contract)
    exec_env = nil # exec_env_for_message_call(recipient, originator, gas_price, data, sender, apparent_value, stack_depth, block_header, machine_code)

    # Eq.(106)
    {state_2, remaining_gas, sub_state, _output} = case recipient do
      1 -> EVM.VM.run_ecrec(state_1, available_gas, exec_env)
      2 -> EVM.VM.run_sha256(state_1, available_gas, exec_env)
      3 -> EVM.VM.run_rip160(state_1, available_gas, exec_env)
      4 -> EVM.VM.run_id(state_1, available_gas, exec_env)
      _ -> EVM.VM.run(state_1, available_gas, exec_env)
    end

    # Eq.(105)
    case state_2 do
      nil -> state
      ds -> ds
    end

    # TODO: Result
  end

  @doc """
  Returns the machine code associated with the contract as the given
  address. This will return nil (empty string?) if the contract has
  no associated code (is a simple account).
  """
  @spec get_machine_code(EVM.state, EVM.address) :: nil | EVM.MachineState.t
  def get_machine_code(state, contract) do

  end

  @doc """
  Determines the address of a new contract based on the sender and
  the sender's current nonce.

  This is defined as Eq.(82) in the Yellow Paper.

  ## Examples

      iex> Blockchain.Contract.new_contract_address(<<0x01::160>>, 1)
      <<>>

      iex> Blockchain.Contract.new_contract_address(<<0x01::160>>, 2)
      <<>>

      iex> Blockchain.Contract.new_contract_address(<<0x02::160>>, 0)
      <<>>
  """
  @spec new_contract_address(EVM.address, integer()) :: EVM.address
  def new_contract_address(sender, nonce) do
    [sender, nonce - 1]
      |> RLP.encode()
      |> Blockchain.BitHelper.kec()
      |> Blockchain.BitHelper.mask(160)
  end

end