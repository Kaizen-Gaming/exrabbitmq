defmodule ExRabbitMQ.AST.Consumer.GenServer do
  @moduledoc """
  AST holding module for the consumer behaviour when the surrounding consumer is a GenServer.
  """

  @doc """
  Produces part of the AST for the consumer behaviour when the consumer is a GenServer.
  It holds GenServer handle_info callbacks and a few default implementations.
  Specifically, it handles the basic_deliver and basic_cancel AMQP events.
  It also responds to connection and channel events, trying to keep a channel open when a connection is available.
  """
  def ast do
    quote location: :keep do
      alias ExRabbitMQ.Config.Environment, as: XRMQEnvironmentConfig
      alias ExRabbitMQ.State, as: XRMQState

      @impl true
      def handle_info({:basic_deliver, payload, meta}, state) do
        if XRMQEnvironmentConfig.accounting_enabled() and is_binary(payload) do
          payload
          |> byte_size()
          |> Kernel./(1_024)
          |> Float.round()
          |> trunc()
          |> XRMQState.add_kb_of_messages_seen_so_far()
        end

        callback_result = xrmq_basic_deliver(payload, meta, state)

        if XRMQEnvironmentConfig.accounting_enabled() and XRMQState.hibernate?(),
          do: xrmq_on_hibernation_threshold_reached(callback_result),
          else: callback_result
      end

      @impl true
      def handle_info({:basic_cancel, cancellation_info}, state) do
        xrmq_basic_cancel(cancellation_info, state)
      end

      @impl true
      def handle_info({:xrmq_connection, {:new, connection}}, state) do
        state = xrmq_on_connection_opened(connection, state)

        {:noreply, state}
      end

      @impl true
      def handle_info({:xrmq_connection, {:open, connection}}, state) do
        case xrmq_open_channel_setup_consume(state) do
          {:ok, state} ->
            state = xrmq_on_connection_reopened(connection, state)
            state = xrmq_flush_buffered_messages(state)

            {:noreply, state}

          {:error, reason, state} ->
            case xrmq_on_connection_reopened_consume_failed(reason, state) do
              {:cont, state} -> {:noreply, state}
              {:halt, reason, state} -> {:stop, reason, state}
            end
        end
      end

      @impl true
      def handle_info({:xrmq_connection, {:closed, _}}, state) do
        XRMQState.set_connection_status(:disconnected)

        state = xrmq_on_connection_closed(state)

        # WE WILL CONTINUE HANDLING THIS EVENT WHEN WE HANDLE THE CHANNEL DOWN EVENT

        {:noreply, state}
      end

      @impl true
      def handle_info({:DOWN, ref, :process, pid, reason}, state) do
        case XRMQState.get_channel_info() do
          {_, ^ref} ->
            XRMQState.set_channel_info(nil, nil)

            case xrmq_open_channel_setup_consume(state) do
              {:ok, state} ->
                state = xrmq_flush_buffered_messages(state)

                {:noreply, state}

              {:error, reason, state} ->
                case xrmq_on_channel_reopened_consume_failed(reason, state) do
                  {:cont, state} -> {:noreply, state}
                  {:halt, reason, state} -> {:stop, reason, state}
                end
            end

          _ ->
            send(self(), {{:DOWN, ref, :process, pid, reason}})

            {:noreply, state}
        end
      end

      @impl true
      def handle_info({:xrmq_try_init, opts}, state), do: xrmq_try_init_consumer(opts, state)

      @impl true
      def handle_continue({:xrmq_try_init, opts, continuation}, state) do
        case xrmq_try_init_consumer(opts, state) do
          result when continuation === nil -> result
          {action, state} -> {action, state, continuation}
          error -> error
        end
      end
    end
  end
end
