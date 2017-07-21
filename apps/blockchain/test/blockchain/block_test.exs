defmodule Blockchain.BlockTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Block

  setup_all do
    MerklePatriciaTrie.DB.ETS.init()

    :ok
  end

end