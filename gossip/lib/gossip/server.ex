defmodule Gossip.Server do
  use Task

  def start_link(args) do
    Task.start_link(__MODULE__, :listen, args)
  end

  def listen(pid, port) do
    {:ok, server_socket} = TCP.listen(port)

    accept_loop(pid, server_socket)
  end

  defp accept_loop(pid, server_socket) do
    {:ok, client} = TCP.accept(server_socket)
    :inet.setopts(client, [active: true])
    TCP.controlling_process(client, pid)

    Gossip.accept(pid, client)

    accept_loop(pid, server_socket)
  end
end
