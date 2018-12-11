defmodule GenstageDemo.Producer do
  use GenStage
  import Logger

  def start_link(state) do
    GenStage.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    {:producer, state}
  end

  def handle_info(:check_messages, %{processes: 0} = state), do: {:noreply, [], state}

  def handle_info(:check_messages, %{queue_name: queue_name, processes: processes} = state) do
    Logger.debug("Reading from SQS... got #{processes} workers ready")

    messages = get_messages(queue_name, processes)

    Logger.debug("Messages #{length(messages)}")

    Process.send(self(), :check_messages, [])

    state = %{state | processes: processes - Enum.count(messages)}
    {:noreply, messages, state}
  end

  def handle_demand(demand, %{processes: processes} = state) do
    IO.puts("Handling downstream demand (#{demand}) for messages")
    send(self(), :check_messages)
    state = %{state | processes: demand + processes}
    {:noreply, [], state}
  end

  defp get_messages(queue_name, max) do
    response =
      ExAws.SQS.receive_message(queue_name, max_number_of_messages: max) |> ExAws.request!()

    %{body: %{messages: messages}} = response
    messages
  end
end
