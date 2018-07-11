defmodule ExRabbitMQ.Config.Pool do
  @moduledoc false

  @name __MODULE__

  @type t :: %__MODULE__{
          size: pos_integer,
          strategy: atom,
          max_overflow: pos_integer
        }

  defstruct [:size, :strategy, :max_overflow]

  @spec get(pool_config :: t()) :: t()
  def get(pool_config) do
    case pool_config do
      pool_config when is_list(pool_config) -> from_env(pool_config)
      _ -> pool_config
    end
    |> merge_defaults()
  end

  defp from_env(config) do
    %@name{
      size: config[:size],
      strategy: config[:strategy],
      max_overflow: config[:max_overflow]
    }
  end

  defp merge_defaults(%@name{} = config) do
    %@name{
      size: config.size || 20,
      strategy: :weighted,
      max_overflow: config.max_overflow || 1
    }
  end
end