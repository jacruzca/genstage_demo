defmodule GenstageDemo.Standard.ConsumerSupervisor do
  use ConsumerSupervisor

  def start_link(queue_name) do
    ConsumerSupervisor.start_link(__MODULE__, queue_name)
  end

  def init(queue_name) do
    children = [
      worker(GenstageDemo.Printer, [queue_name], restart: :temporary)
    ]

    {:ok, children,
     strategy: :one_for_one,
     subscribe_to: [{String.to_atom(queue_name), max_demand: 10, min_demand: 1}]}
  end
end
