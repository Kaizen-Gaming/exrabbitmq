defmodule ExRabbitMQ.ChannelRipper do
  @moduledoc """
  Monitors when a `ExRabbitMQ.Producer` or `ExRabbitMQ.Consumer` dies and when it does, it kills the AMQP channel.
  """

  @module __MODULE__

  use GenServer

  @doc """
  Starts a new `ExRabbitMQ.ChannelRipper` process which will immediately starts monitoring the calling process.
  """
  @spec start :: GenServer.on_start()
  def start do
    GenServer.start(@module, %{monitored_pid: self(), channel: nil})
  end

  @doc """
  Sets the AMQP channel to kill when the monitored process dies.
  """
  @spec set_channel(channel_ripper_pid :: pid, channel :: %AMQP.Channel{}) :: term
  def set_channel(channel_ripper_pid, channel) do
    GenServer.call(channel_ripper_pid, {:set_channel, channel})
  end

  @impl true
  def init(state) do
    %{monitored_pid: monitored_pid} = state

    Process.monitor(monitored_pid)

    {:ok, state}
  end

  @impl true
  def handle_call({:set_channel, channel}, _from, state) do
    new_state = %{state | channel: channel}

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %{channel: nil} = state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %{channel: channel} = state) do
    AMQP.Channel.close(channel)

    {:stop, :normal, state}
  rescue
    _ -> {:stop, :normal, state}
  catch
    _ -> {:stop, :normal, state}
    _, _ -> {:stop, :normal, state}
  end

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end
end
