# SPDX-License-Identifier: MIT
# Copyright (c) 2026-present K. S. Ernest (iFire) Lee

defmodule AriaStorage.ChunkServerPlugTest do
  use ExUnit.Case, async: true
  use PropCheck

  import Plug.Test

  alias AriaStorage.ChunkServerPlug

  # ---------------------------------------------------------------------------
  # Generators
  # ---------------------------------------------------------------------------

  # A valid lowercase hex character
  defp hex_char do
    oneof([integer(?0, ?9), integer(?a, ?f)])
  end

  # A string of exactly n lowercase hex characters
  defp hex_string(n) do
    let chars <- vector(n, hex_char()) do
      List.to_string(chars)
    end
  end

  # Valid chunk id: 64 hex chars
  defp valid_chunk_id, do: hex_string(64)

  # Valid prefix: first 4 chars of a valid chunk id
  defp valid_path_info do
    let id <- valid_chunk_id() do
      prefix = String.slice(id, 0, 4)
      [prefix, "#{id}.cacnk"]
    end
  end

  # ---------------------------------------------------------------------------
  # Unit tests — parse_chunk_id via the Plug interface
  # ---------------------------------------------------------------------------

  # ChunkServerPlug.parse_chunk_id is private; we exercise it by calling
  # the plug directly through a mock Plug.Conn.

  defp build_conn(method, path_info) do
    conn(method, "/" <> Enum.join(path_info, "/"))
    |> Map.put(:path_info, path_info)
  end

  describe "GET routing" do
    test "returns 400 for empty path" do
      conn = build_conn("GET", [])
      conn = ChunkServerPlug.call(conn, writeable: false)
      assert conn.status == 400
    end

    test "returns 400 for single-segment path" do
      conn = build_conn("GET", ["ab12"])
      conn = ChunkServerPlug.call(conn, writeable: false)
      assert conn.status == 400
    end

    test "returns 400 when extension is wrong" do
      id = String.duplicate("a", 64)
      conn = build_conn("GET", [String.slice(id, 0, 4), "#{id}.idx"])
      conn = ChunkServerPlug.call(conn, writeable: false)
      assert conn.status == 400
    end

    test "returns 400 when prefix does not match chunk id" do
      id = String.duplicate("a", 64)
      conn = build_conn("GET", ["ffff", "#{id}.cacnk"])
      conn = ChunkServerPlug.call(conn, writeable: false)
      assert conn.status == 400
    end

    test "returns 400 when chunk id is too short" do
      id = String.duplicate("a", 30)
      conn = build_conn("GET", [String.slice(id, 0, 4), "#{id}.cacnk"])
      conn = ChunkServerPlug.call(conn, writeable: false)
      assert conn.status == 400
    end

    test "returns 400 when prefix is wrong length" do
      id = String.duplicate("a", 64)
      conn = build_conn("GET", ["ab", "#{id}.cacnk"])
      conn = ChunkServerPlug.call(conn, writeable: false)
      assert conn.status == 400
    end
  end

  describe "PUT routing" do
    test "returns 403 when writeable: false" do
      id = String.duplicate("b", 64)
      prefix = String.slice(id, 0, 4)
      conn = build_conn("PUT", [prefix, "#{id}.cacnk"])
      conn = ChunkServerPlug.call(conn, writeable: false)
      assert conn.status == 403
    end
  end

  describe "unsupported method" do
    test "returns 405 for DELETE" do
      id = String.duplicate("c", 64)
      prefix = String.slice(id, 0, 4)
      conn = build_conn("DELETE", [prefix, "#{id}.cacnk"])
      conn = ChunkServerPlug.call(conn, writeable: false)
      assert conn.status == 405
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck properties
  # ---------------------------------------------------------------------------

  property "valid path_info always reaches storage layer (not 400)" do
    forall [prefix, filename] <- valid_path_info() do
      conn = build_conn("GET", [prefix, filename])
      result = ChunkServerPlug.call(conn, writeable: false)
      # A valid path should NOT return 400 — it may 404 if chunk absent,
      # but the path parsing step is correct.
      result.status != 400
    end
  end

  property "mismatched prefix always returns 400" do
    forall [id <- valid_chunk_id(), bad_prefix <- hex_string(4)] do
      # Only run when prefix genuinely mismatches
      implies String.slice(id, 0, 4) != bad_prefix do
        conn = build_conn("GET", [bad_prefix, "#{id}.cacnk"])
        result = ChunkServerPlug.call(conn, writeable: false)
        result.status == 400
      end
    end
  end

  property "prefix length != 4 always returns 400" do
    forall [
      id <- valid_chunk_id(),
      bad_len <- oneof([integer(1, 3), integer(5, 8)])
    ] do
      bad_prefix = String.slice(id, 0, bad_len)
      conn = build_conn("GET", [bad_prefix, "#{id}.cacnk"])
      result = ChunkServerPlug.call(conn, writeable: false)
      result.status == 400
    end
  end

  property "chunk id length != 64 always returns 400" do
    forall [
      id <- valid_chunk_id(),
      short_len <- integer(1, 63)
    ] do
      short_id = String.slice(id, 0, short_len)
      prefix = String.slice(id, 0, 4)
      conn = build_conn("GET", [prefix, "#{short_id}.cacnk"])
      result = ChunkServerPlug.call(conn, writeable: false)
      result.status == 400
    end
  end

  property "wrong extension always returns 400" do
    forall [
      [prefix, _] <- valid_path_info(),
      id <- valid_chunk_id(),
      ext <- oneof(["", ".caibx", ".gz", ".bin", ".caidx"])
    ] do
      conn = build_conn("GET", [prefix, "#{id}#{ext}"])
      result = ChunkServerPlug.call(conn, writeable: false)
      result.status == 400
    end
  end

  property "PUT with writeable: false always returns 403" do
    forall [prefix, filename] <- valid_path_info() do
      conn = build_conn("PUT", [prefix, filename])
      result = ChunkServerPlug.call(conn, writeable: false)
      result.status == 403
    end
  end

  property "unsupported method always returns 405" do
    forall [
      method <- oneof(["DELETE", "PATCH", "POST", "OPTIONS"]),
      [prefix, filename] <- valid_path_info()
    ] do
      conn = build_conn(method, [prefix, filename])
      result = ChunkServerPlug.call(conn, writeable: false)
      result.status == 405
    end
  end
end
