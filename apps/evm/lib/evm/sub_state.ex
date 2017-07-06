defmodule EVM.SubState do
  @moduledoc """
  Functions for handling the sub-state that exists only
  between operations in an execution for a contract.
  """

  defstruct [
    suicide_list: [],
    logs: [],
    refund: 0
  ]

  @type t :: %{
    suicide_list: [],
    logs: [],
    refund: EVM.Wei.t
  }
end