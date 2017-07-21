defmodule Blockchain.Block do
  @moduledoc """
  This module effective encodes a Block, the heart of the blockchain. A chain is
  formed when blocks point to previous blocks, either as a parent or an ommer (uncle).
  For more information, see Section 4.4 of the Yellow Paper.
  """

  alias Blockchain.Block.Header
  alias Blockchain.Transaction

  # Defined in Eq.(18)
  defstruct [
    header: %Header{}, # B_H
    transactions: [],  # B_T
    ommers: [],        # B_U
  ]

  @type t :: %{
    header: Header.t,
    transactions: [Transaction.t],
    ommers: [Header.t],
  }

  @d_0 131_072 # Eq.(40)
  @min_gas_limit 125_000 # Eq.(47)

  @doc """
  Encodes a block such that it can be represented in
  RLP encoding. This is defined as L_B Eq.(33) in the Yellow Paper.

  ## Examples

    iex> Blockchain.Block.serialize(%Blockchain.Block{
    ...>   header: %Blockchain.Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>},
    ...>   transactions: [%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}],
    ...>   ommers: [%Blockchain.Block.Header{parent_hash: <<11::256>>, ommers_hash: <<12::256>>, beneficiary: <<13::160>>, state_root: <<14::256>>, transactions_root: <<15::256>>, receipts_root: <<16::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<17::256>>, nonce: <<18::64>>}]
    ...> })
    [
      [<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, 5, 1, 5, 3, 6, "Hi mom", <<7::256>>, <<8::64>>],
      [[5, 6, 7, <<1::160>>, 8, "hi", 27, 9, 10]],
      [[<<11::256>>, <<12::256>>, <<13::160>>, <<14::256>>, <<15::256>>, <<16::256>>, <<>>, 5, 1, 5, 3, 6, "Hi mom", <<17::256>>, <<18::64>>]]
    ]

    iex> Blockchain.Block.serialize(%Blockchain.Block{})
    [[nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0, nil, "", nil, nil], [], []]
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

  @doc """
  Creates a new block from a parent block. This will handle setting
  the block number, the difficulty and will keep the `gas_limit` the
  same as the parent's block unless specified in `opts`.

  A timestamp is required for difficulty calculation.
  If it's not specified, it will default to the current system time.

  This function is not directly addressed in the Yellow Paper.

  ## Examples

      iex> %Blockchain.Block{header: %Blockchain.Block.Header{number: 100_000, difficulty: 131072, timestamp: 5000, gas_limit: 500_000}}
      ...> |> Blockchain.Block.gen_child_block(timestamp: 5010)
      %Blockchain.Block{header: %Blockchain.Block.Header{number: 100_001, difficulty: 131136, timestamp: 5010, gas_limit: 500_000}}
  """
  @spec gen_child_block(t, integer() | nil) :: t
  def gen_child_block(parent_block, opts \\ []) do
    timestamp = opts[:timestamp] || System.system_time(:second)
    gas_limit = opts[:gas_limit] || parent_block.header.gas_limit

    %Blockchain.Block{header: %Blockchain.Block.Header{timestamp: timestamp}}
    |> set_block_number(parent_block)
    |> set_block_difficulty(parent_block)
    |> set_block_gas_limit(parent_block, gas_limit)
  end

  @doc """
  Calculates the `number` for a new block. This implements Eq.(38) from
  the Yellow Paper.

  ## Examples

      iex> Blockchain.Block.set_block_number(%Blockchain.Block{header: %Blockchain.Block.Header{extra_data: "hello"}}, %Blockchain.Block{header: %Blockchain.Block.Header{number: 32}})
      %Blockchain.Block{header: %Blockchain.Block.Header{number: 33, extra_data: "hello"}}
  """
  @spec set_block_number(t, t) :: integer()
  def set_block_number(block=%Blockchain.Block{header: header}, parent_block=%Blockchain.Block{header: %Blockchain.Block.Header{number: parent_number}}) do
    %{block | header: %{header | number: parent_number + 1}}
  end

  @doc """
  Calculates the difficulty of a new block. This implements Eq.(39),
  Eq.(40), Eq.(41), Eq.(42), Eq.(43) and Eq.(44) of the Yellow Paper.

  # TODO: Validate these results

  ## Examples

      iex> Blockchain.Block.set_block_difficulty(
      ...>   %Blockchain.Block{header: %Blockchain.Block.Header{number: 0, timestamp: 55}},
      ...>   nil
      ...> )
      %Blockchain.Block{header: %Blockchain.Block.Header{number: 0, timestamp: 55, difficulty: 131_072}}

      iex> Blockchain.Block.set_block_difficulty(
      ...>   %Blockchain.Block{header: %Blockchain.Block.Header{number: 33, timestamp: 66}},
      ...>   %Blockchain.Block{header: %Blockchain.Block.Header{number: 32, timestamp: 55, difficulty: 300_000}}
      ...> )
      %Blockchain.Block{header: %Blockchain.Block.Header{number: 33, timestamp: 66, difficulty: 300_146}}

      iex> Blockchain.Block.set_block_difficulty(
      ...>   %Blockchain.Block{header: %Blockchain.Block.Header{number: 33, timestamp: 88}},
      ...>   %Blockchain.Block{header: %Blockchain.Block.Header{number: 32, timestamp: 55, difficulty: 300_000}}
      ...> )
      %Blockchain.Block{header: %Blockchain.Block.Header{number: 33, timestamp: 88, difficulty: 299_854}}

      # TODO: Is this right? These numbers are quite a jump
      iex> Blockchain.Block.set_block_difficulty(
      ...>   %Blockchain.Block{header: %Blockchain.Block.Header{number: 3_000_001, timestamp: 66}},
      ...>   %Blockchain.Block{header: %Blockchain.Block.Header{number: 3_000_000, timestamp: 55, difficulty: 300_000}}
      ...> )
      %Blockchain.Block{header: %Blockchain.Block.Header{number: 3_000_001, timestamp: 66, difficulty: 268_735_456}}

      iex> Blockchain.Block.set_block_difficulty(
      ...>   %Blockchain.Block{header: %Blockchain.Block.Header{number: 3_000_001, timestamp: 155}},
      ...>   %Blockchain.Block{header: %Blockchain.Block.Header{number: 3_000_000, timestamp: 55, difficulty: 300_000}}
      ...> )
      %Blockchain.Block{header: %Blockchain.Block.Header{number: 3_000_001, timestamp: 155, difficulty: 268_734_142}}
  """
  @spec set_block_difficulty(t, t) :: integer()
  def set_block_difficulty(block=%Blockchain.Block{header: header}, parent_block) do
    difficulty = cond do
      header.number == 0 -> @d_0
      Header.is_before_homestead?(header) -> max(@d_0, parent_block.header.difficulty + difficulty_x(parent_block.header.difficulty) * difficulty_s1(header, parent_block.header) + difficulty_e(header))
      true -> max(@d_0, parent_block.header.difficulty + difficulty_x(parent_block.header.difficulty) * difficulty_s2(header, parent_block.header) + difficulty_e(header))
    end

    %{block | header: %{header | difficulty: difficulty}}
  end

  # Eq.(42) ς1
  defp difficulty_s1(block_header, parent_header) do
    if block_header.timestamp < ( parent_header.timestamp + 13 ), do: 1, else: -1
  end

  # Eq.(43) ς2
  defp difficulty_s2(block_header, parent_header) do
    s = MathHelper.floor( ( block_header.timestamp - parent_header.timestamp ) / 10 )
    max(1 - s, -99)
  end

  # Eq.(41) x
  defp difficulty_x(parent_difficulty), do: MathHelper.floor(parent_difficulty / 2048)

  # Eq.(44) ε
  defp difficulty_e(block_header) do
    MathHelper.floor(
      :math.pow(
        2,
        MathHelper.floor( block_header.number / 100_000 ) - 2
      )
    )
  end

  @doc """
  Sets the gas limit of a given block, or raises
  if the block limit is not acceptable. The validity
  check is defined in Eq.(45), Eq.(46) and Eq.(47) of
  the Yellow Paper.

  ## Examples

      iex> Blockchain.Block.set_block_gas_limit(
      ...>   %Blockchain.Block{header: %Blockchain.Block.Header{}},
      ...>   %Blockchain.Block{header: %Blockchain.Block.Header{gas_limit: 1_000_000}},
      ...>   1_000_500
      ...> )
      %Blockchain.Block{header: %Blockchain.Block.Header{gas_limit: 1_000_500}}

      iex> Blockchain.Block.set_block_gas_limit(
      ...>   %Blockchain.Block{header: %Blockchain.Block.Header{}},
      ...>   %Blockchain.Block{header: %Blockchain.Block.Header{gas_limit: 1_000_000}},
      ...>   2_000_000
      ...> )
      ** (RuntimeError) Block gas limit not valid
  """
  @spec set_block_gas_limit(t, t, EVM.Gas.t) :: t
  def set_block_gas_limit(block, parent_block, gas_limit) do
    if not is_gas_limit_valid?(gas_limit, parent_block.header.gas_limit), do: raise "Block gas limit not valid"

    %{block | header: %{block.header | gas_limit: gas_limit}}
  end

  @doc """
  Function to determine if the gas limit set is valid. The miner gets to
  specify a gas limit, so long as it's in range. This allows about a 0.1% change
  per block.

  This function directly implements Eq.(45), Eq.(46) and Eq.(47).

  ## Examples

      iex> Blockchain.Block.is_gas_limit_valid?(1_000_000, 1_000_000)
      true

      iex> Blockchain.Block.is_gas_limit_valid?(1_000_000, 2_000_000)
      false

      iex> Blockchain.Block.is_gas_limit_valid?(1_000_000, 500_000)
      false

      iex> Blockchain.Block.is_gas_limit_valid?(1_000_000, 999_500)
      true

      iex> Blockchain.Block.is_gas_limit_valid?(1_000_000, 999_000)
      false
  """
  @spec is_gas_limit_valid?(EVM.Gas.t, EVM.Gas.t) :: boolean()
  def is_gas_limit_valid?(gas_limit, parent_gas_limit) do
    max_delta = MathHelper.floor(parent_gas_limit / 1024)

    ( gas_limit < parent_gas_limit + max_delta ) and
    ( gas_limit > parent_gas_limit - max_delta ) and
    gas_limit > @min_gas_limit
  end

  @doc """
  Determines whether or not a block is valid. This is
  defined in Eq.(29) of the Yellow Paper.

  # TODO: This is going to be pretty serious,
  since it will involve us literally running the block.
  """
  @spec block_valid?(t) :: boolean()
  def block_valid?(block), do: true

  @doc """
  For a given block, this will add the given transactions to its
  list of transaction and update the header state accordingly. That
  is, we will execute each transaction and update the state root,
  transaction receipts, etc. We effectively implement Eq.(2), Eq.(3)
  and Eq.(4) of the Yellow Paper, referred to as Π.

  The trie db refers to where we expect our trie to exist, e.g.
  in `:ets` or `:leveldb`. See `MerklePatriciaTrie.DB`.

  # TODO: Add a rich set of test cases in `block_test.exs`

  ## Examples

      # Create a contract
      iex> beneficiary = <<0x05::160>>
      iex> private_key = <<1::256>>
      iex> sender = <<82, 43, 246, 253, 8, 130, 229, 143, 111, 235, 9, 107, 65, 65, 123, 79, 140, 105, 44, 57>> # based on simple private key
      iex> contract_address = Blockchain.Contract.new_contract_address(sender, 6)
      iex> machine_code = EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return])
      iex> trx = %Blockchain.Transaction{nonce: 5, gas_price: 3, gas_limit: 100_000, to: <<>>, value: 5, init: machine_code}
      ...>           |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> state = MerklePatriciaTrie.Trie.new()
      ...>           |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 400_000, nonce: 5})
      iex> block = %Blockchain.Block{header: %Blockchain.Block.Header{state_root: state.root_hash, beneficiary: beneficiary}, transactions: []}
      ...>           |> Blockchain.Block.add_transactions_to_block([trx], :ets)
      iex> Enum.count(block.transactions)
      1
      iex> MerklePatriciaTrie.Trie.new(root_hash: block.header.state_root)
      ...> |> Blockchain.Account.get_accounts([sender, beneficiary, contract_address])
      [%Blockchain.Account{balance: 238727, nonce: 6}, %Blockchain.Account{balance: 161268}, %Blockchain.Account{balance: 5, code_hash: <<184, 49, 71, 53, 90, 147, 31, 209, 13, 252, 14, 242, 188, 146, 213, 98, 3, 169, 138, 178, 91, 23, 65, 191, 149, 7, 79, 68, 207, 121, 218, 225>>}]

  """
  @spec add_transactions_to_block(t, [Transaction.t], atom()) :: t
  def add_transactions_to_block(block, transactions, trie_db) do
    do_add_transactions_to_block(block, transactions, trie_db)
  end

  defp do_add_transactions_to_block(block, [], _), do: block
  defp do_add_transactions_to_block(block=%__MODULE__{header: header}, [trx|transactions], trie_db) do
    state = MerklePatriciaTrie.Trie.new(db: trie_db, root_hash: header.state_root)
    new_state = Blockchain.Transaction.execute_transaction(state, trx, header)
    total_transactions = block.transactions ++ [trx]
    updated_header = %{header | state_root: new_state.root_hash}
    # TODO: gas, etc?

    updated_block = %{block | header: updated_header, transactions: total_transactions}

    do_add_transactions_to_block(updated_block, transactions, trie_db)
  end

end