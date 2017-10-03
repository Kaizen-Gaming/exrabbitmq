defmodule ExRabbitMQ.ChannelRipper do
  @moduledoc false
  @module __MODULE__

  use GenServer

  def start_link() do
    GenServer.start_link(@module, %{linked_pid: self(), channel: nil})
  end

  def set_channel(channel_ripper_pid, channel) do
    GenServer.call(channel_ripper_pid, {:set_channel, channel})
  end

  def init(%{linked_pid: linked_pid} = state) do
    Process.flag(:trap_exit, true)

    Process.link(linked_pid)

    {:ok, state}
  end

  def handle_call({:set_channel, channel}, _from, state) do
    new_state = %{state | channel: channel}

    {:reply, :ok, new_state}
  end

  def handle_info({:EXIT, _from, _reason}, %{channel: nil} = state) do
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, _from, _reason}, %{channel: channel} = state) do
    AMQP.Channel.close(channel)

    {:stop, :normal, state}
  catch
    _ -> {:stop, :normal, state}
    _, _ -> {:stop, :normal, state}
  rescue
    _ -> {:stop, :normal, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
