defmodule ExRabbitMQ.Config.Queue do
  @moduledoc false

  alias ExRabbitMQ.Config.Bind, as: XRMQBindConfig
  alias ExRabbitMQ.Config.Session, as: XRMQSessionConfig

  @name __MODULE__

  @type t :: %__MODULE__{
          name: String.t(),
          opts: keyword,
          bindings: list
        }

  defstruct [:name, :opts, :bindings]

  @spec get(queue_config :: keyword) :: t()
  def get(queue_config) do
    case queue_config do
      queue_config when is_list(queue_config) -> from_env(queue_config)
      _ -> queue_config
    end
    |> merge_defaults()
    |> validate_name()
    |> XRMQSessionConfig.validate_bindings()
  end

  defp from_env(config) do
    %@name{
      name: config[:name],
      opts: config[:opts],
      bindings: XRMQBindConfig.get(config[:bindings] || [])
    }
  end

  defp merge_defaults(%@name{} = config) do
    %@name{
      name: config.name,
      opts: config.opts || [],
      bindings: XRMQBindConfig.get(config.bindings || [])
    }
  end

  defp validate_name(%@name{name: name} = config) when is_binary(name), do: config

  defp validate_name(config) do
    raise ArgumentError, "invalid queue name declaration: #{inspect(config)}"
  end
end
