defmodule ExRabbitMQ.AST.Consumer.GenStage do
  @moduledoc false
  # @moduledoc """
  # AST holding module for the consumer behaviour when the surrounding consumer is a GenStage.
  # """

  @doc """
  Produces part of the AST for the consumer behaviour when the consumer is a GenStage.

  It holds GenStage handle_info callbacks and a few default implementations.

  Specifically, it handles the basic_deliver and basic_cancel AMQP events.

  It also responds to connection and channel events, trying to keep a channel open when a connection is available.
  """
  def ast() do
    quote location: :keep do
      alias ExRabbitMQ.State

      def handle_info({:basic_deliver, payload, meta}, state) do
        xrmq_basic_deliver(payload, meta, state)
      end

      def handle_info({:basic_cancel, cancellation_info}, state) do
        xrmq_basic_cancel(cancellation_info, state)
      end

      def handle_info({:xrmq_connection, {:open, connection}}, state) do
        new_state =
          state
          |> xrmq_open_channel_consume()
          |> xrmq_extract_state()

        {:noreply, [], new_state}
      end

      def handle_info({:xrmq_connection, {:closed, _}}, state) do
        # WE WILL CONTINUE HANDLING THIS EVENT WHEN WE HANDLE THE CHANNEL DOWN EVENT

        {:noreply, [], state}
      end

      def handle_info({:DOWN, ref, :process, pid, reason}, state) do
        case State.get_channel_info() do
          {_, ^ref} ->
            State.set_channel_info(nil, nil)

            new_state =
              state
              |> xrmq_open_channel_consume()
              |> xrmq_extract_state()

            {:noreply, [], new_state}

          _ ->
            send(self(), {{:DOWN, ref, :process, pid, reason}})

            {:noreply, [], state}
        end
      end
    end
  end
end
