defmodule ExRabbitMQ.Config.Pool do
  @moduledoc false

  defstruct [:size, :strategy, :max_overflow]

  @type t :: %__MODULE__{
          size: pos_integer,
          strategy: atom,
          max_overflow: pos_integer
        }

  @spec get(t()) :: t()
  def get(pool_config) do
    pool_config
    |> case do
      pool_config when is_list(pool_config) -> from_env(pool_config)
      _ -> pool_config
    end
    |> merge_defaults()
  end

  defp from_env(config) do
    %__MODULE__{
      size: config[:size],
      strategy: config[:strategy],
      max_overflow: config[:max_overflow]
    }
  end

  defp merge_defaults(%__MODULE__{} = config) do
    %__MODULE__{
      size: config.size || 20,
      strategy: :weighted,
      max_overflow: config.max_overflow || 1
    }
  end
end
