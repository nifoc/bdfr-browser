defmodule BdfrBrowser.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    repos = Application.fetch_env!(:bdfr_browser, :ecto_repos)
    {:ok, http_ip} = :inet.parse_address(Application.fetch_env!(:bdfr_browser, :http_ip))
    http_port = Application.fetch_env!(:bdfr_browser, :http_port)

    children = [
      {Ecto.Migrator, repos: repos, skip: System.get_env("SKIP_MIGRATIONS") == "true"},
      BdfrBrowser.Repo,
      BdfrBrowser.Importer,
      {Plug.Cowboy, scheme: :http, plug: BdfrBrowser.HTTP.Plug, options: [ip: http_ip, port: http_port]},
      :systemd.ready()
    ]

    opts = [strategy: :one_for_one, name: BdfrBrowser.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
