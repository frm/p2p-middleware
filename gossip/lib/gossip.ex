defmodule Gossip do
  use GenServer

  def start_link([port: port, callback: callback], opts \\ []) do
    GenServer.start_link(__MODULE__, %{port: port, callback: callback}, opts)
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
    GenServer.cast(pid, {:recv, msg})
  end

  def connect(pid, host, port) do
    GenServer.call(pid, {:connect, host, port})
  end

  # Client API

  def init(%{port: port, callback: callback} = default_state) do
    {:ok, server} = start_server(port)
    {:ok, message_agent} = start_message_agent()

    state =
      default_state
      |> Map.put(:neighbours, %{})
      |> Map.put(:server, server)
      |> Map.put(:message_agent, message_agent)
      |> Map.put(:callback, callback)

    {:ok, state}
  end

  def handle_cast({:accept, socket}, state) do
    new_state = assign_worker(socket, state)

    {:noreply, new_state}
  end

  def handle_cast({:disconnect, pid}, state) do
    neighbours = Map.delete(state[:neighbours], pid)
    new_state = %{state | neighbours: neighbours}

    {:noreply, new_state}
  end

  def handle_cast({:broadcast, %{id: _, content: _} = msg}, state) do
    %{neighbours: neighbours, message_agent: message_agent} = state
    {:ok, packed_msg} = MessageAgent.pack(msg)

    Enum.each neighbours, fn({pid, _socket}) ->
      send pid, {:send, packed_msg}
    end

    {:noreply, state}
  end
  def handle_cast({:broadcast, msg}, %{message_agent: message_agent} = state) do
    formatted_msg = MessageAgent.build!(message_agent, msg)

    handle_cast({:broadcast, formatted_msg}, state)
  end

  def handle_cast({:recv, packed_msg}, state) do
    case MessageAgent.unpack(packed_msg) do
      {:ok, %{id: _, content: content} = msg} ->
        if MessageAgent.new_msg?(state.message_agent, msg) do
          MessageAgent.put_msg(state.message_agent, msg)
          state.callback.(content)
          Gossip.broadcast(self(), msg)
        end
      _ ->
        nil
    end

    {:noreply, state}
  end

  def handle_call({:connect, host, port}, _from, state) do
    {reply, new_state} = case TCP.connect_to(host, port, [active: true]) do
      {:ok, socket} ->
        new_state = assign_worker(socket, state)
        {{:ok, :connected}, new_state}

      {:error, _} = error ->
        {error, state}
    end

    {:reply, reply, new_state}
  end

  defp start_message_agent, do: MessageAgent.start_link()

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

  defp assign_worker(socket, state) do
    {:ok, pid} = start_worker(socket)
    TCP.controlling_process(socket, pid)

    neighbours = Map.put(state[:neighbours], pid, socket)
    %{state | neighbours: neighbours}
  end
end
