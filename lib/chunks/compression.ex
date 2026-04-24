# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaStorage.Chunks.Compression do
  @moduledoc "Chunk compression and decompression using zstd (OTP 28 stdlib)."

  @type compression_algorithm :: :zstd | :none
  @type compression_result :: {:ok, binary()} | {:error, atom() | {atom(), any()}}

  @spec compress_chunk(binary(), compression_algorithm()) :: compression_result()
  def compress_chunk(data, algorithm \\ :zstd) do
    case algorithm do
      :zstd -> {:ok, :erlang.iolist_to_binary(:zstd.compress(data))}
      :none -> {:ok, data}
      _ -> {:error, {:unsupported_compression, algorithm}}
    end
  end

  @spec decompress_chunk(binary(), compression_algorithm()) :: compression_result()
  def decompress_chunk(compressed_data, algorithm \\ :zstd) do
    case algorithm do
      :zstd -> {:ok, :erlang.iolist_to_binary(:zstd.decompress(compressed_data))}
      :none -> {:ok, compressed_data}
      _ -> {:error, {:unsupported_compression, algorithm}}
    end
  end

  @spec compression_available?(compression_algorithm()) :: boolean()
  def compression_available?(:zstd), do: true
  def compression_available?(:none), do: true
  def compression_available?(_), do: false

  @spec best_available_compression() :: compression_algorithm()
  def best_available_compression, do: :zstd

  @spec compression_ratio(binary(), compression_algorithm()) :: {:ok, float()} | {:error, any()}
  def compression_ratio(data, algorithm) do
    case compress_chunk(data, algorithm) do
      {:ok, compressed} -> {:ok, byte_size(compressed) / byte_size(data)}
      {:error, _} = err -> err
    end
  end
end
