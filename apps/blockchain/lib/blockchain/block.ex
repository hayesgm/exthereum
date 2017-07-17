defmodule Blockchain.Block do
  @moduledoc """
  This module effective encodes a Block, the heart of the blockchain. A chain is
  formed when blocks point to previous blocks, either as a parent or an ommer (uncle).
  For more information, see Section 4.4 of the Yellow Paper.
  """

  alias Blockchain.Block.Header
  alias Blockchain.Transaction

  defstruct [
    header: nil,       # B_H
    transactions: [],  # B_T
    ommers: [],        # B_U
  ]

  @type t :: %{
    header: Header.t,
    transactions: [Transaction.t],
    ommers: [Header.t],
  }

  # The start of the Homestead block, as defined in Eq.(13) of the Yellow Paper (N_H)
  @homestead 1_150_000

  @doc """
  Encodes a block such that it can be represented in
  RLP encoding. This is defined as L_B Eq.(33) in the Yellow Paper.

  ## Examples

    iex> Blockchain.Block.serialize(%Blockchain.Block{header:
      %Blockchain.Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>},
      transactions: [],
      ommers: []})
    []

    iex> Blockchain.Block.serialize(%Blockchain.Block{})
    []
  """
  @spec serialize(t) :: RLP.t
  def serialize(block) do
    [
      Header.serialize(block.header),
      Enum.map(block.transactions, &Transaction.serialize/1),
      Enum.map(block.ommers, &Header.serialize/1),
    ]
  end

  # TODO: gen_genesis_block
  # TODO: gen_child_block

  @doc """
  Calculates the difficulty of a block.

  TODO: Implement and test
  """
  @spec difficulty(t, t) :: integer()
  def difficulty(block, parent_block), do: 0


  @doc """
  Calculates the gas limit of a given block.

  TODO: Implement and test
  """
  @spec gas_limit(t, t) :: integer()
  def gas_limit(block, parent_block), do: 0

  @spec block_valid?(t) :: boolean()
  def block_valid?(block), do: true

end