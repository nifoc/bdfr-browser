import Config

config :bdfr_browser,
  base_directory: System.get_env("BDFR_BROWSER_BASE_DIRECTORY", "/nonexistant"),
  http_ip: to_charlist(System.get_env("BDFR_BROWSER_HTTP_IP", "127.0.0.1")),
  http_port: String.to_integer(System.get_env("BDFR_BROWSER_HTTP_PORT", "4040"))
