import Config

config :bdfr_browser,
  ecto_repos: [BdfrBrowser.Repo]

config :bdfr_browser, BdfrBrowser.Repo,
  migration_primary_key: [name: :id, type: :string],
  migration_foreign_key: [column: :id, type: :string]

config :logger,
  backends: [:console],
  level: :info,
  handle_otp_reports: false,
  handle_sasl_reports: false

import_config "#{Mix.env()}.exs"
