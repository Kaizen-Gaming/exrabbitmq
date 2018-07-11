defmodule ExRabbitMQ.Config.Bind do
  @moduledoc false

  @name __MODULE__

  @type t :: %__MODULE__{
          exchange: String.t(),
          opts: keyword
        }

  defstruct [:exchange, :opts]

  @spec get([map]) :: [t()]
  def get(bind_config) do
    bind_config
    |> Enum.map(
      &(case &1 do
          &1 when is_list(&1) -> from_env(&1)
          _ -> &1
        end
        |> merge_defaults()
        |> validate_name())
    )
  end

  defp from_env(config) do
    %@name{
      exchange: config[:exchange],
      opts: config[:opts]
    }
  end

  defp merge_defaults(%@name{} = config) do
    %@name{
      exchange: config.exchange,
      opts: config.opts || []
    }
  end

  defp validate_name(%@name{exchange: exchange} = config) when is_binary(exchange), do: config

  defp validate_name(config) do
    raise ArgumentError, "invalid exchange name declaration: #{inspect(config)}"
  end
end
