defmodule BdfrBrowser.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    {:ok, http_ip} = :inet.parse_address(Application.fetch_env!(:bdfr_browser, :http_ip))
    http_port = Application.fetch_env!(:bdfr_browser, :http_port)

    children = [
      {Plug.Cowboy, scheme: :http, plug: BdfrBrowser.HTTP.Plug, options: [ip: http_ip, port: http_port]},
      :systemd.ready()
    ]

    opts = [strategy: :one_for_one, name: BdfrBrowser.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
