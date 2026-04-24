# AriaStorage

Content-addressable chunk storage compatible with the
[casync](https://github.com/systemd/casync) /
[desync](https://github.com/folbricht/desync) wire format.

## How it works

Files are split into content-defined chunks using a rolling Buzhash algorithm.
Each chunk is identified by `SHA-512/256(uncompressed_data)` and stored as a
zstd-compressed `.cacnk` file at `/<4-hex-prefix>/<64-hex-id>.cacnk` — the
same path layout used by desync, so stores are interoperable.

Index files (`.caibx` for blobs, `.caidx` for directory trees) record the
ordered list of chunk IDs needed to reconstruct the original file.

## Modules

| Module | Role |
|---|---|
| `AriaStorage` | Public API facade |
| `AriaStorage.Chunks` / `Chunks.Core` | Rolling-hash chunking (Buzhash), SHA-512/256 IDs, zstd compression |
| `AriaStorage.Chunks.Assembly` | Reassemble a file from chunks given an index |
| `AriaStorage.CasyncDecoder` | Parse `.caibx`/`.caidx` index files; fetch and verify chunks from a store or URI; concurrent assembly |
| `AriaStorage.Parsers.CasyncFormat` | Binary format parser for CAIBX, CAIDX, CACNK, CATAR |
| `AriaStorage.WaffleChunkStore` | Store/retrieve `.cacnk` files via Waffle (local, S3, GCS) |
| `AriaStorage.ChunkUploader` | `Waffle.Definition` callbacks — filename, path layout, integrity validation |
| `AriaStorage.WaffleAdapter` | Higher-level adapter: configures backend at runtime, decodes retrieved chunks |
| `AriaStorage.Storage` | `store_file_with_waffle/2` — reads a file, chunks it, stores via Waffle |
| `AriaStorage.Desync` | Optional wrapper around the external `desync` CLI |

## Write path

```
file
 └─ Chunks.Core.create_chunks/2          rolling Buzhash, content-defined boundaries
     └─ chunk.id = SHA-512/256(data)
     └─ chunk.compressed = zstd(data)
 └─ WaffleChunkStore.store_chunk/2
     └─ writes compressed bytes to temp file
     └─ Waffle.Definition.store/1
         ├─ local  →  <storage_dir>/<ab12>/<ab12cd...>.cacnk
         └─ S3     →  s3://<bucket>/<ab12>/<ab12cd...>.cacnk
 └─ Chunks.create_index/2                CAIBX struct: ordered chunk IDs + offsets
```

## Read path

```
index.caibx
 └─ CasyncDecoder.decode_file/2          or Parsers.CasyncFormat.parse_index/1
     └─ for each chunk ID:
         └─ check XDG cache (~/.cache/casync/chunks/)
         └─ fetch from store_path / store_uri
         └─ CasyncFormat.parse_chunk/1   verify magic, decompress zstd
         └─ :file.pwrite(fd, offset, data)   parallel, up to 64 concurrent tasks
```

## Usage

```elixir
# Chunk a file and store via Waffle (local backend)
{:ok, result} = AriaStorage.store_file("/path/to/file", backend: :local)

# Chunk a file manually
{:ok, chunks} = AriaStorage.create_chunks("/path/to/file")
index = AriaStorage.create_index(chunks)

# Assemble from chunks + index
{:ok, path} = AriaStorage.assemble_file(chunks, index, "/output/file")

# Decode a .caibx index and fetch chunks from a local store
{:ok, decoded} = AriaStorage.CasyncDecoder.decode_file(
  "archive.caibx",
  store_path: "/path/to/store"
)
```

## Storage backend configuration

Backend is selected at runtime via the `:waffle` application env, set by
`WaffleAdapter.configure_waffle/2` or `Storage.configure_waffle_storage/1`:

```elixir
# Local filesystem (default)
AriaStorage.configure_storage(%{backend: :local, storage_dir: "/var/lib/chunks"})

# Amazon S3 / S3-compatible
AriaStorage.configure_storage(%{backend: :s3, bucket: "my-chunks", region: "us-east-1"})

# Google Cloud Storage
AriaStorage.configure_storage(%{backend: :gcs, bucket: "my-chunks"})
```

## Wire format compatibility

Chunk IDs use `SHA-512/256` (FIPS 180-4), matching casync and desync exactly —
not truncated SHA-512. Stores produced by this library can be read by `desync`
and vice versa.

## Running tests

```bash
mix test
```
