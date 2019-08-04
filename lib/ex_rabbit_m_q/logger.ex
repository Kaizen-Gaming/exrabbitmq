defmodule ExRabbitMQ.Logger do
  @moduledoc false

  defmacro debug(message, metadata \\ []) do
    logger_stub(:debug, message, metadata)
  end

  defmacro info(message, metadata \\ []) do
    logger_stub(:info, message, metadata)
  end

  defmacro warn(message, metadata \\ []) do
    logger_stub(:warn, message, metadata)
  end

  defmacro error(message, metadata \\ []) do
    logger_stub(:error, message, metadata)
  end

  defp logger_stub(level, message, metadata) do
    quote do
      if ExRabbitMQ.Config.Environment.logging_enabled() do
        require Logger
        Logger.unquote(level)(unquote(message), unquote(metadata))
      end
    end
  end
end
