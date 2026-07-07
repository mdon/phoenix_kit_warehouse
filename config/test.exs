import Config

config :phoenix_kit_warehouse, ecto_repos: [PhoenixKitWarehouse.Test.Repo]

config :phoenix_kit_warehouse, PhoenixKitWarehouse.Test.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  database: "phoenix_kit_warehouse_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  priv: "test/support/postgres"

# Wire repo for library code that calls PhoenixKit.RepoHelper.repo()
config :phoenix_kit, repo: PhoenixKitWarehouse.Test.Repo

config :logger, level: :warning

config :phoenix_kit_warehouse, PhoenixKitWarehouse.Test.Endpoint,
  secret_key_base: String.duplicate("a", 64),
  server: false
