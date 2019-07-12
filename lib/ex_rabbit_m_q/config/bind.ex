defmodule ExRabbitMQ.Config.Bind do
  @moduledoc false

  defstruct [:type, :name, :exchange, :opts]

  @type t :: %__MODULE__{
          type: nil | :queue | :exchange,
          name: nil | String.t(),
          exchange: String.t(),
          opts: keyword
        }

  @spec get(t() | [] | keyword | [keyword]) :: t() | [t()]
  def get(bind_config)

  def get(%__MODULE__{} = bind_config), do: bind_config
  def get([]), do: []

  def get(bind_config) do
    if Keyword.keyword?(bind_config),
      do: get_single(bind_config),
      else: get_list(bind_config)
  end

  @spec get_single(keyword) :: t()
  defp get_single(bind_config) do
    from_env(bind_config)
  end

  @spec get_list([keyword]) :: [t()]
  defp get_list(bind_config) do
    Enum.map(
      bind_config,
      &(&1
        |> case do
          &1 when is_list(&1) -> from_env(&1)
          _ -> &1
        end
        |> merge_defaults()
        |> validate_type()
        |> validate_names())
    )
  end

  defp from_env(config) do
    %__MODULE__{
      type: config[:type],
      name: config[:name],
      exchange: config[:exchange],
      opts: config[:opts]
    }
  end

  defp merge_defaults(%__MODULE__{} = config) do
    %__MODULE__{
      type: config.type,
      name: config.name,
      exchange: config.exchange,
      opts: config.opts || []
    }
  end

  defp validate_type(%__MODULE__{type: type} = config) when type in [nil, :exchange, :queue],
    do: config

  defp validate_type(config) do
    raise ArgumentError, "invalid bindee type: #{inspect(config)}"
  end

  defp validate_names(%__MODULE__{name: name, exchange: exchange} = config)
       when (name === nil or is_binary(name)) and is_binary(exchange),
       do: config

  defp validate_names(config) do
    raise ArgumentError, "invalid bindee and/or exchange name: #{inspect(config)}"
  end
end
