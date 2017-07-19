defmodule Blockchain.Account do
  @moduledoc """
  Represents the state of an account, as defined in Section 4
  of the Yellow Paper.
  """

  alias MerklePatriciaTrie.Trie

  @empty_keccak BitHelper.kec(<<>>)
  @empty_trie   <<>> # TODO: Is this the empty trie?

  # State defined in Section 4.1 of the Yellow Paper
  defstruct [
    nonce: 0,                  # σn
    balance: 0,                # σb
    storage_root: @empty_trie, # σs
    code_hash: @empty_keccak,  # σc
  ]

  # Types defined as Eq.(12) of the Yellow Paper
  @type t :: %{
    nonce: integer(),
    balance: EVM.Wei.t,
    storage_root: EVM.trie_root,
    code_hash: MerklePatriciaTrie.Trie.key,
  }

  @doc """
  Checks whether or not an account is a non-contract account. This is defined in the latter
  part of Section 4.1 of the Yellow Paper.

  ## Examples

      iex> Blockchain.Account.is_simple_account?(%Blockchain.Account{})
      true

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
      [0, 0, <<>>, <<167, 255, 198, 248, 191, 30, 215, 102, 81, 193, 71, 86, 160, 97,
                     214, 98, 245, 128, 255, 77, 228, 59, 73, 250, 130, 216, 10, 75,
                     128, 248, 67, 74>>]
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

      iex> Blockchain.Account.deserialize([<<0>>, <<0>>, <<>>, <<167, 255, 198, 248, 191, 30, 215, 102, 81, 193, 71, 86, 160, 97, 214, 98, 245, 128, 255, 77, 228, 59, 73, 250, 130, 216, 10, 75, 128, 248, 67, 74>>])
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
      iex> MerklePatriciaTrie.Trie.new()
      ...> |> MerklePatriciaTrie.Trie.update(<<0x01::160>>, RLP.encode([5, 6, <<1>>, <<2>>]))
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{nonce: 5, balance: 6, storage_root: <<0x01>>, code_hash: <<0x02>>}

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> MerklePatriciaTrie.Trie.new()
      ...> |> MerklePatriciaTrie.Trie.update(<<0x01::160>>, <<>>)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      nil

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> MerklePatriciaTrie.Trie.new()
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      nil
  """
  @spec get_account(EVM.state, EVM.address) :: t | nil
  def get_account(state, address) do
    case Trie.get(state, address) do
      nil -> nil
      <<>> -> nil # TODO: Is this the same as deleting the account?
      encoded_account ->
          encoded_account
          |> RLP.decode()
          |> deserialize()
    end
  end

  @doc """
  Helper function to load multiple accounts.

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.update(MerklePatriciaTrie.Trie.new(), <<0x01::160>>, RLP.encode([5, 6, <<1>>, <<2>>]))
      iex> Blockchain.Account.get_accounts(state, [<<0x01::160>>, <<0x02::160>>])
      [
        %Blockchain.Account{nonce: 5, balance: 6, storage_root: <<0x01>>, code_hash: <<0x02>>},
        nil
      ]
  """
  @spec get_accounts(EVM.state, [EVM.address]) :: [t | nil]
  def get_accounts(state, addresses) do
    for address <- addresses, do: get_account(state, address)
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
  Completely removes an account from the world state. This is used,
  for instance, after a suicide. This is defined from Eq.(77) and
  Eq.(78) in the Yellow Paper.

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      ...>   |> Blockchain.Account.del_account(<<0x01::160>>)
      ...>   |> Blockchain.Account.get_account(<<0x01::160>>)
      nil

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.del_account(<<0x01::160>>)
      ...>   |> Blockchain.Account.get_account(<<0x01::160>>)
      nil
  """
  @spec del_account(EVM.state, EVM.address) :: EVM.state
  def del_account(state, address) do
    Trie.update(state, address, <<>>)
  end

  @doc """
  Gets and updates an account based on a given input
  function `fun`. Account passed to `fun` will be blank
  instead of nil if account doesn't exist.

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      ...>   |> Blockchain.Account.update_account(<<0x01::160>>, fn (acc) -> %{acc | balance: acc.balance + 5} end)
      ...>   |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{balance: 15}

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> MerklePatriciaTrie.Trie.new()
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

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{nonce: 10})
      iex> state
      ...> |> Blockchain.Account.increment_nonce(<<0x01::160>>)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{nonce: 11}
  """
  @spec increment_nonce(EVM.state, EVM.address) :: EVM.state
  def increment_nonce(state, address) do
    update_account(state, address, fn (acct) ->
      %{acct | nonce: acct.nonce + 1}
    end)
  end

  @doc """
  Simple helper function to adjust wei in an account. Wei may be
  positive (to add wei) or negative (to remove it). This function
  will raise if we attempt to reduce wei in an account to less than zero.

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> state
      ...> |> Blockchain.Account.add_wei(<<0x01::160>>, 13)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{balance: 23}

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> state
      ...> |> Blockchain.Account.add_wei(<<0x01::160>>, -3)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{balance: 7}

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> state
      ...> |> Blockchain.Account.add_wei(<<0x01::160>>, -13)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      ** (RuntimeError) wei reduced to less than zero
  """
  @spec add_wei(EVM.state, EVM.address, EVM.Wei.t) :: EVM.state
  def add_wei(state, address, delta_wei) do
    update_account(state, address, fn (acct) ->
      updated_balance = acct.balance + delta_wei

      if updated_balance < 0, do: raise "wei reduced to less than zero"

      %{acct | balance: updated_balance}
    end)
  end

  @doc """
  Even simpler helper function to adjust wei in an account negatively. Wei
  may be positive (to subtract wei) or negative (to add it). This function
  will raise if we attempt to reduce wei in an account to less than zero.

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> state
      ...> |> Blockchain.Account.dec_wei(<<0x01::160>>, 3)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{balance: 7}

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> state
      ...> |> Blockchain.Account.dec_wei(<<0x01::160>>, 13)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      ** (RuntimeError) wei reduced to less than zero

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>   |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      iex> state
      ...> |> Blockchain.Account.dec_wei(<<0x01::160>>, -3)
      ...> |> Blockchain.Account.get_account(<<0x01::160>>)
      %Blockchain.Account{balance: 13}
  """
  @spec dec_wei(EVM.state, EVM.address, EVM.Wei.t) :: EVM.state
  def dec_wei(state, address, delta_wei), do: add_wei(state, address, -1 * delta_wei)

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

  Note: transferring value to an empty account still adds value to said account,
        even though it's effectively a zombie.

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
    # TODO: Decide if we want to waste the cycles to pull
    # the account information when `add_wei` will do that itself.
    from_account = get_account(state, from)

    cond do
      wei < 0 -> {:error, "wei transfer cannot be negative"}
      from_account == nil -> {:error, "sender account does not exist"}
      from_account.balance < wei -> {:error, "sender account insufficient wei"}
      true ->
        {:ok,
          state
            |> add_wei(from, -1 * wei)
            |> add_wei(to, wei)
        }
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
  Puts code into a given account. Note, this will handle
  the aspect that we need to store the code_hash outside of the
  contract itself and only store the KEC of the code_hash.

  This is defined in Eq.(98) and address in Section 4.1 under
  `codeHash` in the Yellow Paper.

  Not sure if this is correct, but I'm going to store the code_hash
  in state, as well as the link to it in the Account object itself.

  TODO: Verify the above ^^^ is accurate, as it's not spelled out
        in the Yellow Paper directly.

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> state = MerklePatriciaTrie.Trie.new()
      ...> |> Blockchain.Account.put_code(<<0x01::160>>, <<1, 2, 3>>)
      iex> Blockchain.Account.get_account(state, <<0x01::160>>)
      %Blockchain.Account{code_hash: <<253, 23, 128, 166, 252, 158, 224, 218, 178, 108, 235,
                                       75, 57, 65, 171, 3, 230, 108, 205, 151, 13, 29, 185, 22, 18, 198,
                                       109, 244, 81, 91, 10, 10>>}
      iex> MerklePatriciaTrie.Trie.get(state, BitHelper.kec(<<1, 2, 3>>))
      <<1, 2, 3>>
  """
  @spec put_code(EVM.state, EVM.address, EVM.MachineCode.t) :: EVM.state
  def put_code(state, contract_address, machine_code) do
    kec = BitHelper.kec(machine_code)

    state
      |> Trie.update(kec, machine_code)
      |> update_account(contract_address, fn (acct) ->
        %{acct | code_hash: kec}
      end)
  end

  @doc """
  Returns the machine code associated with the account at the given
  address. This will return nil if the contract has
  no associated code (i.e. it is a simple account).

  We may return `:not_found`, indicating that we were not able to
  find the given code hash in the state trie.

  Alternatively, we will return `{:ok, machine_code}` where `machine_code`
  may be the empty string `<<>>`.

  Note from Yellow Paper:
    > "it is assumed that the client will have stored the pair (KEC(I_b), I_b)
       at some point prior in order to make the determinatio of Ib feasible"

  ## Examples

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> MerklePatriciaTrie.Trie.new()
      ...> |> Blockchain.Account.get_machine_code(<<0x01::160>>)
      {:ok, <<>>}

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> MerklePatriciaTrie.Trie.new()
      ...> |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{code_hash: <<555>>})
      ...> |> Blockchain.Account.get_machine_code(<<0x01::160>>)
      :not_found

      iex> MerklePatriciaTrie.DB.ETS.init()
      iex> MerklePatriciaTrie.Trie.new()
      ...> |> Blockchain.Account.put_code(<<0x01::160>>, <<1, 2, 3>>)
      ...> |> Blockchain.Account.get_machine_code(<<0x01::160>>)
      {:ok, <<1, 2, 3>>}
  """
  @spec get_machine_code(EVM.state, EVM.address) :: {:ok, EVM.MachineState.t} | :not_found
  def get_machine_code(state, contract_address) do
    # TODO: Do we have a standard for default account values
    account = get_account(state, contract_address) || %__MODULE__{}

    case account.code_hash do
      @empty_keccak -> {:ok, <<>>}
      code_hash ->
        case Trie.get(state, code_hash) do
          nil -> :not_found
          machine_code when is_binary(machine_code) -> {:ok, machine_code}
        end
    end

  end

end