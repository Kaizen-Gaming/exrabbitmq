defmodule ExRabbitMQ.Constants do
  @moduledoc """
  A module holding constants (e.g., process dictionay keys) that are used in multiple sites.
  """

  @doc """
  The key in the process dictionary holding the connection pid (GenServer) used by a consumer or a producer.
  """
  @spec connection_pid_key :: :xrmq_connection_pid
  def connection_pid_key, do: :xrmq_connection_pid

  @doc false
  @spec channel_ripper_pid_key :: :xrmq_channel_ripper_pid
  def channel_ripper_pid_key, do: :xrmq_channel_ripper_pid

  @doc """
  The key in the process dictionary holding the connection configuration used by consumers and producers.
  """
  @spec connection_config_key :: :xrmq_connection_config
  def connection_config_key, do: :xrmq_connection_config

  @doc """
  The key in the process dictionary holding the queue configuration used by a consumer.
  """
  @spec session_config_key :: :xrmq_session_config
  def session_config_key, do: :xrmq_session_config

  @doc """
  The key in the process dictionary holding the channel struct used by a consumer or a producer.
  """
  @spec channel_key :: :xrmq_channel
  def channel_key, do: :xrmq_channel

  @doc """
  The key in the process dictionary holding the channel monitor reference for the open channel used by a consumer or a producer.
  """
  @spec channel_monitor_key :: :xrmq_channel_monitor
  def channel_monitor_key, do: :xrmq_channel_monitor

  @doc """
  The key in the process dictionary holding the current connection status.
  """
  @spec connection_status_key :: :xrmq_connection_status
  def connection_status_key, do: :xrmq_connection_status

  @doc """
  The key in the process dictionary holding a boolean value that indicates whether or not a consumer should
  automatically start consuming on connection.
  """
  @spec auto_consume_on_connection_key :: :xrmq_auto_consume_on_connection
  def auto_consume_on_connection_key, do: :xrmq_auto_consume_on_connection

  @doc """
  The key in the process dictionary holding the buffered messages of a producer.
  """
  @spec buffered_messages_key :: :xrmq_buffered_messages
  def buffered_messages_key, do: :xrmq_buffered_messages

  @doc """
  The key in the process dictionary holding the buffered messages count of a producer.
  """
  @spec buffered_messages_count_key :: :xrmq_buffered_messages_count
  def buffered_messages_count_key, do: :xrmq_buffered_messages_count

  @doc """
  The key in the process dictionary holding the bytes of the messages seen so far, in KBs.
  """
  @spec kb_of_messages_seen_so_far_key :: :xrmq_kb_of_messages_seen_so_far
  def kb_of_messages_seen_so_far_key, do: :xrmq_kb_of_messages_seen_so_far

  @doc """
  The error returned when an attempt to use a closed channel is made.
  """
  @spec no_channel_error :: :no_channel
  def no_channel_error, do: :no_channel

  @doc false
  @spec logging_config_key :: :logging_enabled
  def logging_config_key, do: :logging_enabled

  @doc false
  @spec accounting_config_key :: :accounting_enabled
  def accounting_config_key, do: :accounting_enabled

  @doc false
  @spec message_buffering_config_key :: :message_buffering_enabled
  def message_buffering_config_key, do: :message_buffering_enabled

  @doc false
  @spec try_init_interval_config_key :: :try_init_interval
  def try_init_interval_config_key, do: :try_init_interval

  @doc false
  @spec kb_of_messages_seen_so_far_threshold_config_key :: :kb_of_messages_seen_so_far_threshold
  def kb_of_messages_seen_so_far_threshold_config_key, do: :kb_of_messages_seen_so_far_threshold
end
