# ExRabbitMQ

A project providing the following abstractions:

1. Connection lifecycle handling
2. Channel lifecycle handling
3. A consumer behaviour for consuming from a RabbitMQ queue
4. A producer behaviour for publishing messages to a RabbitMQ queue

The goal of the project are:

1. Make it unnecessary for the programmer to directly handle connections and channels
2. Reduce the boilerplate when creating new projects that interact with RabbitMQ

As such, hooks are provided to enable the programmer to handle message delivery, cancellation, acknowlegement, rejection
as well as publishing.

For more information on implementing a consumer, see the documentation of the `ExRabbitMQ.Consumer` behaviour.

For more information on implementing a producer, see the documentation of the `ExRabbitMQ.Producer` behaviour.

## Installation

1. Add `{:exrabbitmq, "~> X.Y"}` ([https://hex.pm/packages/exrabbitmq](https://hex.pm/packages/exrabbitmq)) in your project's `deps` function in `mix.exs`
2. Run `mix deps.get` and `mix compile` in your project's root directory to download and compile the package

## Documentation

1. Run `mix deps.get`, `mix compile` and `mix docs` in `:exrabbitmq`'s root directory
2. Serve the `doc` folder in `:exrabbitmq`'s root directory with a web server