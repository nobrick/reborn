# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# By default, the umbrella project as well as each child
# application will require this configuration file, ensuring
# they all use the same configuration. While one could
# configure all applications here, we prefer to delegate
# back to each application for organization purposes.
import_config "../apps/*/config/config.exs"

# Sample configuration (overrides the imported configuration above):
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
import_config "#{Mix.env}.exs"
config :dirk, ecto_repos: [Dirk.Repo]
config :machine, fstate_ba: 1000.0
config :machine, chunk_size: 6
config :machine, chunk_step: 1
config :machine, feature_keys: ~w(d_la d_hi d_lo)a
config :machine, data_storage_path: Path.expand("data", File.cwd!)
config :machine, corr_filters: [{0.9, 37}]
