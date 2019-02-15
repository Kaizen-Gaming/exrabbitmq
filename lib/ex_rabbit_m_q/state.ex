defmodule ExRabbitMQ.State do
  @moduledoc """
  Provides functions for saving or getting the state such as the configuration, connection and channel information of a
  `ExRabbitMQ.Consumer` or `ExRabbitMQ.Producer` process in its process dictionary.
  """

  alias ExRabbitMQ.Config.Connection, as: ConnectionConfig
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
end
