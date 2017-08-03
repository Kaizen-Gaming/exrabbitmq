# ExRabbitMQ

RabbitMQ client library, written in Elixir, which abstracts away connection and channel lifecycle handling.

It provides hooks and default function implementations, to allow library users to consume and publish messages,
minimizing the need to directly interact with the AMQP module.

## Required `ExRabbitMQ.Consumer` callbacks

`c:ExRabbitMQ.Consumer.xrmq_basic_deliver/3`
```elixir
def xrmq_basic_deliver(payload :: term, meta :: term, state :: term) ::
  {:noreply, new_state :: term} |
  {:noreply, new_state :: term, timeout | :hibernate} |
  {:noreply, [event :: term], new_state :: term} |
  {:noreply, [event :: term], new_state :: term, :hibernate} |
  {:stop, reason :: term, new_state :: term}
```
## Overridable `ExRabbitMQ.Consumer` callbacks

`c:ExRabbitMQ.Consumer.xrmq_channel_setup/1`
```elixir
def xrmq_channel_setup(state :: term) ::
  {:ok, new_state :: term} |
  {:error, reason :: term, new_state :: term}
```

---

`c:ExRabbitMQ.Consumer.xrmq_queue_setup/2`
```elixir
def xrmq_queue_setup(queue :: String.t, state :: term) ::
  {:ok, new_state :: term} |
  {:error, reason :: term, new_state :: term}
```

---

`c:ExRabbitMQ.Consumer.xrmq_basic_cancel/2`
```elixir
def xrmq_basic_cancel(cancellation_info :: any, state :: any) ::
  {:noreply, new_state :: term} |
  {:noreply, new_state :: term, timeout | :hibernate} |
  {:noreply, [event :: term], new_state :: term} |
  {:noreply, [event :: term], new_state :: term, :hibernate} |
  {:stop, reason :: term, new_state :: term}
```

---

`c:ExRabbitMQ.Consumer.xrmq_basic_ack/2`
```elixir
def xrmq_basic_ack(delivery_tag :: String.t, state :: term) ::
  {:ok, new_state :: term} |
  {:error, reason :: term, new_state :: term}
```

---

`c:ExRabbitMQ.Consumer.xrmq_basic_reject/2`
```elixir
def xrmq_basic_reject(delivery_tag :: String.t, state :: term) ::
  {:ok, new_state :: term} |
  {:error, reason :: term, new_state :: term}
def xrmq_basic_reject(delivery_tag :: String.t, opts :: term, state :: term) ::
  {:ok, new_state :: term} |
  {:error, reason :: term, new_state :: term}
```

## Provided `ExRabbitMQ.Consumer` functions

`c:ExRabbitMQ.Consumer.xrmq_init/3`
```elixir
def xrmq_init(connection_key :: atom, queue_key :: atom, state :: term) ::
  {:ok, new_state :: term} |
  {:error, reason :: term, new_state :: term}
def xrmq_init(connection_key :: atom, queue_config :: struct, state :: term) ::
  {:ok, new_state :: term} |
  {:error, reason :: term, new_state :: term}
def xrmq_init(connection_config :: struct, queue_key :: atom, state :: term) ::
  {:ok, new_state :: term} |
  {:error, reason :: term, new_state :: term}
def xrmq_init(connection_config :: struct, queue_config :: struct, state :: term) ::
  {:ok, new_state :: term} |
  {:error, reason :: term, new_state :: term}
```

---

`c:ExRabbitMQ.Consumer.xrmq_get_connection_config/0`
```elixir
def xrmq_get_connection_config() :: term
```

---

`c:ExRabbitMQ.Consumer.xrmq_get_queue_config/0`
```elixir
def xrmq_get_queue_config() :: term
```

## Overridable `ExRabbitMQ.Producer` callbacks

`c:ExRabbitMQ.Producer.xrmq_channel_setup/1`
```elixir
def xrmq_channel_setup(state :: term) ::
  {:ok, new_state :: term} |
  {:error, reason :: term, new_state :: term}
```

## Provided `ExRabbitMQ.Producer` functions

`c:ExRabbitMQ.Producer.xrmq_init/2`
```elixir
def xrmq_init(connection_key :: atom, state :: term) ::
  {:ok, new_state :: term} |
  {:error, reason :: term, new_state :: term}
def xrmq_init(connection_config :: struct, state :: term) ::
  {:ok, new_state :: term} |
  {:error, reason :: term, new_state :: term}
```

---

`c:ExRabbitMQ.Producer.xrmq_get_connection_config/0`
```elixir
def xrmq_get_connection_config() :: term
```

---

`c:ExRabbitMQ.Producer.xrmq_basic_publish/4`
```elixir
def xrmq_basic_publish(payload :: term, exchange :: String.t, routing_key :: String.t, opts :: [term]) ::
  :ok |
  {:error, reason :: :blocked | :closing | :no_channel}
```

## Configuration

You can provide configuration for connections and queues in two ways.

1. Define configuration sections under application `:exrabbitmq` with appropriate atom keys and pass these keys to `c:ExRabbitMQ.Consumer.xrmq_init/2` and `c:ExRabbitMQ.Producer.xrmq_init/1`.
2. Use the configuration structs `ExRabbitMQ.ConnectionConfig` and `ExRabbitMQ.Consumer.QueueConfig` and pass them directly to
`c:ExRabbitMQ.Consumer.xrmq_init/2` and `c:ExRabbitMQ.Producer.xrmq_init/1`.

## Example usage

For an example usage please refer to **[test/ex_rabbit_m_q_test.exs](./test.html)**.

There you will find a complete producer/consumer example, which you can run
given a local RabbitMQ installation at `127.0.0.1:5672` with the default
credentials `guest:guest`.
