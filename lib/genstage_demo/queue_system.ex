defmodule GenstageDemo.QueueSystem do
  import Logger

  @sqs_protocol "sqs"
  @url_ending ".amazonaws.com/"

  @doc """
  This function executes the following steps:
  * It creates a SNS topic with the given `topic_name`
  * It creates a SQS queue with the given `queue_name`
  * It retrieves the queue attributes in order to obtain the queue ARN
  * It creates a subscription of the SQS queue to the SNS topic
  * It adds the `SendMessage` permission to the sqs queue

  Once the subscription was successfuly created, when the SNS topic receives a message,
  the message will be broadcasted to all subscribed queues.

  ## Parameters:

    * `topic_name` - the name of the SNS topic to be created
    * `queue_name` - the name of the SQS standard queue to be created
  """
  @spec create_topic_and_queue(topic_name :: binary, queue_name :: binary) ::
          {:ok, any()} | {:error, any()}
  def create_topic_and_queue(topic_name, queue_name) do
    with {:ok, %{body: %{topic_arn: topic_arn} = topic}} <- create_topic(topic_name),
         {:ok, %{body: %{queue_url: queue_url}}} <- create_queue(queue_name),
         {:ok, stripped_queue_url} <- get_stripped_queue_url(queue_url),
         {:ok, %{body: %{attributes: %{queue_arn: queue_arn}}}} <-
           get_queue_attributes(queue_name),
         {:ok, %{body: subscription}} <- subscribe_queue_to_topic(topic_arn, queue_arn),
         {:ok, _} <- add_send_message_permission(stripped_queue_url, queue_arn, topic_arn) do
      {:ok,
       %{
         topic: topic,
         queue: %{queue_url: queue_url, queue_arn: queue_arn},
         subscription: subscription
       }}
    else
      error -> error
    end
  end

  @doc """
  Adds the `SendMessage` permission to a SQS queue

  ## Parameters:

  * `queue_url` - The stripped queue url we're giving permissions to. Example: `068000098326/test2``
  * `queue_arn` - The ARN of the queue we're giving permissions to. Example: `arn:aws:sqs:us-west-2:068000098326:test2`
  * `topic_arn` - The ARN of the SNS topic we're giving permissions from. Example: `arn:aws:sns:us-west-2:068000098326:test2`
  """
  @spec add_send_message_permission(binary(), any(), any()) :: {:error, any()} | {:ok, any()}
  def add_send_message_permission(queue_url, queue_arn, topic_arn) do
    policy = """
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "AWS": "*"
          },
          "Action": "SQS:SendMessage",
          "Resource": "#{queue_arn}",
          "Condition": {
            "ArnEquals": {
              "aws:SourceArn": "#{topic_arn}"
            }
          }
        }
      ]
    }
    """

    ExAws.SQS.set_queue_attributes(queue_url, policy: policy) |> ExAws.request()
  end

  @doc """
  Creates a new SNS topic. If a topic with the same `topic_name` is already created, it will be returned and
  a new one won't be created.
  """
  @spec create_topic(topic_name :: binary()) :: {:error, any()} | {:ok, any()}
  def create_topic(topic_name) do
    ExAws.SNS.create_topic(topic_name) |> ExAws.request()
  end

  @doc """
  Creates a new SQS queue. If a queue with the same `queue_name` is already created, it will be returned and
  a new one won't be created.
  """
  @spec create_queue(queue_name :: binary()) :: {:error, any()} | {:ok, any()}
  def create_queue(queue_name) do
    ExAws.SQS.create_queue(queue_name, receive_message_wait_time_seconds: 20) |> ExAws.request()
  end

  @doc """
  Returns the attributes of a queue.
  """
  @spec get_queue_attributes(queue_name :: binary()) :: {:error, any()} | {:ok, any()}
  def get_queue_attributes(queue_name) do
    ExAws.SQS.get_queue_attributes(queue_name) |> ExAws.request()
  end

  @doc """
  Subscribes the given SQS queue to the topic

  ## Parameters:

    * `topic_arn` - The AWS ARN of the topic
    * `queue_arn` - The AWS ARN of the queue
  """
  @spec subscribe_queue_to_topic(binary(), binary()) :: {:error, any()} | {:ok, any()}
  def subscribe_queue_to_topic(topic_arn, queue_arn) do
    ExAws.SNS.subscribe(topic_arn, @sqs_protocol, queue_arn) |> ExAws.request()
  end

  @doc """
  Gets the messages of the given SQS queue

  Returns an array of messages if any. Otherwise an empty array is returned ([])
  """
  @spec get_messages(
          queue_name :: binary(),
          max_number_of_messages :: 1..10,
          wait_time_seconds :: 0..20
        ) :: any()
  @spec get_messages(
          queue_name :: binary(),
          max_number_of_messages :: 1..10
        ) :: any()
  def get_messages(queue_name, max_number_of_messages, wait_time_seconds \\ 10) do
    response =
      ExAws.SQS.receive_message(queue_name,
        max_number_of_messages: max_number_of_messages,
        wait_time_seconds: wait_time_seconds
      )
      |> ExAws.request!()

    %{body: %{messages: messages}} = response
    messages
  end

  @doc """
  Publishes a message to a SNS topic

  ## Parameters:

  * `subject` - The subject of the message
  * `message` - The message
  * `topic_name` - The name of the topic. If it does not exists, it will be created
  """
  @spec publish_message(any(), any(), binary()) :: {:error, any()} | {:ok, any()}
  def publish_message(subject, message, topic_name) do
    with {:ok, %{body: %{topic_arn: topic_arn}}} <- create_topic(topic_name) do
      ExAws.SNS.publish(message, subject: subject, topic_arn: topic_arn) |> ExAws.request()
    else
      error -> error
    end
  end

  defp get_stripped_queue_url(queue_url) do
    [_ | stripped_queue_url] = String.split(queue_url, @url_ending)
    Logger.debug(stripped_queue_url)
    {:ok, List.first(stripped_queue_url)}
  end
end
