defmodule MessageAgentTest do
  use ExUnit.Case

  doctest MessageAgent

  describe "next_id/1" do
    test "returns the next identifier" do
      {:ok, agent} = MessageAgent.start_link()

      assert MessageAgent.get_id(agent) != MessageAgent.next_id(agent)
    end

    test "increments the current message identifier" do
      {:ok, agent} = MessageAgent.start_link()
      first_id = MessageAgent.get_id(agent)

      MessageAgent.next_id(agent)

      assert MessageAgent.get_id(agent) != first_id
    end
  end

  describe "put_msg/1" do
    test "adds the message to the set of existing messages" do
      {:ok, agent} = MessageAgent.start_link()
      msg = %{id: "123"}

      MessageAgent.put_msg(agent, msg)

      msgs = MessageAgent.get_msgs(agent)
      assert Enum.member?(msgs, msg.id)
    end
  end

  describe "new_msg?/1" do
    test "is true for new messages" do
      {:ok, agent} = MessageAgent.start_link()
      msg = %{id: "123"}

      assert MessageAgent.new_msg?(agent, msg)
    end

    test "is false for repeated messages" do
      {:ok, agent} = MessageAgent.start_link()
      msg = %{id: "123"}
      MessageAgent.put_msg(agent, msg)

      refute MessageAgent.new_msg?(agent, msg)
    end
  end

  describe "deterministic_hash_id/1" do
    test "is different for different ids" do
      hash1 = MessageAgent.deterministic_hash_id(1)
      hash2 = MessageAgent.deterministic_hash_id(2)

      assert hash1 != hash2
    end

    test "is different for different processes" do
      pid = self()
      hash1 = MessageAgent.deterministic_hash_id(1)
      Task.start fn -> send pid, MessageAgent.deterministic_hash_id(1) end

      receive do
        hash2 -> assert hash1 != hash2
      end
    end
  end

  describe "build!/2" do
    test "increments the id" do
      {:ok, agent} = MessageAgent.start_link()
      first_id = MessageAgent.get_id(agent)

      MessageAgent.build!(agent, "hello")

      assert MessageAgent.get_id(agent) != first_id
    end

    test "adds the message to the received messages list" do
      {:ok, agent} = MessageAgent.start_link()

      msg = MessageAgent.build!(agent, "hello")

      refute MessageAgent.new_msg?(agent, msg)
    end

    test "returns a well-formed message" do
      {:ok, agent} = MessageAgent.start_link()

      assert %{id: _id, content: _content} = MessageAgent.build!(agent, "hello")
    end
  end
end
