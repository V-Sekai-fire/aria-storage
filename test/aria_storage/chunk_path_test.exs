# SPDX-License-Identifier: MIT
# Copyright (c) 2026-present K. S. Ernest (iFire) Lee

defmodule AriaStorage.ChunkPathTest do
  @moduledoc """
  Property tests for the desync-compatible chunk path format.

  Invariant: for any valid 64-hex chunk id, the Waffle storage_dir and filename
  combine to produce `<first-4-hex>/<64-hex>.cacnk` — exactly the path format
  that the desync HTTP chunk-server wire protocol expects.
  """

  use ExUnit.Case, async: true
  use PropCheck

  alias AriaStorage.WaffleChunkStore

  # ---------------------------------------------------------------------------
  # Generators
  # ---------------------------------------------------------------------------

  defp hex_char, do: oneof([integer(?0, ?9), integer(?a, ?f)])

  defp chunk_id_hex do
    let chars <- vector(64, hex_char()) do
      List.to_string(chars)
    end
  end

  # ---------------------------------------------------------------------------
  # Unit tests
  # ---------------------------------------------------------------------------

  describe "storage_dir/2" do
    test "uses exactly the first 4 hex chars of the chunk id as the prefix" do
      id = "ab12cd34" <> String.duplicate("e", 56)
      scope = %{chunk_id: id}
      dir = WaffleChunkStore.storage_dir(:original, {nil, scope})
      assert dir == "ab12"
    end

    test "prefix is always exactly 4 characters" do
      id = String.duplicate("f", 64)
      scope = %{chunk_id: id}
      dir = WaffleChunkStore.storage_dir(:original, {nil, scope})
      assert String.length(dir) == 4
    end

    test "prefix matches the first 4 chars of the id" do
      id = "dead" <> String.duplicate("0", 60)
      scope = %{chunk_id: id}
      dir = WaffleChunkStore.storage_dir(:original, {nil, scope})
      assert dir == "dead"
    end
  end

  describe "filename/2" do
    test "appends .cacnk to the chunk id" do
      id = String.duplicate("a", 64)
      scope = %{chunk_id: id}
      name = WaffleChunkStore.filename(:original, {nil, scope})
      assert name == id <> ".cacnk"
    end
  end

  describe "desync path format" do
    test "full path is <4-hex>/<64-hex>.cacnk" do
      id = "1234" <> String.duplicate("5", 60)
      scope = %{chunk_id: id}
      dir = WaffleChunkStore.storage_dir(:original, {nil, scope})
      name = WaffleChunkStore.filename(:original, {nil, scope})
      path = "#{dir}/#{name}"
      assert path == "1234/#{id}.cacnk"
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck properties
  # ---------------------------------------------------------------------------

  property "storage_dir prefix is always exactly 4 chars" do
    forall id <- chunk_id_hex() do
      scope = %{chunk_id: id}
      dir = WaffleChunkStore.storage_dir(:original, {nil, scope})
      String.length(dir) == 4
    end
  end

  property "storage_dir prefix matches first 4 chars of the chunk id" do
    forall id <- chunk_id_hex() do
      scope = %{chunk_id: id}
      dir = WaffleChunkStore.storage_dir(:original, {nil, scope})
      dir == String.slice(id, 0, 4)
    end
  end

  property "filename is always <64-hex-id>.cacnk" do
    forall id <- chunk_id_hex() do
      scope = %{chunk_id: id}
      name = WaffleChunkStore.filename(:original, {nil, scope})
      name == id <> ".cacnk"
    end
  end

  property "full path matches desync wire format /<4-hex>/<64-hex>.cacnk" do
    forall id <- chunk_id_hex() do
      scope = %{chunk_id: id}
      dir = WaffleChunkStore.storage_dir(:original, {nil, scope})
      name = WaffleChunkStore.filename(:original, {nil, scope})
      path = "#{dir}/#{name}"

      expected = "#{String.slice(id, 0, 4)}/#{id}.cacnk"
      path == expected
    end
  end

  property "chunk id can always be recovered from the path" do
    forall id <- chunk_id_hex() do
      scope = %{chunk_id: id}
      dir = WaffleChunkStore.storage_dir(:original, {nil, scope})
      name = WaffleChunkStore.filename(:original, {nil, scope})

      # The chunk id is filename without the .cacnk extension
      recovered_id = Path.rootname(name)

      # The prefix must be the first segment of the path
      prefix = dir

      recovered_id == id and String.starts_with?(recovered_id, prefix)
    end
  end
end
