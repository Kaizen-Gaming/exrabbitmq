defmodule ExRabbitMQ.Config.Queue do
  @moduledoc false

  alias ExRabbitMQ.Config.Bind, as: XRMQBindConfig
  alias ExRabbitMQ.Config.Session, as: XRMQSessionConfig

  defstruct [:name, :opts, :bindings]

  @type t :: %__MODULE__{
          name: String.t(),
          opts: keyword,
          bindings: list
        }

  @spec get(keyword) :: t()
  def get(queue_config) do
    queue_config
    |> case do
      queue_config when is_list(queue_config) -> from_env(queue_config)
      _ -> queue_config
    end
    |> merge_defaults()
    |> validate_name()
    |> XRMQSessionConfig.validate_bindings()
  end

  defp from_env(config) do
    %__MODULE__{
      name: config[:name],
      opts: config[:opts],
      bindings: XRMQBindConfig.get(config[:bindings] || [])
    }
  end

  defp merge_defaults(%__MODULE__{} = config) do
    %__MODULE__{
      name: config.name,
      opts: config.opts || [],
      bindings: XRMQBindConfig.get(config.bindings || [])
    }
  end

  defp validate_name(%__MODULE__{name: name} = config) when is_binary(name), do: config

  defp validate_name(config) do
    raise ArgumentError, "invalid queue name declaration: #{inspect(config)}"
  end
end
