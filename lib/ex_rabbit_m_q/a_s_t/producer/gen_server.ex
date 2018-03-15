defmodule ExRabbitMQ.AST.Producer.GenServer do
  @moduledoc false
  # @moduledoc """
  # AST holding module for the producer behaviour when the surrounding producer is a GenServer.
  # """

  @doc """
  Produces part of the AST for the producer behaviour when the producer is a GenServer.

  It holds GenServer handle_info callbacks.

  It responds to connection and channel events, trying to keep a channel open when a connection is available.
  """
  def ast() do
    quote location: :keep do
      def handle_info({:xrmq_connection, {:open, connection}}, state) do
        new_state =
          state
          |> xrmq_open_channel()
          |> xrmq_extract_state()

        {:noreply, new_state}
      end

      def handle_info({:xrmq_connection, {:closed, _}}, state) do
        # WE WILL CONTINUE HANDLING THIS EVENT WHEN WE HANDLE THE CHANNEL DOWN EVENT

        {:noreply, state}
      end

      def handle_info({:DOWN, ref, :process, pid, reason}, state) do
        case xrmq_get_channel_info() do
          {_, ^ref} ->
            xrmq_set_channel_info(nil, nil)

            new_state =
              state
              |> xrmq_open_channel()
              |> xrmq_extract_state()

            {:noreply, new_state}

          _ ->
            handle_info({{:DOWN, ref, :process, pid, reason}}, state)
        end
      end
    end
  end
end
