defmodule Blockchain.TransactionTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Transaction

  setup_all do
    MerklePatriciaTrie.DB.ETS.init()

    :ok
  end

  describe "when handling transactions" do

    test "for a transaction with a stop" do
      beneficiary = <<0x05::160>>
      private_key = <<1::256>>
      sender = <<82, 43, 246, 253, 8, 130, 229, 143, 111, 235, 9, 107, 65, 65, 123, 79, 140, 105, 44, 57>> # based on simple private key
      contract_address = Blockchain.Contract.new_contract_address(sender, 6)
      machine_code = EVM.MachineCode.compile([:stop])
      trx = %Blockchain.Transaction{nonce: 5, gas_price: 3, gas_limit: 100_000, to: <<>>, value: 5, init: machine_code}
            |> Blockchain.Transaction.Signature.sign_transaction(private_key)

      assert MerklePatriciaTrie.Trie.new()
        |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 400_000, nonce: 5})
        |> Blockchain.Transaction.execute_transaction(trx, %Blockchain.Block.Header{beneficiary: beneficiary})
        |> Blockchain.Account.get_accounts([sender, beneficiary, contract_address]) ==
        [
          %Blockchain.Account{balance: 240983, nonce: 6}, %Blockchain.Account{balance: 159012}, %Blockchain.Account{balance: 5}
        ]
    end
  end
end