defmodule EVM.Instruction.Metadata do
  @moduledoc """
  A simple struct to store metadata about all VM instructions.
  """

  defstruct [
    id: nil,
    sym: nil,
    d: nil,
    a: nil,
    description: nil
  ]

  @type t :: %{
    id: integer(),
    sym: atom(),
    d: integer(),
    a: integer(),
    description: String.t
  }
end