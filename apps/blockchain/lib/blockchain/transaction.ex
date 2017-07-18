defmodule Blockchain.Transaction do
  @moduledoc """
  The module encode the transaction object, defined in Section 4.3
  of the Yellow Paper (http://gavwood.com/Paper.pdf).
  """

  alias Blockchain.Account

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
        # Note, we only want to take the first 3 items from the tuples, as designated Θ_3 in the literature
        {state_, remaining_gas_, sub_state_, _output} = Blockchain.Contract.message_call(state, sender, originator, recipient, recipient, gas, trx.gas_price, trx.value, apparent_value, trx.data, stack_depth, block_header) # Θ_3

        {state_, remaining_gas_, sub_state_}
    end

    refund = calculate_refund(trx, remaining_gas, sub_state.refund)

    state_after_gas = finalize_transaction_gas(state, sender, trx, refund, block_header)

    state_after_suicides = Enum.reduce(state, sub_state.suicide_list, fn (address, state) ->
      Account.del_account(state, address)
    end)

    state_after_suicides

    # TODO: We need to track Υ^g and Υ^l
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
    state
      |> Account.transfer!(sender, trx.to, trx.value)
      |> Account.increment_nonce(sender)
  end

  @doc """
  Finalizes the gas payout, repaying the sender for excess or refunded gas
  and paying the miner his due. This is defined according to Eq.(73), Eq.(74),
  Eq.(75) and Eq.(76) of the Yellow Paper.

  Again, we take a sender so that we don't have to re-compute the sender
  address several times.

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> trx = %Blockchain.Transaction{gas_price: 10, gas_limit: 30}
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 11})
      ...>   |> Blockchain.Account.put_account(<<0x02::160>>, %Blockchain.Account{balance: 22})
      iex> Blockchain.Transaction.finalize_transaction_gas(state, <<0x01::160>>, trx, 5, %Blockchain.Block.Header{beneficiary: <<0x02::160>>})
      ...>   |> Blockchain.Account.get_accounts([<<0x01::160>>, <<0x02::160>>])
      [
        %Blockchain.Account{balance: 61},
        %Blockchain.Account{balance: 272},
      ]
  """
  @spec finalize_transaction_gas(EVM.state, EVM.address, t, EVM.Gas.t, Blockchain.Block.Header.t) :: EVM.state
  def finalize_transaction_gas(state, sender, trx, refund, block_header) do
    state
      |> Account.add_wei(sender, refund * trx.gas_price) # Eq.(74)
      |> Account.add_wei(block_header.beneficiary, (trx.gas_limit - refund) * trx.gas_price) # Eq.(75)
  end

  @doc """
  Caluclates the amount which should be refunded based on the current transactions
  final usage. This includes the remaining gas plus refunds from clearing storage.

  The specs calls for capping the refund at half of the total amount of gas used.

  This function is defined as `g*` in Eq.(72) in the Yellow Paper.

  ## Examples

      iex> Blockchain.Transaction.calculate_refund(%Blockchain.Transaction{gas_limit: 100}, 10, 5)
      15

      iex> Blockchain.Transaction.calculate_refund(%Blockchain.Transaction{gas_limit: 100}, 10, 99)
      55

      iex> Blockchain.Transaction.calculate_refund(%Blockchain.Transaction{gas_limit: 100}, 10, 0)
      10

      iex> Blockchain.Transaction.calculate_refund(%Blockchain.Transaction{gas_limit: 100}, 11, 99)
      55
  """
  @spec calculate_refund(t, EVM.Gas.t, EVM.SubState.refund) :: EVM.Gas.t
  def calculate_refund(trx, remaining_gas, refund) do
    # TODO: Add a math helper, finally
    max_refund = round( :math.floor( ( trx.gas_limit - remaining_gas ) / 2 ) )

    remaining_gas + min(max_refund, refund)
  end

end