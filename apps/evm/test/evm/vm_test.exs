defmodule EVM.VMTest do
  use ExUnit.Case, async: true
  doctest EVM.VM

  setup_all do
    MerklePatriciaTrie.DB.ETS.init()
    :ok
  end

  setup do
    {:ok, %{
      state: MerklePatriciaTrie.Trie.new()
    }}
  end

  test "simple program with return value", %{state: state} do
    instructions = [
      :push1,
      3,
      :push1,
      5,
      :add,
      :push1,
      0x00,
      :mstore,
      :push1,
      0,
      :push1,
      32,
      :return
    ]

    result = EVM.VM.run(state, 5, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile(instructions)})

    assert result == {state, 5, [], "", 0, <<0x08::256>>}
  end

  test "simple program with block storage", %{state: state} do
    instructions = [
      :push1,
      3,
      :push1,
      5,
      :sstore,
      :stop
    ]

    result = EVM.VM.run(state, 5, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile(instructions)})

    expected_state = %{state|root_hash: <<12, 189, 253, 61, 167, 240, 166, 67, 81, 179, 89, 188, 142, 220, 80, 44, 72, 102, 195, 89, 230, 27, 75, 136, 68, 2, 117, 227, 48, 141, 102, 230>>}

    assert result == {expected_state, 5, [], "", 0, ""}

    {returned_state, _, _, _, _, _} = result

    assert MerklePatriciaTrie.Trie.Inspector.all_values(returned_state) == [{<<5::256>>, <<3::256>>}]
  end
end