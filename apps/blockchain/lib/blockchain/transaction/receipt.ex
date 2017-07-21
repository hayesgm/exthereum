defmodule Blockchain.Transaction.Receipt do
  @moduledoc """
  This module specifies functions to create and
  interact with the transaction receipt, defined
  in Section 4.4.1 of the Yellow Paper.

  Transaction receipts track incremental state changes
  after each transaction (e.g. how much gas has been
  expended).
  """

  # Defined in Eq.(19)
  defstruct [
    state: <<>>,
    cumulative_gas: 0,
    bloom_filter: <<>>,
    logs: [],
  ]

  # Types defined in Eq.(20)
  @type t :: %{
    state: EVM.state,
    cumulative_gas: EVM.Wei.t,
    bloom_filter: <<>>, # TODO: Bloom filter
    logs: [], # TODO: Log type
  }

  @doc """
  Encodes a transaction receipt such that it can be
  RLP encoded. This is defined in Eq.(20) of the Yellow
  Paper.

  # TODO: More examples

  ## Examples

      iex> Blockchain.Transaction.Receipt.serialize(%Blockchain.Transaction.Receipt{})
      [<<>>, 0, <<>>, []]
  """
  @spec serialize(t) :: RLP.t
  def serialize(trx_receipt) do
    [
      trx_receipt.state,
      trx_receipt.cumulative_gas,
      trx_receipt.bloom_filter,
      trx_receipt.logs,
    ]
  end

end