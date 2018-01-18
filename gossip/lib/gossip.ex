defmodule Gossip do
  use GenServer

  def start_link(port, opts \\ []) do
    GenServer.start_link(__MODULE__, %{port: port}, opts)
  end

  def accept(pid, socket) do
    GenServer.cast(pid, {:accept, socket})
  end

  # Client API

  def init(%{port: port} = default_state) do
    {:ok, server} = start_server(port)

    state =
      default_state |> Map.put(:messages, [])
      |> Map.put(:neighbours, [])
      |> Map.put(:server, server)

    {:ok, state}
  end

  def handle_cast({:accept, socket}, state) do
    start_worker(socket)

    neighbours = [socket | state[:neighbours]]
    new_state = %{state | neighbours: neighbours}

    {:noreply, new_state}
  end

  defp start_server(port) do
    Supervisor.start_link([
      {Gossip.Server, [self(), port]}
    ], strategy: :one_for_one)
  end

  defp start_worker(socket) do
    Supervisor.start_link([
      {Gossip.Worker, [self(), socket]}
    ],
    strategy: :one_for_one,
    max_restarts: 0)
  end
end
