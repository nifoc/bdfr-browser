defmodule BdfrBrowser.Repo do
  use Ecto.Repo,
    otp_app: :bdfr_browser,
    adapter: Ecto.Adapters.Postgres
end
