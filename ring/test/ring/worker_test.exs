defmodule Ring.WorkerTest do
  use ExUnit.Case
  use Ring.TCPSocketCase

  describe "recv_loop/2" do
    test "receives :tcp messages" do
      str = "another one bites the dust"
      {in_socket, out_socket} = start_and_connect_to(3000)
      {:ok, task} = start_task(self(), in_socket)

      send task, {:tcp, in_socket, str}

      assert_receive {:"$gen_cast", {:recv, ^str}}
    end

    test "disconnects on :tcp_closed messages" do
      {in_socket, out_socket} = start_and_connect_to(3000)
      {:ok, task} = start_task(self(), in_socket)

      send task, {:tcp_closed, in_socket}

      assert_closed out_socket
      assert_closed in_socket
      assert_receive {:"$gen_cast", {:disconnect, ^task}}
    end

    test "sends a message on :send messages" do
      str = "another one bites the dust"
      {in_socket, out_socket} = start_and_connect_to(3000)
      {:ok, task} = start_task(self(), in_socket)

      send task, {:send, str}

      assert_reply out_socket, str
    end
  end

  defp start_and_connect_to(port) do
    Ring.Server.start_link([self(), port])

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
    {:ok, task} = Task.start fn -> Ring.Worker.recv_loop(pid, socket) end
    TCP.controlling_process(socket, task)

    {:ok, task}
  end
end
