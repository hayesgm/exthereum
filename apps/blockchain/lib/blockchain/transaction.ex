defmodule Blockchain.Transaction do
  @moduledoc """
  The module encode the transaction object, defined in Section 4.3
  of the Yellow Paper (http://gavwood.com/Paper.pdf).
  """

  defstruct [
    nonce: nil,       # Tn
    gas_price: nil,   # Tp
    gas_limit: nil,   # Tg
    to: nil,          # Tt
    value: 0,         # Tv
    v: nil,           # Tw
    r: nil,           # Tr
    s: nil,           # Ts
    init: nil,        # Ti
    data: nil,        # Td
  ]

  @type t :: %{
    nonce: EVM.val,
    gas_price: EVM.val,
    gas_limit: EVM.val,
    to: EVM.address | <<_::0>>,
    value: EVM.val,
    v: <<_::5>>,
    r: <<_::256>>,
    s: <<_::256>>,
    init: EVM.MachineCode.t,
    data: binary(),
  }

  @doc """
  Encodes a transaction such that it can be RLP-encoded.
  This is defined at L_T Eq.(14) in the Yellow Paper.

  ## Examples

      iex> Blockchain.Transaction.serialize(%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"})
      [5, 6, 7, <<1::160>>, 8, "hi", 27, 9, 10]

      iex> Blockchain.Transaction.serialize(%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 8, v: 27, r: 9, s: 10, init: <<1, 2, 3>>})
      [5, 6, 7, <<>>, 8, <<1, 2, 3>>, 27, 9, 10]
  """
  @spec serialize(t) :: RLP.t
  def serialize(trx) do
    [
      trx.nonce,
      trx.gas_price,
      trx.gas_limit,
      trx.to,
      trx.value,
      (if trx.to == <<>>, do: trx.init, else: trx.data),
      trx.v,
      trx.r,
      trx.s
    ]
  end

  @doc """
  Validates the validity of a transaction that is required to be
  true before we're willing to execute a transaction. This is
  specified in Section 6.2 of the Yellow Paper Eq.(66).

  # TODO: Add examples
  # TODO: Implement
  """
  @spec is_valid?(t) :: boolean()
  def is_valid?(trx) do
    true
  end

  @doc """
  Performs transaction execution, as defined in Section 6
  of the Yellow Paper, defined there as 𝛶, Eq.(1) and Eq.(59),
  and Eq.(70).

  From the Yellow Paper, T_o is the original transactor, which can differ from the
  sender in the case of a message call or contract creation
  not directly triggered by a transaction but coming from
  the execution of EVM-code.

  # TODO: Add examples
  # TODO: Add gas
  """
  @spec execute_transaction(EVM.VM.state, t) :: EVM.VM.state
  def execute_transaction(state, trx) do
    {:ok, sender} = Blockchain.Transaction.Signature.sender(trx)

    state_0 = begin_transaction(state, sender, trx)

    # TODO: Deduct gas (g ≡ Tg − g0 from Eq.(71))
    originator = trx.sender
    gas = trx.gas_limit # or something
    stack_depth = 0
    apparent_value = trx.value
    block_header = nil # TODO:

    # TODO: Sender versus originator?
    {state_p, remaining_gas, sub_state} = case trx.to do
      <<>> -> Blockchain.Contract.create_contract(state, sender, originator, gas, trx.gas_price, trx.value, trx.init, stack_depth) # Λ
      recipient -> 
        # Note, we only want to take the first 3 tuples.
        Blockchain.Contract.message_call(state, sender, originator, recipient, recipient, gas, trx.gas_price, trx.value, apparent_value, trx.data, stack_depth, block_header) # Θ_3
    end

    # TODO: Compute refund (Eq.(72))
    refund = 0

  end

  @doc """
  Performs first step of transaction, which adjusts the sender's
  balance and nonce, as defined in Eq.(67), Eq.(68) and Eq.(69)
  of the Yellow Paper.

  Note: we pass in sender here so we do not need to compute it
        several times (since we'll use it elsewhere).

  TODO: we execute this as two separate updates; we may want to
        combine a series of updates before we update our state.

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10, nonce: 7})
      ...>   |> Blockchain.Account.put_account(<<0x02::160>>, %Blockchain.Account{balance: 5})
      iex> state = Blockchain.Transaction.begin_transaction(state, <<0x01::160>>, %Blockchain.Transaction{to: <<0x02::160>>, value: 3})
      iex> {Blockchain.Account.get_account(state, <<0x01::160>>), Blockchain.Account.get_account(state, <<0x02::160>>)}
      {%Blockchain.Account{balance: 7, nonce: 8}, %Blockchain.Account{balance: 8}}
  """
  @spec begin_transaction(EVM.state, EVM.address, t) :: EVM.VM.state
  def begin_transaction(state, sender, trx) do
    {:ok, state} = Blockchain.Account.transfer(state, sender, trx.to, trx.value)

    Blockchain.Account.update_account(state, sender, fn (acc) -> %{acc | nonce: acc.nonce + 1} end)
  end

  @doc """
  Pays miner, according to Eq.(73), Eq.(74), Eq.(75) and Eq.(76).

  Again, we take a sender so that we don't have to re-compute the sender
  address several times.

  TODO: Add tests
  """
  @spec pay_miner(EVM.state, EVM.address, t, EVM.Gas.t, Blockchain.Block.Header.t) :: EVM.state
  def pay_miner(state, sender, trx, gas_used, block_header) do
    state # ...
  end

end