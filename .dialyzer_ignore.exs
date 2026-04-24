# Dialyzer false-positive suppression.
# All entries are library integration issues, not bugs in this project.
# Run `mix dialyzer` and verify "Unnecessary Skips: 0".
#
# Known unfilterable: deps/ecto/lib/ecto/type.ex:7:callback_info_missing
# (Ecto.Type behaviour info not in PLT; dep-level, dialyxir cannot suppress it.)

[
  # Plug behaviour + Plug.Conn functions — delegation patterns dialyzer cannot follow.
  {"lib/aria_storage/chunk_server_plug.ex", :callback_info_missing},
  {"lib/aria_storage/chunk_server_plug.ex", :unknown_function},

  # Porcelain.exec/2 not specced in PLT.
  {"lib/aria_storage/desync.ex", :unknown_function},

  # Req.get/2 not resolved despite :req in plt_add_apps.
  {"lib/casync_decoder.ex", :unknown_function},

  # Mix.Task behaviour and Mix.Shell functions not in PLT.
  {"lib/mix/tasks/aria_storage.fetch.ex", :callback_info_missing},
  {"lib/mix/tasks/aria_storage.fetch.ex", :unknown_function},
  # Mix.Task.run/1 raises via Mix.raise when --index missing — by design.
  {"lib/mix/tasks/aria_storage.fetch.ex", :no_return},

  # Waffle macros generate functions dialyzer cannot see.
  {"lib/waffle_adapter.ex", :unknown_function},
  {"lib/waffle_chunk_store.ex", :unknown_function},
  {"lib/waffle_example.ex", :unknown_function},

  # Utilities module uses IO functions dialyzer over-approximates.
  {"lib/parsers/casync_format/utilities.ex", :unknown_function},

  # Storage.ex uses ExAws macros.
  {"lib/storage.ex", :unknown_function},

  # ChunkUploader uses Waffle macros.
  {"lib/chunk_uploader.ex", :unknown_function},
]
