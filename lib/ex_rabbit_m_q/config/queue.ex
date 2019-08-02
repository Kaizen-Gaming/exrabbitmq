defmodule ExRabbitMQ.Config.Queue do
  @moduledoc false

  alias ExRabbitMQ.Config.Bind, as: XRMQBindConfig
  alias ExRabbitMQ.Config.Session, as: XRMQSessionConfig

  defstruct [:name, :name_prefix, :opts, :bindings]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          name_prefix: String.t() | nil,
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
      name_prefix: config[:name_prefix],
      opts: config[:opts],
      bindings: XRMQBindConfig.get(config[:bindings] || [])
    }
  end

  def get_queue_name(%__MODULE__{name: name}) when is_binary(name), do: name

  def get_queue_name(%__MODULE__{name_prefix: prefix}) when is_binary(prefix),
    do: ExRabbitMQ.NameGenerator.unique_name(prefix)

  defp merge_defaults(%__MODULE__{} = config) do
    %__MODULE__{
      name: config.name,
      name_prefix: config.name_prefix,
      opts: config.opts || [],
      bindings: XRMQBindConfig.get(config.bindings || [])
    }
  end

  defp validate_name(%__MODULE__{name: name} = config) when is_binary(name), do: config
  defp validate_name(%__MODULE__{name_prefix: prefix} = config) when is_binary(prefix), do: config

  defp validate_name(config) do
    raise ArgumentError, "invalid queue name declaration: #{inspect(config)}"
  end
end
