defmodule ExRabbitMQ.State do
  @moduledoc """
  Provides functions for saving or getting the state such as the configuration, connection and channel information of a
  `ExRabbitMQ.Consumer` or `ExRabbitMQ.Producer` process in its process dictionary.
  """

  @type connection_status :: :connected | :disconnected
  @type buffered_message ::
          {payload :: binary, exchange :: binary, routing_key :: binary, opts :: keyword}

  alias ExRabbitMQ.Config.Connection, as: ConnectionConfig
  alias ExRabbitMQ.Config.Environment, as: XRMQEnvironmentConfig
  alias ExRabbitMQ.Config.Session, as: XRMQSessionConfig
  alias ExRabbitMQ.Constants

  @doc """
  Get the `ExRabbitMQ.Config.Connection` struct from the process dictionary.
  """
  @spec get_connection_config :: ConnectionConfig.t() | nil
  def get_connection_config do
    Process.get(Constants.connection_config_key())
  end

  @doc """
  Set the `ExRabbitMQ.Config.Connection` struct in the process dictionary.
  """
  @spec set_connection_config(ConnectionConfig.t() | nil) :: term | nil
  def set_connection_config(config) do
    Process.put(Constants.connection_config_key(), config)
  end

  @doc """
  Get the `ExRabbitMQ.Connection` pid from the process dictionary.
  """
  @spec get_connection_pid :: pid | nil
  def get_connection_pid do
    Process.get(Constants.connection_pid_key())
  end

  @doc """
  Set the `ExRabbitMQ.Connection` pid in the process dictionary.
  """
  @spec set_connection_pid(pid | nil) :: term | nil
  def set_connection_pid(connection_pid) do
    Process.put(Constants.connection_pid_key(), connection_pid)
  end

  @doc """
  Get the `ExRabbitMQ.ChannelRipper` pid from the process dictionary.
  """
  @spec get_channel_ripper_pid :: pid | nil
  def get_channel_ripper_pid do
    Process.get(Constants.channel_ripper_pid_key())
  end

  @doc """
  Set the `ExRabbitMQ.ChannelRipper` pid in the process dictionary.
  """
  @spec set_channel_ripper_pid(pid | nil) :: term | nil
  def set_channel_ripper_pid(channel_ripper_pid) do
    Process.put(Constants.channel_ripper_pid_key(), channel_ripper_pid)
  end

  @doc """
  Get the `AMQP.Channel` struct and the channel pid from the process dictionary.
  """
  @spec get_channel_info :: {AMQP.Channel.t() | nil, pid | nil}
  def get_channel_info do
    {Process.get(Constants.channel_key()), Process.get(Constants.channel_monitor_key())}
  end

  @doc """
  Set the `AMQP.Channel` struct and the channel pid in the process dictionary.
  """
  @spec set_channel_info(AMQP.Channel.t() | nil, reference | nil) ::
          term | nil
  def set_channel_info(channel, channel_monitor) do
    Process.put(Constants.channel_key(), channel)
    Process.put(Constants.channel_monitor_key(), channel_monitor)
  end

  @doc """
  Get the `ExRabbitMQ.Config.Session` struct from the process dictionary.
  """
  @spec get_session_config :: XRMQSessionConfig.t() | nil
  def get_session_config do
    Process.get(Constants.session_config_key())
  end

  @doc """
  Set the `ExRabbitMQ.Config.Session` struct in the process dictionary.
  """
  @spec set_session_config(XRMQSessionConfig.t()) :: term | nil
  def set_session_config(config) do
    Process.put(Constants.session_config_key(), config)
  end

  @doc """
  Get the current connection status from the process dictionary.
  """
  @spec get_connection_status :: connection_status
  def get_connection_status do
    Process.get(Constants.connection_status_key(), :disconnected)
  end

  @doc """
  Set the current connection status in the process dictionary.
  """
  @spec set_connection_status(connection_status) :: connection_status
  def set_connection_status(status) when status in [:connected, :disconnected] do
    Process.put(Constants.connection_status_key(), status)
  end

  @doc """
  Get whether or not a consumer should automatically start consuming on connection from the process dictionary.
  """
  @spec get_auto_consume_on_connection :: boolean
  def get_auto_consume_on_connection do
    Process.get(Constants.auto_consume_on_connection_key(), true)
  end

  @doc """
  Set whether or not a consumer should automatically start consuming on connection in the process dictionary.
  """
  @spec set_auto_consume_on_connection(boolean) :: boolean
  def set_auto_consume_on_connection(auto_consume_on_connection)
      when is_boolean(auto_consume_on_connection) do
    Process.put(Constants.auto_consume_on_connection_key(), auto_consume_on_connection)
  end

  @doc """
  Get and clear the buffered messages of a producer from the process dictionary.

  The messages of a producer start being buffered when the connection to RabbitMQ is lost.
  """
  @spec get_clear_buffered_messages :: {non_neg_integer, [buffered_message]}
  def get_clear_buffered_messages do
    count = clear_buffered_messages_count()
    buffered_messages = Process.delete(Constants.buffered_messages_key()) || []

    {count, buffered_messages}
  end

  @doc """
  Add a message to the buffered messages of a producer in the process dictionary.
  """
  @spec add_buffered_message(buffered_message) :: [buffered_message]
  def add_buffered_message(message) do
    buffered_messages = Process.get(Constants.buffered_messages_key(), [])
    buffered_messages = [message | buffered_messages]

    increase_buffered_messages_count()

    Process.put(Constants.buffered_messages_key(), buffered_messages)
  end

  @doc """
  Get the buffered messages count of a producer from the process dictionary.
  """
  @spec get_buffered_messages_count :: non_neg_integer
  def get_buffered_messages_count do
    Process.get(Constants.buffered_messages_count_key(), 0)
  end

  @doc """
  Set the buffered messages count of a producer to 0, in the process dictionary.
  """
  @spec clear_buffered_messages_count() :: term | nil
  def clear_buffered_messages_count() do
    Process.delete(Constants.buffered_messages_count_key()) || 0
  end

  @doc """
  Get the byte count of messages seen so far, in KBs, from the process dictionary.
  """
  @spec get_kb_of_messages_seen_so_far :: non_neg_integer | nil
  def get_kb_of_messages_seen_so_far do
    Process.get(Constants.kb_of_messages_seen_so_far_key(), 0)
  end

  @doc """
  Check whether the process must hibernate, based on the KBs of messages seen so far.
  """
  @spec hibernate? :: boolean
  def hibernate?() do
    kb_so_far = get_kb_of_messages_seen_so_far()
    hibernate? = kb_so_far >= XRMQEnvironmentConfig.kb_of_messages_seen_so_far_threshold()

    if hibernate?,
      do: Process.put(Constants.kb_of_messages_seen_so_far_key(), 0),
      else: Process.put(Constants.kb_of_messages_seen_so_far_key(), kb_so_far)

    hibernate?
  end

  @doc """
  Add to the byte count of messages seen so far, in KBs, in the process dictionary.
  """
  @spec add_kb_of_messages_seen_so_far(non_neg_integer) :: term | nil
  def add_kb_of_messages_seen_so_far(kb) when is_number(kb) and kb >= 0 do
    kb_so_far = get_kb_of_messages_seen_so_far()

    Process.put(Constants.kb_of_messages_seen_so_far_key(), kb_so_far + kb)
  end

  # Increase the buffered messages count of a producer by one, in the process dictionary.
  @spec increase_buffered_messages_count() :: non_neg_integer
  defp increase_buffered_messages_count() do
    count = get_buffered_messages_count()

    Process.put(Constants.buffered_messages_count_key(), count + 1)
  end
end
