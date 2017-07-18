defmodule Blockchain.Block.Header do
  @moduledoc """
  This structure codifies the header of a block in the blockchain.
  """

  defstruct [
    parent_hash: nil,       # Hp P(BH)Hr
    ommers_hash: nil,       # Ho KEC(RLP(L∗H(BU)))
    beneficiary: nil,       # Hc
    state_root: nil,        # Hr TRIE(LS(Π(σ, B)))
    transactions_root: nil, # Ht TRIE({∀i < kBTk, i ∈ P : p(i, LT (BT[i]))})
    receipts_root: nil,     # He TRIE({∀i < kBRk, i ∈ P : p(i, LR(BR[i]))})
    logs_bloom: nil,        # Hb bloom
    difficulty: nil,        # Hd
    number: nil,            # Hi
    gas_limit: nil,         # Hl
    gas_used: nil,          # Hg
    timestamp: nil,         # Hs
    extra_data: nil,        # Hx
    mix_hash: nil,          # Hm
    nonce: nil,             # Hn
  ]

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

  # TODO: is_before_homestead
  def is_before_homestead?(h) do
    false
  end
end