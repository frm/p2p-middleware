defmodule MessageAgent do
  defdelegate pack(msg), to: Msgpax
  defdelegate pack!(msg), to: Msgpax

  def start_link do
    Agent.start_link fn -> %{id: 0, msgs: MapSet.new} end
  end

  def build!(pid, content) do
    id = MessageAgent.next_id(pid)
    MessageAgent.put_msg(pid, id)

    %{id: id, content: content}
  end

  def next_id(pid) do
    :ok = Agent.update pid, fn %{id: id} = map ->
      Map.put(map, :id, id + 1)
    end

    MessageAgent.get_id(pid)
  end

  def get_id(pid) do
    id = Agent.get(pid, fn map -> map.id end)

    deterministic_hash_id(id)
  end

  def get_msgs(pid) do
    Agent.get(pid, fn map -> map.msgs end)
  end

  def new_msg?(pid, %{id: id}) do
    msgs = MessageAgent.get_msgs(pid)
    not MapSet.member?(msgs, id)
  end

  def put_msg(pid, %{id: id}), do: put_msg(pid, id)
  def put_msg(pid, id) when is_binary(id) do
    Agent.update pid, fn %{msgs: msgs} = map ->
      new_mapset = MapSet.put(msgs, id)
      Map.put(map, :msgs, new_mapset)
    end
  end

  def unpack(msg) do
    case Msgpax.unpack(msg) do
      {:ok, %{"id" => id, "content" => content}} ->
        {:ok, %{id: id, content: content}}
      {:error, _} = error ->
        error
    end
  end

  def unpack!(msg) do
    %{"id" => id, "content" => content} = Msgpax.unpack!(msg)

    %{id: id, content: content}
  end

  def deterministic_hash_id(id) do
    msg_id = id |> to_string
    beam_ref = self() |> inspect
    machine_ref = :os.getpid() |> to_string
    global_ref = Inet.active_mac_addr()

    msg_ref = msg_id <> beam_ref <> machine_ref <> global_ref
    :crypto.hash(:sha256, msg_ref) |> Base.encode16
  end
end
