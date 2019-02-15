defmodule ExRabbitMQ.Config.Bind do
  @moduledoc false

  defstruct [:exchange, :opts]

  @type t :: %__MODULE__{
          exchange: String.t(),
          opts: keyword
        }

  @spec get([map]) :: [t()]
  def get(bind_config) do
    bind_config
    |> Enum.map(
      &(&1
        |> case do
          &1 when is_list(&1) -> from_env(&1)
          _ -> &1
        end
        |> merge_defaults()
        |> validate_name())
    )
  end

  defp from_env(config) do
    %__MODULE__{
      exchange: config[:exchange],
      opts: config[:opts]
    }
  end

  defp merge_defaults(%__MODULE__{} = config) do
    %__MODULE__{
      exchange: config.exchange,
      opts: config.opts || []
    }
  end

  defp validate_name(%__MODULE__{exchange: exchange} = config) when is_binary(exchange),
    do: config

  defp validate_name(config) do
    raise ArgumentError, "invalid exchange name declaration: #{inspect(config)}"
  end
end
