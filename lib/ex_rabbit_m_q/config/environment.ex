defmodule ExRabbitMQ.Config.Environment do
  @moduledoc false

  alias ExRabbitMQ.Constants

  def logging_enabled() do
    Application.get_env(:exrabbitmq, Constants.logging_config_key(), false)
  end

  def accounting_enabled() do
    Application.get_env(:exrabbitmq, Constants.accounting_config_key(), false)
  end

  def message_buffering_enabled() do
    Application.get_env(:exrabbitmq, Constants.message_buffering_config_key(), false)
  end

  def try_init_interval() do
    Application.get_env(:exrabbitmq, Constants.try_init_interval_config_key(), 1_000)
  end

  def kb_of_messages_seen_so_far_threshold() do
    Application.get_env(
      :exrabbitmq,
      Constants.kb_of_messages_seen_so_far_threshold_config_key(),
      100 * 1_024
    )
  end

  @spec validate() :: :ok | no_return
  def validate() do
    validate(:threshold)

    :ok
  end

  @spec validate(atom) :: :ok | no_return
  defp validate(key)

  defp validate(:threshold) do
    error_message =
      "Configuration key #{Constants.kb_of_messages_seen_so_far_threshold_config_key()} " <>
        "must be set with a non-negative integer or the atom :infinity"

    threshold = kb_of_messages_seen_so_far_threshold()
    threshold_valid? = is_number(threshold) and threshold > 0

    if !threshold_valid? and is_atom(threshold) and threshold !== :infinity do
      raise ArgumentError, error_message
    end

    :ok
  end
end
