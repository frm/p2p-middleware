defmodule Gossip.Worker do
  use Task

  def start_link(args) do
    Task.start_link(__MODULE__, :perform, args)
  end

  def perform(_pid, socket) do
    echo_loop(socket)
  end

  defp echo_loop(socket) do
    result = case :gen_tcp.recv(socket, 0) do
      {:ok, msg} ->
        :gen_tcp.send(socket, msg)
        :ok

      {:error, :closed} ->
        IO.puts "socket is closed"
        :closed

      {:error, reason} ->
        IO.inspect reason
        :error
    end

    result == :ok and echo_loop(socket)
  end
end
