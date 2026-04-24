# SPDX-License-Identifier: MIT
# Copyright (c) 2026-present K. S. Ernest (iFire) Lee

defmodule Mix.Tasks.AriaStorage.Fetch do
  @shortdoc "Fetch and assemble a casync/desync asset from a remote store"

  @moduledoc """
  Downloads a `.caidx` or `.caibx` index from a remote URL, fetches all
  referenced chunks from the corresponding store, and assembles the output.

  ## Usage

      mix aria_storage.fetch --index INDEX_URL [options]

  ## Options

      --index URL     Index file URL (.caidx or .caibx). Required.
      --store URL     Chunk store base URL. Required unless the store
                      can be inferred as `store/` relative to the index.
      --output PATH   Directory to write the assembled output.
                      Defaults to the current directory.

  ## Examples

      mix aria_storage.fetch \\
        --index https://example.com/assets/game.caidx \\
        --store https://example.com/assets/store \\
        --output /tmp/game

  ## Notes

  Chunk files (`.cacnk`) must be served as raw binary content.
  GitHub Pages does not serve binary files — use `raw.githubusercontent.com`
  when the store is hosted in a GitHub repository.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Application.ensure_all_started(:req)
    Application.ensure_all_started(:aria_storage)

    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [index: :string, store: :string, output: :string, cache: :string]
      )

    index_url =
      (Keyword.get(opts, :index) || Mix.raise("--index URL is required"))
      |> normalize_github_url()

    store_url =
      (Keyword.get(opts, :store) || infer_store_url(index_url))
      |> normalize_github_url()

    output_dir = Keyword.get(opts, :output, File.cwd!())

    cache_path = Keyword.get(opts, :cache) || AriaStorage.CasyncDecoder.default_cache_path()

    Mix.shell().info("Index:  #{index_url}")
    Mix.shell().info("Store:  #{store_url}")
    Mix.shell().info("Cache:  #{cache_path}")
    Mix.shell().info("Output: #{output_dir}")

    File.mkdir_p!(output_dir)

    # The decoder calls progress_callback.(done, remaining) — capture the
    # initial total on first call so percentage stays in 0–100%.
    initial_total = :atomics.new(1, [])
    :atomics.put(initial_total, 1, 0)

    progress = fn done, remaining ->
      total = done + remaining

      if :atomics.get(initial_total, 1) == 0 do
        :atomics.put(initial_total, 1, total)
      end

      init = :atomics.get(initial_total, 1)
      pct = if init > 0, do: round(done * 100 / init), else: 0
      Mix.shell().info("  chunks: #{done}/#{init} (#{pct}%)")
    end

    Mix.shell().info("Fetching index...")

    case AriaStorage.CasyncDecoder.decode_uri(index_url,
           store_uri: store_url,
           cache_path: cache_path,
           output_dir: output_dir,
           verify_integrity: true,
           progress_callback: progress
         ) do
      {:ok, result} ->
        Mix.shell().info("")
        Mix.shell().info("Done.")
        Mix.shell().info("  format:  #{result.format}")
        Mix.shell().info("  chunks:  #{result.chunk_count}")
        Mix.shell().info("  index:   #{format_bytes(result.file_size)}")

        if result.assembly_result do
          a = result.assembly_result
          Mix.shell().info("  output:  #{a.assembled_file}")
          Mix.shell().info("  written: #{format_bytes(a.bytes_written)}")
          Mix.shell().info("  verified: #{a.verification_passed}")
        end

      {:error, reason} ->
        Mix.raise("aria_storage.fetch failed: #{inspect(reason)}")
    end
  end

  # Rewrite github.com blob/tree/raw paths → raw.githubusercontent.com so
  # Req receives a direct binary download rather than an HTML page or a 404.
  #   github.com/{owner}/{repo}/blob/{ref}/{path}  → raw.githubusercontent.com/{owner}/{repo}/{ref}/{path}
  #   github.com/{owner}/{repo}/tree/{ref}/{path}  → raw.githubusercontent.com/{owner}/{repo}/{ref}/{path}
  #   github.com/{owner}/{repo}/raw/{ref}/{path}   → raw.githubusercontent.com/{owner}/{repo}/{ref}/{path}
  defp normalize_github_url(url) do
    uri = URI.parse(url)

    case uri do
      %URI{host: "github.com", path: path} when is_binary(path) ->
        case Regex.run(~r{^(/[^/]+/[^/]+)/(blob|tree|raw)/(.+)$}, path) do
          [_, repo_path, _verb, rest] ->
            raw = %URI{
              scheme: "https",
              host: "raw.githubusercontent.com",
              path: "#{repo_path}/#{rest}"
            }

            raw_url = URI.to_string(raw)
            Mix.shell().info("(normalized GitHub URL → #{raw_url})")
            raw_url

          nil ->
            url
        end

      _ ->
        url
    end
  end

  # Assume store/ is a sibling directory of the index file.
  defp infer_store_url(index_url) do
    store_url =
      index_url
      |> URI.parse()
      |> Map.update!(:path, &(Path.dirname(&1) <> "/store"))
      |> URI.to_string()

    Mix.shell().info("No --store given, inferring: #{store_url}")
    store_url
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_bytes(_), do: "unknown"
end
