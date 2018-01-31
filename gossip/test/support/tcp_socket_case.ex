defmodule Gossip.TCPSocketCase do
  @moduledoc """
  Defines the test case to be used in tests that require TCP Socket connections
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      def connect_to_tcp_socket(port) do
        TCP.connect_to('localhost', port)
      end

      def assert_reply(socket) do
        assert {:ok, reply} = :gen_tcp.recv(socket, 0)
      end

      def assert_reply(socket, expected_reply) do
        {:ok, reply} = :gen_tcp.recv(socket, 0)

        assert reply == expected_reply
      end

      def assert_closed(socket) do
        assert {:error, :closed} = :gen_tcp.recv(socket, 0)
      end

      def assert_invalid(socket) do
        assert {:error, :einval} = :gen_tcp.recv(socket, 0)
      end
    end
  end
end
