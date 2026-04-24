# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaStorage.Chunks.Compression do
  @moduledoc "Chunk compression and decompression utilities.\n\nProvides compression functionality for chunks using various algorithms,\nwith zstd as the primary compression method.\n"
  @type compression_algorithm :: :zstd | :none
  @type compression_result :: {:ok, binary()} | {:error, atom() | {atom(), any()}}
  @doc "Compresses chunk data using the specified compression algorithm.\n\nSupports zstd compression (default) and no compression. The compressed\ndata format includes a small header indicating the compression algorithm used.\n\n## Parameters\n  - data: Binary data to compress\n  - algorithm: Compression algorithm to use (:zstd, :none)\n\n## Returns\n  - {:ok, binary} - Successfully compressed data with header\n  - {:error, :compression_not_available} - Compression algorithm not available\n"
  @spec compress_chunk(binary(), compression_algorithm()) :: compression_result()
  def compress_chunk(data, algorithm \\ :zstd) do
    case algorithm do
      :zstd ->
        if function_exported?(:zstd, :compress, 2) do
          {:ok, :erlang.iolist_to_binary(:zstd.compress(data, %{compression_level: 1}))}
        else
          {:error, :compression_not_available}
        end

      :none ->
        {:ok, data}

      _ ->
        {:error, {:unsupported_compression, algorithm}}
    end
  end

  @doc "Decompresses chunk data that was previously compressed with compress_chunk/2.\n\n## Parameters\n  - compressed_data: Binary data to decompress\n  - algorithm: Compression algorithm used (:zstd, :none)\n\n## Returns\n  - {:ok, binary} - Successfully decompressed data\n  - {:error, :compression_not_available} - Decompression algorithm not available\n  - {:error, {:decompression_failed, reason}} - Decompression failed\n"
  @spec decompress_chunk(binary(), compression_algorithm()) :: compression_result()
  def decompress_chunk(compressed_data, algorithm \\ :zstd) do
    case algorithm do
      :zstd ->
        if function_exported?(:zstd, :decompress, 1) do
          {:ok, :erlang.iolist_to_binary(:zstd.decompress(compressed_data))}
        else
          {:error, :compression_not_available}
        end

      :none ->
        {:ok, compressed_data}

      _ ->
        {:error, {:unsupported_compression, algorithm}}
    end
  end

  @doc "Check if a compression algorithm is available.\n"
  @spec compression_available?(compression_algorithm()) :: boolean()
  def compression_available?(:zstd) do
    function_exported?(:zstd, :compress, 2)
  end

  def compression_available?(:none) do
    true
  end

  def compression_available?(_) do
    false
  end

  @doc "Get the best available compression algorithm.\n"
  @spec best_available_compression() :: compression_algorithm()
  def best_available_compression do
    if compression_available?(:zstd) do
      :zstd
    else
      :none
    end
  end

  @doc "Calculate compression ratio for given data and algorithm.\n"
  @spec compression_ratio(binary(), compression_algorithm()) :: {:ok, float()} | {:error, any()}
  def compression_ratio(data, algorithm) do
    original_size = byte_size(data)

    case compress_chunk(data, algorithm) do
      {:ok, compressed} ->
        compressed_size = byte_size(compressed)
        ratio = compressed_size / original_size
        {:ok, ratio}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
