defmodule GossipTest do
  use ExUnit.Case
  use Gossip.TCPSocketCase

  doctest Gossip

  @default_state %{port: 0,
                   neighbours: %{},
                   messages: [],
                   server: self()}

  describe "init/1" do
    test "creates a server process" do
      {:ok, state} = Gossip.init(%{port: 3000})

      assert Process.alive?(state.server)
    end

    test "sets the the default state" do
      assert {:ok, state} = Gossip.init(%{port: 3000})
      assert %{messages: [], neighbours: %{}, server: _} = state
    end
  end

  describe "handle_cast/2 for :accept messages" do
    test "creates a worker process" do
      {:ok, _} = Gossip.start_link(3000)
      {:ok, socket} = connect_to_tcp_socket(3000)

      {:noreply, state} = Gossip.handle_cast({:accept, socket}, @default_state)

      pid = Enum.at(state.neighbours, 0) |> elem(0)
      assert Process.alive?(pid)
    end

    test "updates the neighbour list" do
      {:ok, _} = Gossip.start_link(3000)
      {:ok, socket} = connect_to_tcp_socket(3000)

      {:noreply, state} = Gossip.handle_cast({:accept, socket}, @default_state)

      assert Enum.count(state.neighbours) > 0
    end
  end

  describe "handle_cast/2 for :disconnect messages" do
    test "updates the neighbour list" do
      {:ok, state} = Gossip.init(%{port: 3000})
      {:ok, socket} = connect_to_tcp_socket(3000)
      {:noreply, state} = Gossip.handle_cast({:accept, socket}, state)
      pid = Enum.at(state.neighbours, 0) |> elem(0)

      {:noreply, state} = Gossip.handle_cast({:disconnect, pid}, state)

      assert %{} = state.neighbours
    end
  end

  describe "handle_call/3 for :recv messages" do
    test "echoes the message" do
      str = "So you thought you might like to go to the show"

      response = Gossip.handle_call({:recv, str}, self(), %{})

      {:reply, ^str, %{}} = response
    end
  end
end
