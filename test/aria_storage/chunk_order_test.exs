# SPDX-License-Identifier: MIT
# Copyright (c) 2026-present K. S. Ernest (iFire) Lee

defmodule AriaStorage.ChunkOrderTest do
  use ExUnit.Case

  alias AriaStorage.CasyncDecoder
  alias AriaStorage.Chunks.Core, as: ChunksCore
  alias AriaStorage.Parsers.CasyncFormat

  @moduledoc """
  Regression test for the Enum.reverse bug in create_rolling_hash_chunks.

  Previously, find_all_chunks_in_data returned chunks in forward (start→end)
  order, but an outer Enum.reverse inverted the sequence before encoding the
  index.  The assembled output therefore started with the last file segment
  instead of the first, breaking any magic-byte check (e.g. ELF header).
  """

  describe "make → assemble round-trip" do
    test "assembled file is byte-identical to source for a multi-chunk binary" do
      # Build a synthetic payload large enough to cross the max_chunk_size (256 KiB)
      # boundary so create_rolling_hash_chunks is used, not create_single_chunk.
      chunk_boundary = 16 * 1024
      payload_size = chunk_boundary * 25  # 400 KiB > 256 KiB max
      # Distinct content per 1 KiB region so boundaries differ from position
      source_data =
        for i <- 0..(payload_size - 1), into: <<>> do
          <<rem(i, 256)>>
        end

      assert byte_size(source_data) == payload_size

      # Write to a temp file, run create_chunks, encode index and store, then
      # decode and reassemble into a second temp file.
      tmp_dir = System.tmp_dir!()
      input_path = Path.join(tmp_dir, "chunk_order_test_input.bin")
      store_dir = Path.join(tmp_dir, "chunk_order_test_store")
      output_dir = Path.join(tmp_dir, "chunk_order_test_out")
      File.mkdir_p!(store_dir)
      File.mkdir_p!(output_dir)
      File.write!(input_path, source_data)

      on_exit(fn ->
        File.rm(input_path)
        File.rm_rf(store_dir)
        File.rm_rf(output_dir)
      end)

      # --- make ---
      {:ok, chunks} = ChunksCore.create_chunks(input_path, compression: :zstd)
      assert length(chunks) > 1, "Expected multiple chunks, got #{length(chunks)}"

      index_chunks = Enum.map(chunks, &%{chunk_id: &1.id, size: &1.size})

      {:ok, index_binary} =
        CasyncFormat.Encoder.encode_index(%{
          format: :caibx,
          header: nil,
          chunks: index_chunks,
          feature_flags: 0,
          chunk_size_min: 16 * 1024,
          chunk_size_avg: 64 * 1024,
          chunk_size_max: 256 * 1024
        })

      index_path = Path.join(tmp_dir, "chunk_order_test.caibx")
      File.write!(index_path, index_binary)

      Enum.each(chunks, fn chunk ->
        hex = Base.encode16(chunk.id, case: :lower)
        dir = Path.join(store_dir, String.slice(hex, 0, 4))
        File.mkdir_p!(dir)

        {:ok, cacnk} =
          CasyncFormat.Encoder.encode_chunk(%{
            header: %{
              compressed_size: byte_size(chunk.compressed),
              uncompressed_size: chunk.size,
              compression: if(chunk.compressed == chunk.data, do: :none, else: :zstd),
              flags: 0
            },
            data: chunk.compressed
          })

        File.write!(Path.join(dir, "#{hex}.cacnk"), cacnk)
      end)

      # --- assemble ---
      {:ok, result} =
        CasyncDecoder.decode_file(index_path,
          store_path: store_dir,
          output_dir: output_dir
        )

      assert result.assembly_result != nil
      assembled_path = result.assembly_result.assembled_file
      {:ok, assembled} = File.read(assembled_path)

      # Core assertion: assembled output must equal source byte-for-byte.
      assert assembled == source_data,
             "Assembled file differs from source — chunk order is wrong"

      # Extra: first bytes must match (catches the original ELF-header regression).
      assert :binary.part(assembled, 0, 4) == :binary.part(source_data, 0, 4)
    end

    test "first chunk in index maps to file offset 0" do
      chunk_boundary = 16 * 1024
      source_data = :crypto.strong_rand_bytes(chunk_boundary * 25)
      tmp_dir = System.tmp_dir!()
      input_path = Path.join(tmp_dir, "chunk_order_offset_test.bin")
      File.write!(input_path, source_data)
      on_exit(fn -> File.rm(input_path) end)

      {:ok, chunks} = ChunksCore.create_chunks(input_path, compression: :zstd)
      first_chunk = hd(chunks)

      # The first chunk must contain the first bytes of the source.
      assert :binary.part(first_chunk.data, 0, min(4, byte_size(first_chunk.data))) ==
               :binary.part(source_data, 0, min(4, byte_size(first_chunk.data)))
    end
  end
end
