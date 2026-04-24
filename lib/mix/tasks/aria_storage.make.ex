# SPDX-License-Identifier: MIT
# Copyright (c) 2026-present K. S. Ernest (iFire) Lee

defmodule Mix.Tasks.AriaStorage.Make do
  @shortdoc "Chunk a file into casync blob-index format (.caibx + store/)"

  @moduledoc """
  Chunks a single binary file into casync blob-index format (.caibx) compatible
  with desync and `mix aria_storage.fetch`.

  ## Usage

      mix aria_storage.make --input PATH --output DIR [--name BASENAME]

  ## Options

      --input PATH     Source file to chunk. Required.
      --output DIR     Directory to write {name}.caibx and store/. Required.
      --name BASENAME  Output basename without extension.
                       Defaults to the input filename stem.

  ## Examples

      mix aria_storage.make \\
        --input _build/taskweft_planner \\
        --output /path/to/multiplayer-fabric-casync-seed \\
        --name taskweft_planner

  Produces:
    {output}/taskweft_planner.caibx
    {output}/store/{4-char-prefix}/{sha512_256-hex}.cacnk  (one per chunk)

  The index and store can be served from a git repository and fetched with:

      mix aria_storage.fetch \\
        --index https://raw.githubusercontent.com/.../taskweft_planner.caibx \\
        --store https://raw.githubusercontent.com/.../store \\
        --output /tmp/out
  """

  use Mix.Task

  alias AriaStorage.Chunks
  alias AriaStorage.Parsers.CasyncFormat.Encoder

  @default_min 16 * 1024
  @default_avg 64 * 1024
  @default_max 256 * 1024

  # desync/casync feature flag: SHA-512/256 chunk IDs (1 << 61)
  @feature_flags_sha512_256 2_305_843_009_213_693_952

  @impl Mix.Task
  def run(args) do
    Application.ensure_all_started(:aria_storage)

    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [input: :string, output: :string, name: :string]
      )

    input_path = Keyword.get(opts, :input) || Mix.raise("--input PATH is required")
    output_dir = Keyword.get(opts, :output) || Mix.raise("--output DIR is required")
    name = Keyword.get(opts, :name) || Path.basename(input_path, Path.extname(input_path))

    unless File.exists?(input_path) do
      Mix.raise("Input file not found: #{input_path}")
    end

    store_dir = Path.join(output_dir, "store")
    index_path = Path.join(output_dir, "#{name}.caibx")
    File.mkdir_p!(store_dir)

    input_size = File.stat!(input_path).size

    Mix.shell().info("Input:  #{input_path} (#{format_bytes(input_size)})")
    Mix.shell().info("Index:  #{index_path}")
    Mix.shell().info("Store:  #{store_dir}")
    Mix.shell().info("Chunking...")

    {:ok, chunks} =
      Chunks.create_chunks(input_path,
        min_size: @default_min,
        avg_size: @default_avg,
        max_size: @default_max,
        compression: :zstd
      )

    Mix.shell().info("  #{length(chunks)} chunk(s)")

    # Write each chunk as store/{prefix4}/{id-hex}.cacnk
    Enum.each(chunks, fn chunk ->
      chunk_id_hex = Base.encode16(chunk.id, case: :lower)
      chunk_dir = Path.join(store_dir, String.slice(chunk_id_hex, 0, 4))
      File.mkdir_p!(chunk_dir)

      # Detect whether zstd compression actually ran (fallback is raw data).
      compression = if chunk.compressed == chunk.data, do: :none, else: :zstd

      {:ok, cacnk_data} =
        Encoder.encode_chunk(%{
          header: %{
            compressed_size: byte_size(chunk.compressed),
            uncompressed_size: chunk.size,
            compression: compression,
            flags: 0
          },
          data: chunk.compressed
        })

      File.write!(Path.join(chunk_dir, "#{chunk_id_hex}.cacnk"), cacnk_data)
    end)

    # Build the .caibx index.
    index_chunks = Enum.map(chunks, &%{chunk_id: &1.id, size: &1.size})

    {:ok, index_binary} =
      Encoder.encode_index(%{
        format: :caibx,
        header: nil,
        chunks: index_chunks,
        feature_flags: @feature_flags_sha512_256,
        chunk_size_min: @default_min,
        chunk_size_avg: @default_avg,
        chunk_size_max: @default_max
      })

    File.write!(index_path, index_binary)

    compressed_total = Enum.sum(Enum.map(chunks, &byte_size(&1.compressed)))

    Mix.shell().info("Done.")
    Mix.shell().info("  index:  #{format_bytes(byte_size(index_binary))}")
    Mix.shell().info("  store:  #{format_bytes(compressed_total)} in #{length(chunks)} chunk(s)")
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 2)} KB"
      true -> "#{bytes} B"
    end
  end
end
