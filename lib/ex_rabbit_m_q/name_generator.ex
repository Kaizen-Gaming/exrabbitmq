defmodule ExRabbitMQ.NameGenerator do
  @moduledoc """
  A module to create queue and exchange names dynamically
  """

  @startup_time_key {__MODULE__, :startup_time}

  @doc """
  Will store the start time of this application for usage with dynamic names
  """
  def initialize(), do: store_statup_time()

  @spec unique_name(prefix :: String.t()) :: String.t()
  def unique_name(prefix),
    do: prefix <> "#{get_statup_time()}-#{:erlang.unique_integer([:positive])}"

  defp store_statup_time(), do: :persistent_term.put(@startup_time_key, :erlang.system_time())
  defp get_statup_time(), do: :persistent_term.get(@startup_time_key)
end
