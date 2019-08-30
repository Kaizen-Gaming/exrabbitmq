defmodule ExRabbitMQ.Config.Utils do
  @moduledoc false

  alias ExRabbitMQ.Config.Connection, as: ConnectionConfig
  alias ExRabbitMQ.Config.Session, as: SessionConfig
  alias ExRabbitMQ.Constants

  # logging

  def logging_set?(), do: get_config_set(Constants.logging_config_key())

  def enable_logging(), do: set_config(Constants.logging_config_key(), true)

  def disable_logging(), do: set_config(Constants.logging_config_key(), false)

  # accounting

  def accounting_set?(), do: get_config_set(Constants.accounting_config_key())

  def enable_accounting(), do: set_config(Constants.accounting_config_key(), true)

  def disable_accounting(), do: set_config(Constants.accounting_config_key(), false)

  # message buffering

  def message_buffering_set?(), do: get_config_set(Constants.message_buffering_config_key())

  def enable_message_buffering(), do: set_config(Constants.message_buffering_config_key(), true)

  def disable_message_buffering(), do: set_config(Constants.message_buffering_config_key(), false)

  # try_init interval

  def get_try_init_interval(), do: get_config(Constants.try_init_interval_config_key())

  def set_try_init_interval(interval) when is_number(interval) and interval > 0 do
    set_config(Constants.try_init_interval_config_key(), interval)
  end

  # KBs of messages seen so far threshold

  def get_kb_of_messages_seen_so_far_threshold() do
    get_config(Constants.kb_of_messages_seen_so_far_threshold_config_key())
  end

  def set_kb_of_messages_seen_so_far_threshold(threshold)
      when (is_number(threshold) and threshold > 0) or threshold === :infinity do
    set_config(Constants.kb_of_messages_seen_so_far_threshold_config_key(), threshold)
  end

  # continue_tuple_try_init

  @doc """
  A convenience function to produce a valid `:continue` tuple, for calling `xrmq_try_init/4` with the proper arguments.

  If a continuation tuple is provided then it will be chained.

  This version applies only to consumers.
  """
  @spec continue_tuple_try_init(connection_config, session_config, boolean, continuation) ::
          {:continue,
           {:xrmq_try_init, {connection_config, session_config, boolean}, continuation}}
        when connection_config: atom | ConnectionConfig.t(),
             session_config: atom | SessionConfig.t(),
             continuation: {:continue, term} | nil
  def continue_tuple_try_init(
        connection_config,
        session_config,
        auto_consume,
        continuation
      ) do
    {:continue, {:xrmq_try_init, {connection_config, session_config, auto_consume}, continuation}}
  end

  @doc """
  A convenience function to produce a valid `:continue` tuple, for calling `xrmq_try_init/3` with the proper arguments.

  If a continuation tuple is provided then it will be chained.

  This version applies only to producers.
  """
  @spec continue_tuple_try_init(connection_config, session_config, continuation) ::
          {:continue, {:xrmq_try_init, {connection_config, session_config}, continuation}}
        when connection_config: atom | ConnectionConfig.t(),
             session_config: atom | SessionConfig.t() | nil,
             continuation: {:continue, term} | nil
  def continue_tuple_try_init(connection_config, session_config, continuation) do
    {:continue, {:xrmq_try_init, {connection_config, session_config}, continuation}}
  end

  # helpers

  defp get_config(key, default \\ nil) do
    Application.get_env(:exrabbitmq, key, default)
  end

  defp get_config_set(key) do
    case Application.fetch_env(:exrabbitmq, key) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp set_config(key, value) do
    Application.put_env(:exrabbitmq, key, value)
  end
end
