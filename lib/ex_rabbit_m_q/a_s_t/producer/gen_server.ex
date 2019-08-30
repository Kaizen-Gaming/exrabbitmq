defmodule ExRabbitMQ.AST.Producer.GenServer do
  @moduledoc """
  AST holding module for the producer behaviour when the surrounding producer is a GenServer.
  """

  @doc """
  Produces part of the AST for the producer behaviour when the producer is a GenServer.
  It holds GenServer handle_info callbacks.
  It responds to connection and channel events, trying to keep a channel open when a connection is available.
  """
  def ast do
    quote location: :keep do
      alias ExRabbitMQ.State, as: XRMQState

      @impl true
      def handle_info({:xrmq_connection, {:new, connection}}, state) do
        state = xrmq_on_connection_opened(connection, state)

        {:noreply, state}
      end

      @impl true
      def handle_info({:xrmq_connection, {:open, connection}}, state) do
        case xrmq_open_channel_setup(state) do
          {:ok, state} ->
            state = xrmq_on_connection_reopened(connection, state)
            state = xrmq_flush_buffered_messages(state)

            {:noreply, state}

          {:error, reason, state} ->
            {:stop, reason, state}
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

            new_state =
              state
              |> xrmq_open_channel_setup()
              |> xrmq_extract_state()

            {:noreply, new_state}

          _ ->
            send(self(), {{:DOWN, ref, :process, pid, reason}})

            {:noreply, state}
        end
      end

      @impl true
      def handle_info({:xrmq_try_init, opts}, state), do: xrmq_try_init_producer(opts, state)

      @impl true
      def handle_continue({:xrmq_try_init, opts, continuation}, state) do
        case xrmq_try_init_producer(opts, state) do
          result when continuation === nil -> result
          {action, state} -> {action, state, continuation}
          error -> error
        end
      end
    end
  end
end
