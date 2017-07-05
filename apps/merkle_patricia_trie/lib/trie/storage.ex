defmodule MerklePatriciaTrie.Trie.Storage do
  @moduledoc """
  Module to get and put nodes in a trie by the given
  storage mechanism. Generally, handles the function n(I, i)
  from http://gavwood.com/Paper.pdf
  """

  alias MerklePatriciaTrie.Trie
  alias MerklePatriciaTrie.Trie.Helper

  @max_rlp_len 32

  @doc """
  Takes an RLP-encoded node and pushes it to storage,
  as defined by n(I, i).

  ## Examples

    iex> MerklePatriciaTrie.DB.ETS.init()
    iex> trie = %MerklePatriciaTrie.Trie{db: MerklePatriciaTrie.DB.ETS}
    iex> MerklePatriciaTrie.Trie.Storage.put_node(<<>>, trie)
    nil
    iex> MerklePatriciaTrie.Trie.Storage.put_node(RLP.encode("Hi"), trie)
    <<130, 72, 105>>
    iex> MerklePatriciaTrie.Trie.Storage.put_node(RLP.encode(["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]), trie)
    <<254, 112, 17, 90, 21, 82, 19, 29, 72, 106, 175, 110, 87, 220, 249, 140, 74, 165, 64, 94, 174, 79, 78, 189, 145, 143, 92, 53, 173, 136, 220, 145>>
  """
  @spec put_node(RLP.t, Trie.t) :: nil | binary()
  def put_node(rlp_encoded_node, trie) do
    case byte_size(rlp_encoded_node) do
      0 -> nil # nil is nil
      x when x < @max_rlp_len -> rlp_encoded_node # return node itself
      _ ->
        node_hash = :keccakf1600.sha3_256(rlp_encoded_node) # sha3
        trie.db.put!(node_hash, rlp_encoded_node) # store in db

        node_hash # return hash
    end
  end

  @doc """
  Gets the RLP encoded value of a given trie root, that is,
  we decodes n(I, i) from the yellow paper

  ## Examples

    iex> MerklePatriciaTrie.DB.ETS.init()
    iex> trie = %MerklePatriciaTrie.Trie{db: MerklePatriciaTrie.DB.ETS}
    iex> MerklePatriciaTrie.Trie.Storage.get_node(%{trie| root_hash: <<130, 72, 105>>})
    "Hi"
    # iex> MerklePatriciaTrie.Trie.Storage.get_node(%{trie| root_hash: <<254, 112, 17, 90, 21, 82, 19, 29, 72, 106, 175, 110, 87, 220, 249, 140, 74, 165, 64, 94, 174, 79, 78, 189, 145, 143, 92, 53, 173, 136, 220, 145>>})
    # (RuntimeError) "Cannot find value in DB: [15, 14, 7, 0, 1, 1, 5, 10, 1, 5, 5, 2, 1, 3, 1, 13, 4, 8, 6, 10, 10, 15, 6, 14, 5, 7, 13, 12, 15, 9, 8, 12, 4, 10, 10, 5, 4, 0, 5, 14, 10, 14, 4, 15, 4, 14, 11, 13, 9, 1, ...]"
    iex> MerklePatriciaTrie.Trie.Storage.put_node(RLP.encode(["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]), trie)
    <<254, 112, 17, 90, 21, 82, 19, 29, 72, 106, 175, 110, 87, 220, 249, 140, 74, 165, 64, 94, 174, 79, 78, 189, 145, 143, 92, 53, 173, 136, 220, 145>>
    iex> MerklePatriciaTrie.Trie.Storage.get_node(%{trie| root_hash: <<254, 112, 17, 90, 21, 82, 19, 29, 72, 106, 175, 110, 87, 220, 249, 140, 74, 165, 64, 94, 174, 79, 78, 189, 145, 143, 92, 53, 173, 136, 220, 145>>})
    ["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]
  """
  @spec get_node(Trie.t) :: RLP.t | nil
  def get_node(trie) do
    case trie.root_hash do
      nil -> [] # nil
      x when byte_size(x) < @max_rlp_len -> RLP.decode(x) # stored directly
      h -> case h |> trie.db.get do # stored in db
        {:ok, v} -> RLP.decode(v)
        :not_found -> raise "Cannot find value in DB: #{inspect trie.root_hash}"
      end
    end
  end

end