defmodule GossipTest do
  use ExUnit.Case
  use Gossip.TCPSocketCase

  doctest Gossip

  @default_callback &IO.inspect/1

  @default_state %{port: 0,
                   neighbours: %{},
                   messages: [],
                   server: self(),
                   callback: @default_callback}

  describe "init/1" do
    test "creates a server process" do
      {:ok, state} = Gossip.init(%{port: 3000, callback: @default_callback})

      assert Process.alive?(state.server)
    end

    test "sets the the default state" do
      assert {:ok, state} = Gossip.init(%{port: 3000, callback: @default_callback})
      assert %{message_agent: _, neighbours: %{}, server: _} = state
      assert is_pid(state.message_agent)
      assert is_pid(state.server)
    end
  end

  describe "handle_cast/2 for :accept messages" do
    test "creates a worker process" do
      {:ok, _} = Gossip.start_link(port: 3000, callback: @default_callback)
      {:ok, socket} = connect_to_tcp_socket(3000)

      {:noreply, state} = Gossip.handle_cast({:accept, socket}, @default_state)

      {pid, _} = Enum.at(state.neighbours, 0)
      assert Process.alive?(pid)
    end

    test "updates the neighbour list" do
      {:ok, _} = Gossip.start_link(port: 3000, callback: @default_callback)
      {:ok, socket} = connect_to_tcp_socket(3000)

      {:noreply, state} = Gossip.handle_cast({:accept, socket}, @default_state)

      assert Enum.count(state.neighbours) > 0
    end
  end

  describe "handle_cast/2 for :disconnect messages" do
    test "updates the neighbour list" do
      {:ok, state} = Gossip.init(%{port: 3000, callback: @default_callback})
      {:ok, socket} = connect_to_tcp_socket(3000)
      {:noreply, state} = Gossip.handle_cast({:accept, socket}, state)
      {pid, _} = Enum.at(state.neighbours, 0)

      {:noreply, state} = Gossip.handle_cast({:disconnect, pid}, state)

      assert %{} = state.neighbours
    end
  end

  describe "handle_cast/2 for :broadcast messages" do
    test "updates the message agent with the sent message id" do
      str = "So y'a thought y'a might like to go to the show"
      {:ok, state} = Gossip.init(%{port: 3000, callback: @default_callback})
      {:ok, socket} = connect_to_tcp_socket(3000)
      mock_state = %{state | neighbours: [{self(), socket}]}

      {:noreply, new_state} = Gossip.handle_cast({:broadcast, str}, mock_state)

      refute [] == MessageAgent.get_msgs(new_state.message_agent)
    end

    test "sends a message to connected neighbours" do
      str = "To feel the warm thrill of confusion, that space cadet glow"
      {:ok, state} = Gossip.init(%{port: 3000, callback: @default_callback})
      {:ok, socket} = connect_to_tcp_socket(3000)
      mock_state = %{state | neighbours: [{self(), socket}]}

      {:noreply, _} = Gossip.handle_cast({:broadcast, str}, mock_state)

      assert_received {:send, _msg}
    end
  end

  describe "handle_call/3 for :connect message" do
    test "returns {:ok, :connected}" do
      {:ok, _server} = Gossip.start_link(port: 3000, callback: @default_callback)
      default_state = %{neighbours: %{}}

      resp = Gossip.handle_call(
        {:connect, 'localhost', 3000},
        self(),
        default_state
      )

      assert {:reply, {:ok, :connected}, _} = resp
    end

    test "updates the neighbour list" do
      {:ok, _server} = Gossip.start_link(port: 3000, callback: @default_callback)
      default_state = %{neighbours: %{}}

      {:reply, _, state} = Gossip.handle_call(
        {:connect, 'localhost', 3000},
        self(),
        default_state
      )

      assert Enum.count(state.neighbours) > 0
    end

    test "creates a worker progress" do
      {:ok, _server} = Gossip.start_link(port: 3000, callback: @default_callback)
      default_state = %{neighbours: %{}}

      {:reply, _, state} = Gossip.handle_call(
        {:connect, 'localhost', 3000},
        self(),
        default_state
      )

      {pid, _} = Enum.at(state.neighbours, 0)
      assert Process.alive?(pid)
    end

    test "fails if impossible to connect" do
      default_state = %{neighbours: %{}}

      resp = Gossip.handle_call(
        {:connect, 'localhost', 3000},
        self(),
        default_state
      )

      assert {:reply, {:error, _}, _} = resp
    end

    test "does not update the neighbour list if impossible to connect" do
      default_state = %{neighbours: %{}}

      {:reply, _, state} = Gossip.handle_call(
        {:connect, 'localhost', 3000},
        self(),
        default_state
      )

      assert Enum.count(state.neighbours) == 0
    end
  end

  describe "handle_cast/2 for :recv messages" do
    test "updates the message agent with new message ids" do
      str = "Tell me is something eluding you, sunshine?"
      {:ok, state} = Gossip.init(%{port: 3000, callback: @default_callback})
      {:ok, socket} = connect_to_tcp_socket(3000)
      {:ok, packed_msg} = MessageAgent.pack(%{id: "1", content: str})
      mock_state = %{state | neighbours: [{self(), socket}]}

      {:noreply, new_state} = Gossip.handle_cast({:recv, packed_msg}, mock_state)

      refute [] == MessageAgent.get_msgs(state.message_agent)
    end

    test "invokes the callback for new messages" do
      # TODO: Use Mox
    end

    test "broadcasts the new message to neighbours" do
      str = "Is this not what you expected to see?"
      msg = %{id: "1", content: str}
      {:ok, state} = Gossip.init(%{port: 3000, callback: @default_callback})
      {:ok, socket} = connect_to_tcp_socket(3000)
      {:ok, packed_msg} = MessageAgent.pack(msg)
      mock_state = %{state | neighbours: [{self(), socket}]}

      {:noreply, _} = Gossip.handle_cast({:recv, packed_msg}, mock_state)

      # This assertion tests if the Gossip gen server client process asks
      # itself to broadcast a message, instead of checking if it indeed
      # wrote to the socket. That validation is done in the broadcast test.
      assert_received {:"$gen_cast", {:broadcast, ^msg}}
    end

    test "discards repeated messages" do
      str = "Is this not what you expected to see?"
      msg = %{id: "1", content: str}
      {:ok, state} = Gossip.init(%{port: 3000, callback: @default_callback})
      {:ok, socket} = connect_to_tcp_socket(3000)
      {:ok, packed_msg} = MessageAgent.pack(msg)
      mock_state = %{state | neighbours: [{self(), socket}]}
      MessageAgent.put_msg(state.message_agent, "1")

      {:noreply, _} = Gossip.handle_cast({:recv, packed_msg}, mock_state)

      refute_received {:"$gen_cast", {:broadcast, ^msg}}
    end
  end
end
