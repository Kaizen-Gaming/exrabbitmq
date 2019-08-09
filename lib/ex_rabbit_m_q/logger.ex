defmodule ExRabbitMQ.Logger do
  @moduledoc false

  defmacro debug(message, metadata \\ []) do
    logger_stub(:debug, [message, metadata])
  end

  defmacro info(message, metadata \\ []) do
    logger_stub(:info, [message, metadata])
  end

  defmacro warn(message, metadata \\ []) do
    logger_stub(:warn, [message, metadata])
  end

  defmacro error(message, metadata \\ []) do
    logger_stub(:error, [message, metadata])
  end

  defmacro flush() do
    logger_stub(:flush, [])
  end

  defp logger_stub(level, args) do
    quote do
      if ExRabbitMQ.Config.Environment.logging_enabled() do
        require Logger
        Logger.unquote(level)(unquote_splicing(args))
      end
    end
  end
end
