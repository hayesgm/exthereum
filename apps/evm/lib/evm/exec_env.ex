defmodule EVM.ExecEnv do
  @moduledoc """
  Stores information about the execution environment which led
  to this EVM being called. This is, for instance, the sender of
  a payment or message to a contract, or a sub-contract call.

  This generally relates to `I` in the Yellow Paper.
  """

  defstruct [
    address: nil,                # a
    originator: nil,             # o
    price_of_gas: nil,           # p
    data: nil,                   # d
    sender: nil,                 # s
    value_in_wei: nil,           # v
    machine_code: nil,           # b
    header_of_block: nil,        # h
    stack_depth: nil]            # e

  @type address :: <<_::20>>
  @type t :: %{
    address: address,
    originator: address,
    price_of_gas: EVM.Gas.t,
    data: binary(),
    sender: address,
    value_in_wei: EVM.Wei.t,
    machine_code: EVM.MachineCode.t,
    header_of_block: binary(),
    stack_depth: integer()
  }

end