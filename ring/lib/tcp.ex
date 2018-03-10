defmodule TCP do
  @socket_opts [:binary,
                packet: 0,
                active: false,
                reuseaddr: :true]

  defdelegate controlling_process(socket, pid), to: :gen_tcp
  defdelegate send(socket, msg), to: :gen_tcp
  defdelegate close(socket), to: :gen_tcp
  defdelegate accept(server_socket), to: :gen_tcp

  def connect_to(host, port, opts \\ []) do
    :gen_tcp.connect(host, port, @socket_opts ++ opts)
  end

  def listen(port, opts \\ []) do
    :gen_tcp.listen(port, @socket_opts ++ opts)
  end
end
