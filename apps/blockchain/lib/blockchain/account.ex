defmodule Blockchain.Account do
  @moduledoc """
  Represents the state of an account, as defined in Section 4
  of the Yellow Paper.
  """

  alias MerklePatriciaTrie.Trie

  # State defined in Section 4.1 of the Yellow Paper
  defstruct [
    nonce: 0,            # σn
    balance: 0,          # σb
    storage_root: <<>>,  # σs
    code_hash: <<>>,     # σc
  ]

  # Types defined as Eq.(12) of the Yellow Paper
  @type t :: %{
    nonce: integer(),
    balance: EVM.Wei.t,
    storage_root: EVM.trie_root,
    code_hash: MerklePatriciaTrie.Trie.key,
  }

  @empty_keccak BitHelper.kec(<<>>)

  @doc """
  Helper function for transferring eth for one account to another.
  This handles the fact that a new account may be shadow-created if
  it receives eth. See Section 8, Eq.(100), Eq.(101), Eq.(102, Eq.(103),
  and Eq.(104) of the Yellow Paper.

  The Yellow Paper assumes this function will always succeed (as the checks
  occur before this function is called), but we'll check just in case
  this function is not properly called. The only case will be if the
  sending account is nil or has an insufficient balance, but we add
  a few extra checks just in case.

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      ...>   |> Blockchain.Account.put_account(<<0x02::160>>, %Blockchain.Account{balance: 5})
      iex> {:ok, state} = Blockchain.Account.transfer(state, <<0x01::160>>, <<0x02::160>>, 3)
      iex> {Blockchain.Account.get_account(state, <<0x01::160>>), Blockchain.Account.get_account(state, <<0x02::160>>)}
      {%Blockchain.Account{balance: 7}, %Blockchain.Account{balance: 8}}

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> {:ok, state} = Blockchain.Account.transfer(state, <<0x01::160>>, <<0x02::160>>, 3)
      iex> {Blockchain.Account.get_account(state, <<0x01::160>>), Blockchain.Account.get_account(state, <<0x02::160>>)}
      {%Blockchain.Account{balance: 7}, %Blockchain.Account{balance: 3}}

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> Blockchain.Account.transfer(state, <<0x01::160>>, <<0x02::160>>, 12)
      {:error, "sender account insufficient wei"}

      iex> Blockchain.Account.transfer(MerklePatriciaTrie.Trie.new(), <<0x01::160>>, <<0x02::160>>, -3)
      {:error, "wei transfer cannot be negative"}
  """
  @spec transfer(EVM.state, EVM.address, EVM.address, EVM.Wei.t) :: {:ok, EVM.state} | {:error, String.t}
  def transfer(state, from, to, wei) do
    # Transferring value to an empty account still adds value to said account,
    # even though it's effectively a zombie.
    from_account = get_account(state, from)

    to_account = case get_account(state, to) do
      nil -> %__MODULE__{}
      acct -> acct
    end

    cond do
      wei < 0 -> {:error, "wei transfer cannot be negative"}
      from_account == nil -> {:error, "sender account does not exist"}
      true ->
        from_account_new_balance = from_account.balance - wei
        to_account_new_balance = to_account.balance + wei

        cond do
          from_account_new_balance < 0 -> {:error, "sender account insufficient wei"}
          from_account_new_balance > from_account.balance -> {:error, "sender account cannot increase from transfer"}
          to_account_new_balance < to_account.balance -> {:error, "receiver account cannot decrease from transfer"}
          true ->
            {:ok, state
              |> put_account(from, %{from_account | balance: from_account_new_balance})
              |> put_account(to, %{to_account | balance: to_account_new_balance})}
        end
    end
  end

  @doc """
  Performs transfer but raises instead of returning if an error occurs.

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      ...>   |> Blockchain.Account.put_account(<<0x02::160>>, %Blockchain.Account{balance: 5})
      iex> state = Blockchain.Account.transfer!(state, <<0x01::160>>, <<0x02::160>>, 3)
      iex> {Blockchain.Account.get_account(state, <<0x01::160>>), Blockchain.Account.get_account(state, <<0x02::160>>)}
      {%Blockchain.Account{balance: 7}, %Blockchain.Account{balance: 8}}
  """
  @spec transfer(EVM.state, EVM.address, EVM.address, EVM.Wei.t) :: EVM.state
  def transfer!(state, from, to, wei) do
    case transfer(state, from, to, wei) do
      {:ok, state} -> state
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Checks whether or not an account is a non-contract account. This is defined in the latter
  part of Section 4.1 of the Yellow Paper.

  ## Examples

      iex> Blockchain.Account.is_simple_account?(%Blockchain.Account{})
      false

      iex> Blockchain.Account.is_simple_account?(%Blockchain.Account{code_hash: <<0x01, 0x02>>})
      false

      iex> Blockchain.Account.is_simple_account?(%Blockchain.Account{code_hash: <<167, 255, 198, 248, 191, 30, 215, 102, 81, 193, 71, 86, 160, 97, 214, 98, 245, 128, 255, 77, 228, 59, 73, 250, 130, 216, 10, 75, 128, 248, 67, 74>>})
      true
  """
  @spec is_simple_account?(t) :: boolean()
  def is_simple_account?(acct) do
    acct.code_hash == @empty_keccak
  end

  @doc """
  Encodes an account such that it can be represented in RLP encoding.
  This is defined as Eq.(10) `p` in the Yellow Paper.

  ## Examples

      iex> Blockchain.Account.serialize(%Blockchain.Account{nonce: 5, balance: 10, storage_root: <<0x00, 0x01>>, code_hash: <<0x01, 0x02>>})
      [5, 10, <<0x00, 0x01>>, <<0x01, 0x02>>]

      iex> Blockchain.Account.serialize(%Blockchain.Account{})
      [0, 0, <<>>, <<>>]
  """
  @spec serialize(t) :: RLP.t
  def serialize(account) do
    [
      account.nonce,
      account.balance,
      account.storage_root,
      account.code_hash
    ]
  end

  @doc """
  Decodes an account from an RLP encodable structure.
  This is defined as Eq.(10) `p` in the Yellow Paper (reversed).

  ## Examples

      iex> Blockchain.Account.deserialize([<<5>>, <<10>>, <<0x00, 0x01>>, <<0x01, 0x02>>])
      %Blockchain.Account{nonce: 5, balance: 10, storage_root: <<0x00, 0x01>>, code_hash: <<0x01, 0x02>>}

      iex> Blockchain.Account.deserialize([<<0>>, <<0>>, <<>>, <<>>])
      %Blockchain.Account{}
  """
  @spec deserialize(RLP.t) :: t
  def deserialize(rlp) do
    [
      nonce,
      balance,
      storage_root,
      code_hash
    ] = rlp

    %Blockchain.Account{nonce: :binary.decode_unsigned(nonce), balance: :binary.decode_unsigned(balance), storage_root: storage_root, code_hash: code_hash}
  end

  @doc """
  Loads an account from an address, as defined in Eq.(9), Eq.(10), Eq.(11)
  and Eq.(12) of the Yellow Paper.

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.update(MerklePatriciaTrie.Trie.new(), <<0x01::160>>, RLP.encode([5, 6, <<1>>, <<2>>]))
      iex> Blockchain.Account.get_account(state, <<0x01::160>>)
      %Blockchain.Account{nonce: 5, balance: 6, storage_root: <<0x01>>, code_hash: <<0x02>>}
  """
  @spec get_account(EVM.state, EVM.address) :: t | nil
  def get_account(state, address) do
    case Trie.get(state, address) do
      nil -> nil
      encoded_account ->
          encoded_account
          |> RLP.decode()
          |> deserialize()
    end
  end

  @doc """
  Stores an account at a given address. This function handles serializing
  the account, encoding it to RLP and placing into the given state trie.

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = Blockchain.Account.put_account(MerklePatriciaTrie.Trie.new(), <<0x01::160>>, %Blockchain.Account{nonce: 5, balance: 6, storage_root: <<0x01>>, code_hash: <<0x02>>})
      iex> MerklePatriciaTrie.Trie.get(state, <<0x01::160>>) |> RLP.decode
      [<<5>>, <<6>>, <<0x01>>, <<0x02>>]
  """
  @spec put_account(EVM.state, EVM.address, t) :: EVM.state
  def put_account(state, address, account) do
    encoded_account = account
      |> serialize()
      |> RLP.encode()

    Trie.update(state, address, encoded_account)
  end

  @doc """
  Gets and updates an account based on a given input
  function `fun`. Account passed to `fun` will be blank
  instead of nil if account doesn't exist.

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      ...>   |> Blockchain.Account.update_account(<<0x01::160>>, fn (acc) -> %{acc | balance: acc.balance + 5} end)
      ...>   |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{balance: 15}

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.update_account(<<0x01::160>>, fn (acc) -> %{acc | nonce: acc.nonce + 1} end)
      ...>   |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{nonce: 1}
  """
  @spec update_account(EVM.state, EVM.address, (t -> t)) :: EVM.state
  def update_account(state, address, fun) do
    account = get_account(state, address) || %__MODULE__{}
    updated_account = fun.(account)

    put_account(state, address, updated_account)
  end

  @doc """
  Simple helper function to increment a nonce value.

  TODO: Add tests
  """
  @spec increment_nonce(EVM.state, EVM.address) :: EVM.state
  def increment_nonce(state, address) do

  end

  @doc """
  Simple helper function to adjust wei in an account.

  TODO: Add tests
  """
  @spec add_wei(EVM.state, EVM.address, EVM.Wei.t) :: EVM.state
  def add_wei(state, address, delta_wei) do

  end

end