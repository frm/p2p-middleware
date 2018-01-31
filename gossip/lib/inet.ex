defmodule Inet do
  @localhost_mac_addr "ff:ff:ff:ff:ff:ff"

  def active_mac_addr do
    case non_local_ipv4_ifaddrs() do
      [{_ip, mac_addr} | _] ->
        from_base_16(mac_addr)

      # This only happens when we are not connected to the internet.
      # This means we are only running in localhost and can safely return
      # a fake MAC Address. At most, the nodes would be identified by their
      # local process identifiers. This is leaking knowledge but I'm ok with it
      # since I'm in a car trip right now and I have no other way to test this
      [] ->
        @localhost_mac_addr
    end
  end

  defp non_local_ipv4_ifaddrs do
    {:ok, addrs} = :inet.getifaddrs()

    for {_, opts} <- addrs,
      {:addr, addr} <- opts,
      {:hwaddr, hwaddr} <- opts,
      tuple_size(addr) == 4,
      addr != {127, 0, 0, 1},
      into: [],
      do: {addr, hwaddr}
  end

  defp from_base_16(addr), do: Enum.map_join(addr, ":", &encode16/1)

  defp encode16(c) when length(c) == 1, do: '0' ++ c
  defp encode16(c) when is_number(c) do
    c
    |> Integer.to_charlist(16)
    |> encode16
  end
  defp encode16(c), do: c
end
