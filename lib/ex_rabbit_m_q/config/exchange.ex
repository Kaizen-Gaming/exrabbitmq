defmodule ExRabbitMQ.Config.Exchange do
  @moduledoc false

  alias ExRabbitMQ.Config.Bind, as: XRMQBindConfig
  alias ExRabbitMQ.Config.Session, as: XRMQSessionConfig

  @name __MODULE__

  @type t :: %__MODULE__{
          name: String.t(),
          type: atom,
          opts: keyword,
          bindings: list
        }

  defstruct [:name, :type, :opts, :bindings]

  @spec get(exchange_config :: keyword) :: t()
  def get(exchange_config) do
    case exchange_config do
      exchange_config when is_list(exchange_config) -> from_env(exchange_config)
      _ -> exchange_config
    end
    |> merge_defaults()
    |> validate_name()
    |> XRMQSessionConfig.validate_bindings()
  end

  defp from_env(config) do
    %@name{
      name: config[:name],
      type: config[:type],
      opts: config[:opts],
      bindings: XRMQBindConfig.get(config[:bindings] || [])
    }
  end

  defp merge_defaults(%@name{} = config) do
    %@name{
      name: config.name,
      type: config.type || :direct,
      opts: config.opts || [],
      bindings: XRMQBindConfig.get(config.bindings || [])
    }
  end

  defp validate_name(%@name{name: name} = config) when is_binary(name), do: config

  defp validate_name(config) do
    raise ArgumentError, "invalid exchange name declaration: #{inspect(config)}"
  end
end
