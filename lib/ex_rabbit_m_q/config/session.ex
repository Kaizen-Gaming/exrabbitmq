defmodule ExRabbitMQ.Config.Session do
  @moduledoc """
  A structure holding the necessary information about a binding of an exchange or queue
  which is not otherwise declared by the application.

  This entity must exist prior to trying to bind it.

  #### Bind configuration example:

  ```elixir
  # :queue is this queue's configuration name
  config :exrabbitmq, :my_session_config,

    # name of the queue from which we wish to consume (optional, default: "")
    queue: "my_queue",

    # properties set on the queue when it is declared (optional, default: [])
    queue_opts: [
      durable: true
    ],

    # the exchange name to declare and bind (optional, default: nil)
    exchange: "my_exchange",

    # the options to use when one wants to declare the exchange (optional, default: [])
    exchange_opts: [

      # the exchange type to declare (optional, default: :direct)
      # this is an atom that can have one of the following values:
      # :direct, :fanout, :topic or :headers
      type: :fanout,

      # other exchange declare options as documented in the Options paragraph of
      # https://hexdocs.pm/amqp/AMQP.Exchange.html#declare/4, eg.:
      durable: true,
      auto_delete: true,
      passive: false,
      internal: false
    ]

    # the options to use when binding the queue to the exchange (optional, default: [])
    bind_opts: [
      routing_key: "my_routing_key",
      nowait: false,
      arguments: []
    ],

    # the options to use for specifying QoS properties on a channel (optional, default: [])
    qos_opts: [
      prefetch_size: 1,
      prefetch_count: 1,
      global: true
    ],

    # properties set on the call to consume from the queue (optional, default: [])
    consume_opts: [
      no_ack: false
    ]
  ```
  """

  alias ExRabbitMQ.Config.Bind, as: XRMQBindConfig
  alias ExRabbitMQ.Config.Exchange, as: XRMQExchangeConfig
  alias ExRabbitMQ.Config.Queue, as: XRMQQueueConfig

  defstruct [:queue, :consume_opts, :qos_opts, :declarations]

  @type t :: %__MODULE__{
          queue: String.t(),
          consume_opts: keyword,
          qos_opts: keyword,
          declarations: list
        }

  @doc """
  Returns a part of the `app` configuration section, specified with the
  `key` argument as a `ExRabbitMQ.Config.Session` struct.
  If the `app` argument is omitted, it defaults to `:exrabbitmq`.
  """
  @spec get(atom, atom | t()) :: t()
  def get(app \\ :exrabbitmq, session_config) do
    session_config
    |> case do
      session_config when is_atom(session_config) -> from_env(app, session_config)
      _ -> session_config
    end
    |> merge_defaults()
  end

  def validate_bindings(%{bindings: bindings} = config) do
    Enum.reduce_while(bindings, config, fn
      binding, %XRMQBindConfig{exchange: nil} ->
        raise ArgumentError, "invalid source exchange: #{inspect(binding)}"

      _, _ ->
        {:cont, config}
    end)
  end

  defp from_env(app, key) do
    config = Application.get_env(app, key, [])

    %__MODULE__{
      queue: config[:queue],
      consume_opts: config[:consume_opts],
      qos_opts: config[:qos_opts],
      declarations: get_declarations(config[:declarations] || [])
    }
  end

  # Merges an existing `ExRabbitMQ.Config.Session` struct the default values when these are `nil`.
  defp merge_defaults(%__MODULE__{} = config) do
    %__MODULE__{
      queue: config.queue || "",
      consume_opts: config.consume_opts || [],
      qos_opts: config.qos_opts || [],
      declarations: get_declarations(config.declarations || [])
    }
  end

  defp get_declarations(declarations) do
    Enum.map(declarations, fn
      {:exchange, config} -> {:exchange, XRMQExchangeConfig.get(config)}
      {:queue, config} -> {:queue, XRMQQueueConfig.get(config)}
      {:bind, config} -> {:bind, XRMQBindConfig.get(config)}
      declaration -> raise ArgumentError, "invalid declaration #{inspect(declaration)}"
    end)
  end
end
