defmodule Playground.Server do
  @moduledoc """
  Playground server is respponsible for talking to the erlang :ssh application in order to start the playground SSH interface.
  """

  use GenServer
  require Logger
  alias Playground.Sessions

  @port 2222

  @doc false
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{pid: nil}, name: __MODULE__)
  end

  @doc false
  @spec handle_info(map | any, map) :: {:noreply, map}
  @impl true
  def handle_info(_, state), do: {:noreply, state}

  @impl true
  def init(state) do
    GenServer.cast(self(), :start)
    {:ok, state}
  end

  @impl true
  def handle_cast(:start, state) do
    port = @port
    system_dir = Application.fetch_env!(:playground, :ssh_system_dir) |> String.to_charlist()

    Logger.info("Using system dir #{inspect(system_dir)}")

    start_result =
      :ssh.daemon(port,
        system_dir: system_dir,
        parallel_login: false,
        key_cb: Playground.Authenticator,
        shell: &on_shell/2,
        auth_methods: ~c"publickey",
        connectfun: &on_shell_connect/3,
        disconnectfun: &on_shell_disconnect/1
      )

    case start_result do
      {:ok, pid} when is_pid(pid) ->
        Logger.info("SSH server started on port #{port}")
        Process.link(pid)
        {:noreply, %{state | pid: pid}, :hibernate}

      {:error, :eaddrinuse} ->
        :ok = Logger.error("Unable to bind to local TCP port; the address is already in use")
        {:stop, :normal, state}

      {:error, err} ->
        Logger.error("Unhandled error encountered: #{inspect(err)}")
        {:stop, :normal, state}
    end
  end

  @type ip_address :: :inet.ip_address()
  @type port_number :: :inet.port_number()
  @type peer_address :: {ip_address, port_number}

  @doc false
  @spec on_shell_connect(String.t(), peer_address, String.t()) :: any
  def on_shell_connect(username, peer_address, _method) do
    Sessions.set_username(self(), username)
    Sessions.set_peer_address(self(), peer_address)
  end

  @doc false
  @spec on_shell_disconnect(any) :: :ok
  def on_shell_disconnect(_) do
    Sessions.delete(self())
  end

  @spec on_shell(String.t(), peer_address) :: pid
  @doc """
  This function is called when a shell is connected to the server. It will run different shell depending on the user.  
  If the user is guest, it will run a shell that will guide the user through the setup of a public key, otherwise it will 
  start a shell that will wait until user selects a puzzle on the website (or pastes the code in the prompt).
  """
  def on_shell(_username, peer) do
    {_pid, session} = Sessions.get_by_peer_address(peer)

    case Map.get(session, "public_key") do
      nil ->
        {:ok, pid} =
          Task.start_link(fn ->
            :ok = IO.puts("You are guest")
          end)

        pid

      _ ->
        spawn_link(Playground.ShellHandler, :on_shell, [])
    end
  end
end
