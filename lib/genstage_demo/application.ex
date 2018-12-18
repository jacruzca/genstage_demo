defmodule GenstageDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @producer_suffix "_prod"
  @consumer_suffix "_cons"

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    # List all child processes to be supervised
    queue1 = Application.get_env(:genstage_demo, :queue1)
    queue2 = Application.get_env(:genstage_demo, :queue2)

    children = [
      # Starts a worker by calling: GenstageDemo.Worker.start_link(arg)
      # {GenstageDemo.Worker, arg},
      worker(GenstageDemo.Standard.Producer, [%{queue_name: queue1, processes: 0}],
        id: String.to_atom(queue1 <> @producer_suffix)
      ),
      worker(GenstageDemo.Standard.Producer, [%{queue_name: queue2, processes: 0}],
        id: String.to_atom(queue2 <> @producer_suffix)
      ),
      # {GenstageDemo.Standard.EventEmitter, queue_name},
      # need to send queue name to consumer so we can delete events
      # {GenstageDemo.Standard.Consumer, queue_name}
      worker(GenstageDemo.Standard.ConsumerSupervisor, [queue1],
        id: String.to_atom(queue1 <> @consumer_suffix)
      ),
      worker(GenstageDemo.Standard.ConsumerSupervisor, [queue2],
        id: String.to_atom(queue2 <> @consumer_suffix)
      )
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GenstageDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
