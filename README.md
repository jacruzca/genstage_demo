# GenstageDemo

Demo Application for demonstrating use of `GenStage` with Amazon SQS. It's a mix of these 2 approaches:

- https://github.com/andyleclair/genstage_demo
- https://labs.uswitch.com/genstage-for-continuous-job-processing/

## Installation

```
mix deps.get
iex -S mix
```

Create the following environment variables:

- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

In order to receive events from the queue, either create a queue with name `test` using AWS console or change the `queue_name` in `config.exs`. Queue must be a standard queue. For this to work with FIFO queues you'd need to change the code

## Walkthrough

- `application.ex` describes the main Application behaviour that starts our GenStage process.
- `producer.ex` is a basic GenStage producer. It responds to demand from workers by fetching messages from SQS in batches of 10 or less
- `consumer.ex` is a basic GenStage consumer. It receives asks for messages from the producer and prints them to the console, then deletes the message from SQS
- `event_emitter.ex` is a GenServer that writes a message to SQS once per second with a body of just the system time in millis
- `consumer_supervisor.ex` is a GenStage ConsumerSupervisor. It sends demand upstream to the Producer and spawns a Printer process for each message it receives
- `printer.ex` is a simple message processor that prints a message, then deletes it from SQS.
