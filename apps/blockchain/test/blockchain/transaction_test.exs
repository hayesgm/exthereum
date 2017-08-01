defmodule Blockchain.TransactionTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Transaction
  alias Blockchain.Transaction

  describe "when handling transactions" do

    test "serialize and deserialize" do
      trx = %Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}

      assert trx == trx |> Transaction.serialize |> ExRLP.encode |> ExRLP.decode |> Transaction.deserialize
    end

    test "for a transaction with a stop" do
      beneficiary = <<0x05::160>>
      private_key = <<1::256>>
      sender = <<82, 43, 246, 253, 8, 130, 229, 143, 111, 235, 9, 107, 65, 65, 123, 79, 140, 105, 44, 57>> # based on simple private key
      contract_address = Blockchain.Contract.new_contract_address(sender, 6)
      machine_code = EVM.MachineCode.compile([:stop])
      trx = %Blockchain.Transaction{nonce: 5, gas_price: 3, gas_limit: 100_000, to: <<>>, value: 5, init: machine_code}
            |> Blockchain.Transaction.Signature.sign_transaction(private_key)

      {state, gas_used, logs} = MerklePatriciaTrie.Trie.new(MerklePatriciaTrie.Test.random_ets_db())
        |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 400_000, nonce: 5})
        |> Blockchain.Transaction.execute_transaction(trx, %Blockchain.Block.Header{beneficiary: beneficiary})

      assert gas_used == 53004
      assert logs == ""
      assert Blockchain.Account.get_accounts(state, [sender, beneficiary, contract_address]) ==
        [
          %Blockchain.Account{balance: 240983, nonce: 6}, %Blockchain.Account{balance: 159012}, %Blockchain.Account{balance: 5}
        ]
    end
  end
end