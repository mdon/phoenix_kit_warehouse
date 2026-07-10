import Config

# Test database configuration.
# Integration tests need a real PostgreSQL database. Create it with:
#   mix test.setup       # createdb
config :phoenix_kit_warehouse, ecto_repos: [PhoenixKitWarehouse.Test.Repo]

config :phoenix_kit_warehouse, PhoenixKitWarehouse.Test.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  database: "phoenix_kit_warehouse_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Wire repo for PhoenixKit.RepoHelper — without this, all DB calls crash.
config :phoenix_kit, repo: PhoenixKitWarehouse.Test.Repo

# Test Endpoint for LiveView tests. `phoenix_kit_warehouse` has no
# endpoint of its own in production — the host app provides one — so this
# endpoint only exists for `Phoenix.LiveViewTest`.
config :phoenix_kit_warehouse, PhoenixKitWarehouse.Test.Endpoint,
  secret_key_base: String.duplicate("t", 64),
  live_view: [signing_salt: "warehouse-test-salt"],
  server: false,
  url: [host: "localhost"],
  render_errors: [formats: [html: PhoenixKitWarehouse.Test.Layouts]]

config :phoenix, :json_library, Jason

config :logger, level: :warning
