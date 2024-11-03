import Config

config :logger,
  level: :debug

app_dir = File.cwd!()
priv_dir = Path.join(app_dir, "test/priv/ssh")

config :playground,
  ssh_system_dir: priv_dir
