defmodule Playground.Application do
  use Application

  @moduledoc """
  Main application module.
  """

  @impl true
  def start(_type, _args) do
    Playground.Supervisor.start_link(name: Playground.Supervisor)
  end
end
