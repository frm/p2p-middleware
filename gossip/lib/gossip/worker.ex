defmodule Gossip.Worker do
  use Task

  def start_link(args) do
    Task.start_link(__MODULE__, :loop_again, args)
  end

  def loop_again(pid, socket) do
    loop = case :gen_tcp.recv(socket, 0) do
      {:ok, msg} ->
        Gossip.recv(pid, msg)
        |> handle_reply(socket)

        true

      {:error, :closed} ->
        IO.puts "socket is closed"
        false

      {:error, reason} ->
        IO.inspect reason
        false
    end

    loop and loop_again(pid, socket)
  end

  defp handle_reply(:noreply, _socket), do: nil
  defp handle_reply(reply, socket), do: :gen_tcp.send(socket, reply)
end
