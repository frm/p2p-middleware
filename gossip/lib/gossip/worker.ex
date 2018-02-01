defmodule Gossip.Worker do
  use Task

  def start_link(args) do
    Task.start_link(__MODULE__, :recv_loop, args)
  end

  def recv_loop(pid, socket) do
    continue = receive do
      {:tcp, _port, msg} ->
        Gossip.recv(pid, msg)

        true

      {:tcp_closed, port} ->
        TCP.close(port)
        Gossip.disconnect(pid, self())

        false

      {:send, msg} ->
        TCP.send(socket, msg)

        true

      msg ->
        IO.inspect(msg)

        true
    end

    continue and recv_loop(pid, socket)
  end
end
