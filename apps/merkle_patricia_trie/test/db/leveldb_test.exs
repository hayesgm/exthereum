defmodule MerklePatriciaTrie.DB.LevelDBTest do
  use ExUnit.Case, async: false
  alias MerklePatriciaTrie.DB.LevelDB

  test "init creates an leveldb table" do
    db_name = "/tmp/db#{MerklePatriciaTrie.Test.random_string(20)}"

    {_, db_ref} = LevelDB.init(db_name)
    Exleveldb.close(db_ref)
    {:ok, _db} = Exleveldb.open(db_name, create_if_missing: false)
  end

  test "get/1" do
    db={_, db_ref} = LevelDB.init("/tmp/db#{MerklePatriciaTrie.Test.random_string(20)}")

    Exleveldb.put(db_ref, "key", "value")
    assert LevelDB.get(db, "key") == {:ok, "value"}
    assert LevelDB.get(db, "key2") == :not_found
  end

  test "get!/1" do
    db={_, db_ref} = LevelDB.init("/tmp/db#{MerklePatriciaTrie.Test.random_string(20)}")

    Exleveldb.put(db_ref, "key", "value")
    assert LevelDB.get!(db, "key") == "value"

    assert_raise RuntimeError, "cannot find key `key2`", fn ->
      LevelDB.get!(db, "key2")
    end
  end

  test "put!/2" do
    db={_, db_ref} = LevelDB.init("/tmp/db#{MerklePatriciaTrie.Test.random_string(20)}")

    assert LevelDB.put!(db, "key", "value") == :ok
    assert Exleveldb.get(db_ref, "key") == {:ok, "value"}
  end

  test "simple init, put, get" do
    db = LevelDB.init("/tmp/db#{MerklePatriciaTrie.Test.random_string(20)}")

    assert LevelDB.put!(db, "name", "bob") == :ok
    assert LevelDB.get!(db, "name") == "bob"
    assert LevelDB.get(db, "age") == :not_found
  end

end