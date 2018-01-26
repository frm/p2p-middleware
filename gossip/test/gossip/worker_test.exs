defmodule Gossip.WorkerTest do
  use ExUnit.Case
  use Gossip.TCPSocketCase

  describe "recv_loop/2" do
    test "echoes :tcp messages" do
      str = "another one bites the dust"
      {in_socket, out_socket} = start_and_connect_to(3000)
      {:ok, task} = start_task(self(), in_socket)

      send_task task, {:tcp, in_socket, str}

      assert_reply out_socket, str
    end

    test "disconnects on :tcp_closed messages" do
      {in_socket, out_socket} = start_and_connect_to(3000)
      {:ok, task} = start_task(self(), in_socket)

      send_task task, {:tcp_closed, in_socket}

      assert_closed out_socket
      assert_closed in_socket
      assert_receive {:"$gen_cast", {:disconnect, ^task}}
    end

    test "sends a message on :send messages" do
      str = "another one bites the dust"
      {in_socket, out_socket} = start_and_connect_to(3000)
      {:ok, task} = start_task(self(), in_socket)

      send_task task, {:send, str}

      assert_reply out_socket, str
    end
  end

  defp start_and_connect_to(port) do
    Gossip.Server.start_link([self(), port])

    {:ok, out_socket} = connect_to_tcp_socket(port)
    {:ok, in_socket} = receive_accept_msg()

    {in_socket, out_socket}
  end

  defp receive_accept_msg do
    receive do
      {:"$gen_cast", {:accept, in_socket}} -> {:ok, in_socket}
    after
      3_000 -> {:error, :timeout}
    end
  end

  defp start_task(pid, socket) do
    {:ok, task} = Task.start fn -> Gossip.Worker.recv_loop(pid, socket) end
    :gen_tcp.controlling_process(socket, task)

    {:ok, task}
  end

  # {:tcp, socket, str} msg are GenServer synchronous calls.
  # To avoid the process hanging waiting for the GenServer reply we must
  # mimic the GenServer behaviour and reply to the $gen_call message.
  defp send_task(task, {:tcp, _socket, _str} = msg) do
    send task, msg

    receive do
      {:"$gen_call", {from, ref}, {:recv, msg}} ->
        send from, {ref, msg}
    end
  end
  defp send_task(task, msg), do: send task, msg
end
