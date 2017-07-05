defmodule MerklePatriciaTrie.TrieTest do
  use ExUnit.Case
  alias MerklePatriciaTrie.Trie
  alias MerklePatriciaTrie.Trie.Verifier

  @max_32_bits 4294967296

  setup_all do
    MerklePatriciaTrie.DB.ETS.init()
    :ok
  end

  def leaf_node(key_end, value) do
    RLP.encode([HexPrefix.encode({key_end, true}), value])
  end

  def store(node_value) do
    node_hash = :keccakf1600.sha3_256(node_value)
    MerklePatriciaTrie.DB.ETS.put!(node_hash, node_value)

    node_hash
  end

  def extension_node(shared_nibbles, node_hash) do
    RLP.encode([HexPrefix.encode({shared_nibbles, false}), node_hash])
  end

  def branch_node(branches, value) when length(branches) == 16 do
    RLP.encode(branches ++ [value])
  end

  def blanks(n) do
    for _ <- 1..n, do: []
  end

  def random_key() do
    <<
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
    >>
  end

  def random_value() do
    <<:rand.uniform(@max_32_bits)::32>>
  end

  test "create trie" do
    trie = Trie.new(db: :ets)

    assert Trie.get(trie, <<0x01, 0x02, 0x03>>) == nil
  end

  describe "get" do
    test "for a simple trie with just a leaf" do
      trie = Trie.new(db: :ets)
      trie = %{trie| root_hash: leaf_node([0x01, 0x02, 0x03], "cool")}

      assert Trie.get(trie, <<0x01::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "for a trie with an extension node followed by a leaf" do
      trie = Trie.new(db: :ets)
      trie = %{trie| root_hash: extension_node([0x01, 0x02], leaf_node([0x03], "cool"))}

      assert Trie.get(trie, <<0x01::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "for a trie with an extension node followed by an extension node and then leaf" do
      trie = Trie.new(db: :ets)
      trie = %{trie| root_hash: extension_node([0x01, 0x02], extension_node([0x03], leaf_node([0x04], "cool")))}

      assert Trie.get(trie, <<0x01::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == "cool"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4, 0x05::4>>) == nil
    end

    test "for a trie with a branch node" do
      trie = Trie.new(db: :ets)
      trie = %{trie| root_hash: extension_node([0x01], branch_node([leaf_node([0x02], "hi")|blanks(15)], "cool"))}

      assert Trie.get(trie, <<0x01::4>>) == "cool"
      assert Trie.get(trie, <<0x01::4, 0x00::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x00::4, 0x02::4>>) == "hi"
      assert Trie.get(trie, <<0x01::4, 0x00::4, 0x0::43>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x01::4>>) == nil
    end

    test "for a trie with encoded nodes" do
      long_string = Enum.join(for _ <- 1..60, do: "A")

      trie = Trie.new(db: :ets)
      trie = %{trie| root_hash: extension_node([0x01, 0x02], leaf_node([0x03], long_string) |> store) |> store}

      assert Trie.get(trie, <<0x01::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == long_string
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end
  end

  describe "update trie" do
    test "add a leaf to an empty tree" do
      trie = Trie.new(db: :ets)

      trie_2 = Trie.update(trie, <<0x01::4, 0x02::4, 0x03::4>>, "cool")

      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == nil
      assert Trie.get(trie_2, <<0x01::4>>) == nil
      assert Trie.get(trie_2, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie_2, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get(trie_2, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil

      # assert Trie.root(trie) == nil
      # assert Trie.root(trie_2) == "cool root"
    end

    test "update a leaf value (when stored directly)" do
      trie = Trie.new(db: :ets, root_hash: leaf_node([0x01, 0x02], "first"))
      trie_2 = Trie.update(trie, <<0x01::4, 0x02::4>>, "second")

      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == "first"
      assert Trie.get(trie_2, <<0x01::4, 0x02::4>>) == "second"
    end

    test "update a leaf value (when stored in ets)" do
      long_string = Enum.join(for _ <- 1..60, do: "A")
      long_string_2 = Enum.join(for _ <- 1..60, do: "B")

      trie = Trie.new(db: :ets, root_hash: leaf_node([0x01, 0x02], long_string) |> store)
      trie_2 = Trie.update(trie, <<0x01::4, 0x02::4>>, long_string_2)

      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == long_string
      assert Trie.get(trie_2, <<0x01::4, 0x02::4>>) == long_string_2
    end

    test "update branch under ext node" do
      trie =
        Trie.new(db: :ets)
        |> Trie.update(<<0x01::4, 0x02::4>>, "wee")
        |> Trie.update(<<0x01::4, 0x02::4, 0x03::4>>, "cool")

      trie_2 = Trie.update(trie, <<0x01::4, 0x02::4, 0x03::4>>, "cooler")

      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get(trie_2, <<0x01::4>>) == nil
      assert Trie.get(trie_2, <<0x01::4, 0x02::4>>) == "wee"
      assert Trie.get(trie_2, <<0x01::4, 0x02::4, 0x03::4>>) == "cooler"
      assert Trie.get(trie_2, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "update multiple keys" do
      trie =
        Trie.new(db: :ets)
        |> Trie.update(<<0x01::4, 0x02::4, 0x03::4>>, "a")
        |> Trie.update(<<0x01::4, 0x02::4, 0x03::4, 0x04::4>>, "b")
        |> Trie.update(<<0x01::4, 0x02::4, 0x04::4>>, "c")
        |> Trie.update(<<0x01::size(256)>>, "d")

      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "a"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == "b"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x04::4>>) == "c"
      assert Trie.get(trie, <<0x01::size(256)>>) == "d"
    end

    test "a set of updates" do
      trie =
        Trie.new(db: :ets)
        |> Trie.update(<<5::4, 7::4, 10::4, 15::4, 15::4>>, "a")
        |> Trie.update(<<5::4, 11::4, 0::4, 0::4, 14::4>>, "b")
        |> Trie.update(<<5::4, 10::4, 0::4, 0::4, 14::4>>, "c")
        |> Trie.update(<<4::4, 10::4, 0::4, 0::4, 14::4>>, "d")
        |> Trie.update(<<5::4, 10::4, 1::4, 0::4, 14::4>>, "e")

      assert Trie.get(trie, <<5::4, 7::4, 10::4, 15::4, 15::4>>) == "a"
      assert Trie.get(trie, <<5::4, 11::4, 0::4, 0::4, 14::4>>) == "b"
      assert Trie.get(trie, <<5::4, 10::4, 0::4, 0::4, 14::4>>) == "c"
      assert Trie.get(trie, <<4::4, 10::4, 0::4, 0::4, 14::4>>) == "d"
      assert Trie.get(trie, <<5::4, 10::4, 1::4, 0::4, 14::4>>) == "e"
    end

    test "yet another set of updates" do
      trie =
        Trie.new(db: :ets)
        |> Trie.update(<<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4, 10::4, 6::4, 7::4, 1::4>>, "a")
        |> Trie.update(<<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4, 8::4, 5::4, 2::4, 12::4>>, "b")
        |> Trie.update(<<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4, 6::4, 4::4, 5::4, 0::4>>, "c")

      assert Trie.get(trie, <<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4, 10::4, 6::4, 7::4, 1::4>>) == "a"
      assert Trie.get(trie, <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4, 8::4, 5::4, 2::4, 12::4>>) == "b"
      assert Trie.get(trie, <<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4, 6::4, 4::4, 5::4, 0::4>>) == "c"
    end

    test "acceptence testing" do
      {trie, values} = Enum.reduce(1..100, {Trie.new(db: :ets), []}, fn (_, {trie, dict}) ->
        key = random_key()
        value = random_value()

        updated_trie = Trie.update(trie, key, value) # |> Helper.inspect_trie

        # Verify each key exists in our trie
        for {k, v} <- dict do
          assert Trie.get(trie, k) == v
        end

        {updated_trie, [{key, value} | dict]}
      end)

      # IO.inspect(values)
      # Helper.inspect_trie(trie)

      # Next, assert tree is well formed
      assert Verifier.verify_trie(trie, values) == :ok
    end
  end

end
