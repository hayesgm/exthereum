defmodule Blockchain.Blocktree do
  @moduledoc """
  Blocktree provides functions for adding blocks to the
  overall blocktree and forming a consistent blockchain.

  We have two important issues to handle after we get a new
  unknown block:

  1. Do we accept the block? Is it valid and does it connect to
     a known parent?

  2. After we've accepted it, is it (by total difficulty) the canonical block?
     Does it become the canonical block after other blocks have been added
     to the block chain?

  TODO: Number 1.
  """

  alias Blockchain.Block

  defstruct [
    block: nil,
    children: [],
    total_difficulty: 0,
    parent_map: %{},
  ]

  @type t :: %{
    block: Block.t,
    children: [t],
    total_difficulty: integer(),
    parent_map: %{EVM.hash => EVM.hash},
  }

  @doc """
  Creates a new blocktree with a given genesis block.

  ## Examples

      iex> Blockchain.Blocktree.new_tree()
      %Blockchain.Blocktree{
        block: :root,
        children: %{},
        total_difficulty: 0,
        parent_map: %{}
      }

      iex> Blockchain.Blocktree.new_tree(%Blockchain.Block{header: %Blockchain.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}})
      %Blockchain.Blocktree{
        block: %Blockchain.Block{header: %Blockchain.Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}},
        children: %{},
        total_difficulty: 100,
        parent_map: %{<<195, 190, 212, 21, 153, 190, 242, 206, 171, 245, 168, 227, 210, 229, 154, 248, 12, 61, 129, 119, 156, 64, 253, 107, 41, 225, 82, 230, 210, 47, 161, 191>> => <<1, 2, 3>>}
      }
  """
  @spec new_tree(Block.t | nil, EMV.hash | nil) :: t
  def new_tree(gen_block \\ nil, hash \\ nil)
  def new_tree(nil, nil) do
    %__MODULE__{
      block: :root,
      children: %{},
      total_difficulty: 0,
      parent_map: %{}
    }
  end

  def new_tree(gen_block, hash) do
    # TODO: Simplify this
    hash = hash || gen_block.block_hash || Block.hash(gen_block)

    %__MODULE__{
      block: gen_block,
      children: %{},
      total_difficulty: gen_block.header.difficulty,
      parent_map: %{hash => gen_block.header.parent_hash}
    }
  end

  @doc """
  Adds a block to our complete block tree. After we verify the
  block, we will store it in our blocktree.

  Note: if we do not know the parent node, we will ignore
  the block for now.

  TODO: Perhaps we should store the block until we encounter the parent block?
  TODO: Verify the block...

  ## Examples

      iex> block_1 = %Blockchain.Block{header: %Blockchain.Block.Header{number: 5, parent_hash: <<>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> block_2 = %Blockchain.Block{header: %Blockchain.Block.Header{number: 6, parent_hash: block_1 |> Blockchain.Block.hash, beneficiary: <<2, 3, 4>>, difficulty: 110, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}}
      iex> Blockchain.Blocktree.new_tree(block_1)
      ...> |> Blockchain.Blocktree.add_block(block_2)
      %Blockchain.Blocktree{
        block: %Blockchain.Block{header: %Blockchain.Block.Header{beneficiary: <<2, 3, 4>>, difficulty: 100, extra_data: "", gas_limit: 0, gas_used: 0, logs_bloom: "", mix_hash: <<1>>, nonce: <<2>>, number: 5, ommers_hash: <<128>>, parent_hash: "", receipts_root: <<128>>, state_root: <<128>>, timestamp: 11, transactions_root: <<128>>}, ommers: [], transactions: []},
        children: %{
          <<174, 62, 229, 109, 68, 240, 136, 180, 77, 111, 144, 1, 124, 69, 148, 28, 51, 55, 232, 208, 177, 162, 29, 117, 37, 196, 242, 103, 40, 200, 224, 49>> =>
            %Blockchain.Blocktree{
              block: %Blockchain.Block{header: %Blockchain.Block.Header{beneficiary: <<2, 3, 4>>, difficulty: 110, extra_data: "", gas_limit: 0, gas_used: 0, logs_bloom: "", mix_hash: <<1>>, nonce: <<2>>, number: 6, ommers_hash: <<128>>, parent_hash: <<202, 38, 58, 121, 235, 99, 194, 87, 149, 46, 40, 168, 126, 60, 97, 224, 14, 31, 153, 91, 147, 172, 161, 23, 234, 138, 118, 175, 145, 60, 51, 14>>, receipts_root: <<128>>, state_root: <<128>>, timestamp: 11, transactions_root: <<128>>}, ommers: [], transactions: []},
              children: %{},
              parent_map: %{<<174, 62, 229, 109, 68, 240, 136, 180, 77, 111, 144, 1, 124, 69, 148, 28, 51, 55, 232, 208, 177, 162, 29, 117, 37, 196, 242, 103, 40, 200, 224, 49>> => <<202, 38, 58, 121, 235, 99, 194, 87, 149, 46, 40, 168, 126, 60, 97, 224, 14, 31, 153, 91, 147, 172, 161, 23, 234, 138, 118, 175, 145, 60, 51, 14>>},
              total_difficulty: 110
            }
        },
        total_difficulty: 110,
        parent_map: %{
          <<202, 38, 58, 121, 235, 99, 194, 87, 149, 46, 40, 168, 126, 60, 97, 224, 14, 31, 153, 91, 147, 172, 161, 23, 234, 138, 118, 175, 145, 60, 51, 14>> => <<>>,
          <<174, 62, 229, 109, 68, 240, 136, 180, 77, 111, 144, 1, 124, 69, 148, 28, 51, 55, 232, 208, 177, 162, 29, 117, 37, 196, 242, 103, 40, 200, 224, 49>> => <<202, 38, 58, 121, 235, 99, 194, 87, 149, 46, 40, 168, 126, 60, 97, 224, 14, 31, 153, 91, 147, 172, 161, 23, 234, 138, 118, 175, 145, 60, 51, 14>>
        }
      }
  """
  @spec add_block(t, Block.t) :: t
  def add_block(blocktree, block) do
    block_hash = block.block_hash || block |> Block.hash()
    blocktree = %{blocktree | parent_map: Map.put(blocktree.parent_map, block_hash, block.header.parent_hash)}

    new_tree = case get_path_to_root(blocktree, block_hash) do
      :no_path -> raise "No path to root" # TODO: How we can better handle this case?
      {:ok, path} ->
        do_add_block(blocktree, block, block_hash, path)
    end

    # TODO: Does this parent_hash only exist at the root node?

    # TODO: Add validation check
    # get_parent(block)
    # Block.is_valid?(block, parent)
  end

  # Recursively walk tree and to add children block
  @spec do_add_block(t, Block.t, EVM.hash, [EVM.hash]) :: t
  defp do_add_block(blocktree, block, block_hash, path) do
    case path do
      [] ->
        tree = new_tree(block, block_hash)
        new_children = Map.put(blocktree.children, block_hash, tree)

        %{blocktree | children: new_children, total_difficulty: max_difficulty(new_children)}
      [path_hash|rest] ->
        case blocktree.children[path_hash] do
          nil -> raise "Invalid path to root, missing path #{inspect path_hash}" # this should be impossible unless the tree is missing nodes
          sub_tree ->
            # Recurse and update the children of this tree. Note, we may also need to adjust the total
            # difficulty of this subtree.
            new_child = do_add_block(sub_tree, block, block_hash, rest)

            %{blocktree |
              children: Map.put(blocktree.children, path_hash, new_child),
              total_difficulty: max(blocktree.total_difficulty, new_child.total_difficulty)}
        end
    end
  end

  # Gets the maximum difficulty amoungst a set of child nodes
  @spec max_difficulty([t]) :: integer()
  defp max_difficulty(children) do
    Enum.map(children, fn {_, child} -> child.total_difficulty end) |> Enum.max
  end

  @doc """
  Returns a path from the given block's parent all the way up to the root of the tree. This will
  raise if any node does not have a valid path to root, and runs in O(n) time with regards to the
  height of the tree.

  ## Examples

      iex> Blockchain.Blocktree.get_path_to_root(
      ...>   %Blockchain.Blocktree{parent_map: %{<<1>> => <<2>>, <<2>> => <<3>>, <<3>> => <<>>}},
      ...>   <<1>>)
      {:ok, [<<3>>, <<2>>]}

      iex> Blockchain.Blocktree.get_path_to_root(
      ...>   %Blockchain.Blocktree{parent_map: %{<<20>> => <<10>>, <<10>> => <<>>}},
      ...>   <<20>>)
      {:ok, [<<10>>]}

      iex> Blockchain.Blocktree.get_path_to_root(
      ...>   %Blockchain.Blocktree{parent_map: %{<<30>> => <<20>>, <<31>> => <<20>>, <<20>> => <<10>>, <<21 >> => <<10>>, <<10>> => <<>>}},
      ...>   <<30>>)
      {:ok, [<<10>>, <<20>>]}

      iex> Blockchain.Blocktree.get_path_to_root(
      ...>   %Blockchain.Blocktree{parent_map: %{<<30>> => <<20>>, <<31>> => <<20>>, <<20>> => <<10>>, <<21 >> => <<10>>, <<10>> => <<>>}},
      ...>   <<20>>)
      {:ok, [<<10>>]}

      iex> Blockchain.Blocktree.get_path_to_root(
      ...>   %Blockchain.Blocktree{parent_map: %{<<30>> => <<20>>, <<31>> => <<20>>, <<20>> => <<10>>, <<21 >> => <<10>>, <<10>> => <<>>}},
      ...>   <<31>>)
      {:ok, [<<10>>, <<20>>]}

      iex> Blockchain.Blocktree.get_path_to_root(
      ...>   %Blockchain.Blocktree{parent_map: %{<<30>> => <<20>>, <<31>> => <<20>>, <<20>> => <<10>>, <<21 >> => <<10>>, <<10>> => <<>>}},
      ...>   <<32>>)
      :no_path
  """
  @spec get_path_to_root(t, EVM.hash) :: {:ok, [EVM.hash]} | :no_path
  def get_path_to_root(blocktree, hash) do
    # TODO: Reverse, etc
    case do_get_path_to_root(blocktree, hash) do
      {:ok, path} -> {:ok, Enum.reverse(path)}
      els -> els
    end
  end

  @spec do_get_path_to_root(t, EVM.hash) :: {:ok, [EVM.hash]} | :no_path
  defp do_get_path_to_root(blocktree, hash) do
    case Map.get(blocktree.parent_map, hash, :no_path) do
      :no_path -> :no_path
      <<>> -> {:ok, []}
      parent_hash -> case do_get_path_to_root(blocktree, parent_hash) do
        :no_path -> :no_path
        {:ok, <<>>} -> {:ok, [parent_hash]}
        {:ok, path} -> {:ok, [parent_hash | path]}
      end
    end
  end

end