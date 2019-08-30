defmodule ExRabbitMQ do
  @version Mix.Project.config()[:version]
           |> Version.parse()
           |> elem(1)
           |> Map.take([:major, :minor])
           |> (fn %{major: major, minor: minor} -> "#{major}.#{minor}" end).()

  @moduledoc """
  A project providing the following abstractions:

  1. Connection lifecycle handling
  2. Channel lifecycle handling
  3. A consumer behaviour for consuming from a RabbitMQ queue
  4. A producer behaviour for publishing messages to a RabbitMQ queue

  The goal of the project are:

  1. Make it unnecessary for the programmer to directly handle connections and channels
  2. Reduce the boilerplate when creating new projects that interact with RabbitMQ

  As such, hooks are provided to enable the programmer to handle message delivery, cancellation, acknowlegement,
  rejection as well as publishing.

  For more information on implementing a consumer, see the documentation of the `ExRabbitMQ.Consumer` behaviour.

  For more information on implementing a producer, see the documentation of the `ExRabbitMQ.Producer` behaviour.

  ## Installation

  1. Add `{:exrabbitmq, "~> #{@version}"}` ([https://hex.pm/packages/exrabbitmq](https://hex.pm/packages/exrabbitmq))
     in your project's `deps` function in `mix.exs`
  2. Run `mix deps.get` and `mix compile` in your project's root directory to download and compile the package

  ## Documentation

  1. Run `mix deps.get`, `mix compile` and `mix docs` in `:exrabbitmq`'s root directory
  2. Serve the `doc` folder in `:exrabbitmq`'s root directory with a web server
  """

  alias ExRabbitMQ.Config.Utils, as: XRMQConfigUtils

  # logging

  defdelegate logging_set?(), to: XRMQConfigUtils
  defdelegate enable_logging(), to: XRMQConfigUtils
  defdelegate disable_logging(), to: XRMQConfigUtils

  # accounting

  defdelegate accounting_set?(), to: XRMQConfigUtils
  defdelegate enable_accounting(), to: XRMQConfigUtils
  defdelegate disable_accounting(), to: XRMQConfigUtils

  # message buffering

  defdelegate message_buffering_set?(), to: XRMQConfigUtils
  defdelegate enable_message_buffering(), to: XRMQConfigUtils
  defdelegate disable_message_buffering(), to: XRMQConfigUtils

  # try_init interval

  defdelegate get_try_init_interval(), to: XRMQConfigUtils
  defdelegate set_try_init_interval(interval), to: XRMQConfigUtils

  # KBs of messages seen so far threshold

  defdelegate get_kb_of_messages_seen_so_far_threshold(), to: XRMQConfigUtils
  defdelegate set_kb_of_messages_seen_so_far_threshold(threshold), to: XRMQConfigUtils

  # continue_tuple_try_init

  defdelegate continue_tuple_try_init(
                connection_config,
                session_config,
                auto_consume,
                continuation
              ),
              to: XRMQConfigUtils

  defdelegate continue_tuple_try_init(connection_config, session_config, continuation),
    to: XRMQConfigUtils
end
