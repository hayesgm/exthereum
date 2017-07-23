defmodule Blockchain.Block.Header do
  @moduledoc """
  This structure codifies the header of a block in the blockchain.
  """

  # The start of the Homestead block, as defined in Eq.(13) of the Yellow Paper (N_H)
  @homestead 1_150_000

  defstruct [
    parent_hash: nil,        # Hp P(BH)Hr
    ommers_hash: nil,        # Ho KEC(RLP(L∗H(BU)))
    beneficiary: nil,        # Hc
    state_root: <<>>,        # Hr TRIE(LS(Π(σ, B)))
    transactions_root: <<>>, # Ht TRIE({∀i < kBTk, i ∈ P : p(i, LT (BT[i]))})
    receipts_root: <<>>,     # He TRIE({∀i < kBRk, i ∈ P : p(i, LR(BR[i]))})
    logs_bloom: <<>>,        # Hb bloom
    difficulty: nil,         # Hd
    number: nil,             # Hi
    gas_limit: 0,            # Hl
    gas_used: 0,             # Hg
    timestamp: nil,          # Hs
    extra_data: <<>>,        # Hx
    mix_hash: nil,           # Hm
    nonce: nil,              # Hn
  ]

  # As defined in Eq.(35)
  @type t :: %{
    parent_hash: EVM.hash,
    ommers_hash: EVM.hash,
    beneficiary: EVM.address,
    state_root: EVM.trie_root,
    transactions_root: EVM.trie_root,
    receipts_root: EVM.trie_root,
    logs_bloom: binary(), # TODO
    difficulty: integer(),
    number: integer(),
    gas_limit: EVM.val,
    gas_used: EVM.val,
    timestamp: EVM.timestamp,
    extra_data: binary(),
    mix_hash: EVM.hash,
    nonce: <<_::64>>, # TODO: 64-bit hash?
  }

  @doc "Returns the block that defines the start of Homestead"
  @spec homestead() :: integer()
  def homestead, do: @homestead

  @doc """
  This functions encode a header into a value that can
  be RLP encoded. This is defined as L_H Eq.(32) in the Yellow Paper.

  ## Examples

      iex> Blockchain.Block.Header.serialize(%Blockchain.Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>})
      [<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, 5, 1, 5, 3, 6, "Hi mom", <<7::256>>, <<8::64>>]
  """
  @spec serialize(t) :: RLP.t
  def serialize(h) do
    [
      h.parent_hash,
      h.ommers_hash,
      h.beneficiary,
      h.state_root,
      h.transactions_root,
      h.receipts_root,
      h.logs_bloom,
      h.difficulty,
      h.number,
      h.gas_limit,
      h.gas_used,
      h.timestamp,
      h.extra_data,
      h.mix_hash,
      h.nonce
    ]
  end

  @doc """
  Deserializes a block header from an RLP encodable structure.
  This effectively undoes the encoding defined in L_H Eq.(32) of the
  Yellow Paper.

  ## Examples

      iex> Blockchain.Block.Header.deserialize([<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>])
      %Blockchain.Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}
  """
  @spec deserialize(RLP.t) :: t
  def deserialize(rlp) do
    [
      parent_hash,
      ommers_hash,
      beneficiary,
      state_root,
      transactions_root,
      receipts_root,
      logs_bloom,
      difficulty,
      number,
      gas_limit,
      gas_used,
      timestamp,
      extra_data,
      mix_hash,
      nonce
    ] = rlp

    %__MODULE__{
      parent_hash: parent_hash,
      ommers_hash: ommers_hash,
      beneficiary: beneficiary,
      state_root: state_root,
      transactions_root: transactions_root,
      receipts_root: receipts_root,
      logs_bloom: logs_bloom,
      difficulty: RLP.decode_unsigned(difficulty),
      number: RLP.decode_unsigned(number),
      gas_limit: RLP.decode_unsigned(gas_limit),
      gas_used: RLP.decode_unsigned(gas_used),
      timestamp: RLP.decode_unsigned(timestamp),
      extra_data: extra_data,
      mix_hash: mix_hash,
      nonce: nonce,
    }
  end

  @doc """
  Returns true if a given block is before the
  Homestead block.

  ## Examples

      iex> Blockchain.Block.Header.is_before_homestead?(%Blockchain.Block.Header{number: 5})
      true

      iex> Blockchain.Block.Header.is_before_homestead?(%Blockchain.Block.Header{number: 5_000_000})
      false

      iex> Blockchain.Block.Header.is_before_homestead?(%Blockchain.Block.Header{number: 1_150_000})
      false
  """
  @spec is_before_homestead?(t) :: boolean()
  def is_before_homestead?(h) do
    h.number < @homestead
  end

  @doc """
  Returns true if a given block is at or after the
  Homestead block.

  ## Examples

      iex> Blockchain.Block.Header.is_after_homestead?(%Blockchain.Block.Header{number: 5})
      false

      iex> Blockchain.Block.Header.is_after_homestead?(%Blockchain.Block.Header{number: 5_000_000})
      true

      iex> Blockchain.Block.Header.is_after_homestead?(%Blockchain.Block.Header{number: 1_150_000})
      true
  """
  @spec is_after_homestead?(t) :: boolean()
  def is_after_homestead?(h), do: not is_before_homestead?(h)

  @doc """
  Returns true if the block header is valid. This defines
  Eq.(50), Eq.(51), Eq.(52), Eq.(53), Eq.(54), Eq.(55),
  Eq.(56), Eq.(57) and Eq.(58) of the Yellow Paper, commonly
  referred to as V(H).

  # TODO: Implement and add examples

  ## Examples

      iex> Blockchain.Block.Header.is_valid?(%Blockchain.Block.Header{})
      false
  """
  @spec is_valid?(t) :: boolean()
  def is_valid?(header) do
    true
  end

  @doc """
  Returns the total available gas left for all transactions in
  this block. This is the total gas limit minus the gas used
  in transactions.

  ## Examples

      iex> Blockchain.Block.Header.available_gas(%Blockchain.Block.Header{gas_limit: 50_000, gas_used: 30_000})
      20_000
  """
  @spec available_gas(t) :: EVM.Gas.t
  def available_gas(header) do
    header.gas_limit - header.gas_used
  end
end