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

      def handle_info({:xrmq_connection, {:open, connection}}, state) do
        state =
          state
          |> xrmq_open_channel_setup()
          |> xrmq_extract_state()

        state = xqrm_on_connection_open(connection, state)

        {:noreply, state}
      end

      def handle_info({:xrmq_connection, {:closed, _}}, state) do
        state = xqrm_on_connection_closed(state)

        # WE WILL CONTINUE HANDLING THIS EVENT WHEN WE HANDLE THE CHANNEL DOWN EVENT

        {:noreply, state}
      end

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
    end
  end
end
