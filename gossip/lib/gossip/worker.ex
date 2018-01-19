defmodule Gossip.Worker do
  use Task

  def start_link(args) do
    Task.start_link(__MODULE__, :loop_again, args)
  end

  def loop_again(pid, socket) do
    loop = receive do
      {:tcp, port, msg} ->
        Gossip.recv(pid, msg)
        |> handle_reply(port)

        true

      {:tcp_closed, port} ->
        :gen_tcp.close(port)
        Gossip.disconnect(pid, self())
        false

      {:send, msg} ->
        :gen_tcp.send(socket, msg)
        true

      msg ->
        IO.inspect msg
        false
    end

    loop and loop_again(pid, socket)
  end

  defp handle_reply(:noreply, _socket), do: nil
  defp handle_reply(reply, socket), do: :gen_tcp.send(socket, reply)
end
