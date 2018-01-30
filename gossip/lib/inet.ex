defmodule Inet do
  def active_mac_addr do
    [{_ip, mac_addr} | _] = non_local_ipv4_ifaddrs()

    from_base_16(mac_addr)
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
