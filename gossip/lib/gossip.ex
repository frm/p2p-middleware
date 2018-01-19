defmodule Gossip do
  use GenServer

  def start_link(port, opts \\ []) do
    GenServer.start_link(__MODULE__, %{port: port}, opts)
  end

  def accept(pid, socket) do
    GenServer.cast(pid, {:accept, socket})
  end

  def disconnect(pid, worker) do
    GenServer.cast(pid, {:disconnect, worker})
  end

  def broadcast(pid, msg) do
    GenServer.cast(pid, {:broadcast, msg})
  end

  def recv(pid, msg) do
    GenServer.call(pid, {:recv, msg})
  end

  # Client API

  def init(%{port: port} = default_state) do
    {:ok, server} = start_server(port)

    state =
      default_state
      |> Map.put(:messages, [])
      |> Map.put(:neighbours, %{})
      |> Map.put(:server, server)

    {:ok, state}
  end

  def handle_cast({:accept, socket}, state) do
    {:ok, pid} = start_worker(socket)
    :gen_tcp.controlling_process(socket, pid)

    neighbours = Map.put(state[:neighbours], pid, socket)
    new_state = %{state | neighbours: neighbours}

    {:noreply, new_state}
  end

  def handle_cast({:disconnect, pid}, state) do
    neighbours = Map.delete(state[:neighbours], pid)
    new_state = %{state | neighbours: neighbours}

    {:noreply, new_state}
  end

  def handle_cast({:broadcast, msg}, %{neighbours: neighbours} = state) do
    Enum.each neighbours, fn({pid, _socket}) ->
      send pid, {:send, msg}
    end

    {:noreply, state}
  end

  def handle_call({:recv, msg}, _from, state) do
    {:reply, msg, state}
  end

  defp start_server(port) do
    Supervisor.start_link([
      {Gossip.Server, [self(), port]}
    ], strategy: :one_for_one)
  end

  defp start_worker(socket) do
    {:ok, supervisor} = Supervisor.start_link([
      {Gossip.Worker, [self(), socket]}
    ],
    strategy: :one_for_one,
    max_restarts: 0)

    {:ok, worker_pid_of(supervisor)}
  end

  defp worker_pid_of(supervisor) do
    Supervisor.which_children(supervisor)
    |> List.first
    |> elem(1)
  end
end
