defmodule Blockchain.AccountTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Account
  alias Blockchain.Account

  test "serialize and deserialize" do
    acct = %Account{nonce: 5, balance: 10, storage_root: <<0x00, 0x01>>, code_hash: <<0x01, 0x02>>}

    assert acct == acct |> Account.serialize |> RLP.encode |> RLP.decode |> Account.deserialize
  end

end