# SPDX-License-Identifier: MIT
# Copyright (c) 2026-present K. S. Ernest (iFire) Lee

defmodule AriaStorage.ChunkServerPlug do
  @moduledoc """
  Plug implementing the desync HTTP chunk-server wire protocol.

  Mount in any Phoenix/Plug router to replace the `desync chunk-server` container:

      # zone-backend router.ex
      scope "/chunks" do
        forward "/", AriaStorage.ChunkServerPlug, writeable: true
      end

  Wire protocol (identical to `desync chunk-server`):

      GET  /<4-hex>/<64-hex>.cacnk  — serve compressed chunk bytes
      HEAD /<4-hex>/<64-hex>.cacnk  — 200 if exists, 404 otherwise
      PUT  /<4-hex>/<64-hex>.cacnk  — accept and store chunk bytes (requires writeable: true)

  Chunks are stored and retrieved via `AriaStorage.WaffleChunkStore`, which
  delegates to the configured Waffle backend (S3/local).
  """

  @behaviour Plug

  import Plug.Conn

  alias AriaStorage.WaffleChunkStore

  @chunk_ext ".cacnk"
  # desync max chunk size is 256 KB; allow 512 KB for safety margin
  @max_chunk_bytes 512 * 1024

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    writeable = Keyword.get(opts, :writeable, false)

    case parse_chunk_id(conn.path_info) do
      {:ok, chunk_id_hex} -> dispatch(conn, chunk_id_hex, writeable)
      {:error, reason} -> conn |> send_resp(400, reason) |> halt()
    end
  end

  # Route by HTTP method

  defp dispatch(conn, chunk_id_hex, writeable) do
    case conn.method do
      "GET" -> handle_get(conn, chunk_id_hex)
      "HEAD" -> handle_head(conn, chunk_id_hex)
      "PUT" when writeable -> handle_put(conn, chunk_id_hex)
      "PUT" -> conn |> send_resp(403, "read-only store\n") |> halt()
      _ -> conn |> send_resp(405, "only GET, HEAD, PUT are supported\n") |> halt()
    end
  end

  defp handle_get(conn, chunk_id_hex) do
    case WaffleChunkStore.retrieve_raw_chunk(chunk_id_hex) do
      {:ok, data} ->
        conn
        |> put_resp_content_type("application/octet-stream")
        |> send_resp(200, data)

      {:error, _} ->
        conn |> send_resp(404, "chunk not found\n") |> halt()
    end
  end

  defp handle_head(conn, chunk_id_hex) do
    if WaffleChunkStore.chunk_exists?(chunk_id_hex) do
      conn |> send_resp(200, "") |> halt()
    else
      conn |> send_resp(404, "") |> halt()
    end
  end

  defp handle_put(conn, chunk_id_hex) do
    case read_body(conn, length: @max_chunk_bytes) do
      {:ok, body, conn} ->
        case WaffleChunkStore.store_raw_chunk(chunk_id_hex, body) do
          :ok -> conn |> send_resp(204, "") |> halt()
          {:error, reason} -> conn |> send_resp(500, inspect(reason)) |> halt()
        end

      {:more, _partial, conn} ->
        conn |> send_resp(413, "chunk exceeds #{@max_chunk_bytes} bytes\n") |> halt()

      {:error, reason} ->
        conn |> send_resp(400, inspect(reason)) |> halt()
    end
  end

  # Parse path segments into a validated 64-hex chunk ID.
  # desync format: /<4-hex-prefix>/<64-hex-id>.cacnk
  # The prefix must match the first 4 chars of the ID.

  defp parse_chunk_id([prefix, filename]) do
    chunk_id_hex = Path.rootname(filename)
    ext = Path.extname(filename)

    cond do
      ext != @chunk_ext ->
        {:error, "expected #{@chunk_ext} extension, got #{ext}\n"}

      String.length(prefix) != 4 ->
        {:error, "expected 4-char prefix, got #{String.length(prefix)} chars\n"}

      String.length(chunk_id_hex) != 64 ->
        {:error, "expected 64-char chunk id, got #{String.length(chunk_id_hex)} chars\n"}

      not String.starts_with?(chunk_id_hex, prefix) ->
        {:error, "prefix #{prefix} does not match chunk id\n"}

      true ->
        {:ok, chunk_id_hex}
    end
  end

  defp parse_chunk_id(_) do
    {:error, "expected /<4-hex>/<64-hex>.cacnk\n"}
  end
end
