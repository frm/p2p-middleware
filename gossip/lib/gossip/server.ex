defmodule Gossip.Server do
  use Task

  @opts [:binary,
         packet: 0,
         active: false,
         reuseaddr: :true]

  def start_link(args) do
    Task.start_link(__MODULE__, :listen, args)
  end

  def listen(pid, port) do
    {:ok, server_socket} = :gen_tcp.listen(port, @opts)

    accept_loop(pid, server_socket)
  end

  defp accept_loop(pid, server_socket) do
    {:ok, client} = :gen_tcp.accept(server_socket)
    :inet.setopts(client, [active: true])
    :gen_tcp.controlling_process(client, pid)

    Gossip.accept(pid, client)

    accept_loop(pid, server_socket)
  end
end
