import Config

config :bdfr_browser,
  base_directory: System.get_env("BDFR_BROWSER_BASE_DIRECTORY", "/nonexistant"),
  chat_directory: System.get_env("BDFR_BROWSER_CHAT_DIRECTORY", "/nonexistant"),
  watch_directories: System.get_env("BDFR_BROWSER_WATCH_DIRECTORIES", "true"),
  http_ip: to_charlist(System.get_env("BDFR_BROWSER_HTTP_IP", "127.0.0.1")),
  http_port: String.to_integer(System.get_env("BDFR_BROWSER_HTTP_PORT", "4040"))

config :bdfr_browser, BdfrBrowser.Repo,
  database: System.get_env("BDFR_BROWSER_REPO_DATABASE", "postgres"),
  username: System.get_env("BDFR_BROWSER_REPO_USER", "bdfr-browser"),
  password: System.get_env("BDFR_BROWSER_REPO_PASSWORD", ""),
  socket_dir: System.get_env("BDFR_BROWSER_REPO_SOCKET_DIR", nil),
  hostname: System.get_env("BDFR_BROWSER_REPO_HOST", nil)
