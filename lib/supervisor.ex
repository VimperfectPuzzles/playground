defmodule Playground.Supervisor do
  use Supervisor

  @moduledoc """
  Supervisor is responsible for starting ssh server.
  """

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {Playground.Sessions, name: Playground.Sessions},
      {Playground.Server, name: Playground.Server}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
