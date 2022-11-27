defmodule Pillminder.ReminderSender do
  @moduledoc """
  The ReminderSender handles sending mdeication reminders evenly spaced reminders, such as every few minutes.
  This is intended to handle a single user's reminders; in a multi-user setup, there will be more than one
  ReminderSender.
  """
  alias Pillminder.ReminderSender.TimerManager
  alias Pillminder.ReminderSender.SendServer
  use Supervisor

  @type sender_id :: String.t()
  @type senders :: %{sender_id => SendServer.remind_func()}

  @registry_name __MODULE__.Registry

  def start_link(senders) do
    Supervisor.start_link(__MODULE__, senders, name: __MODULE__)
  end

  @doc """
    Call the reminder every interval milliseconds. An error is returned if the calling interval could not
    be set up; the remind_func will not be called if this happens.
  """
  @spec send_reminder_on_interval(
          timer_id :: sender_id(),
          interval :: non_neg_integer | :infinity,
          opts :: [send_immediately: boolean]
        ) :: :ok | {:error, :already_timing | any}
  def send_reminder_on_interval(timer_id, interval, opts \\ []) do
    destination = make_send_server_via_tuple(timer_id)
    send_server_opts = Keyword.put(opts, :server_name, destination)

    SendServer.send_reminder_on_interval(interval, send_server_opts)
  end

  @doc """
    Call the reminder every interval milliseconds. An error is returned if there is no timer currently running,
    or the timer failed to cancel.
  """
  @spec dismiss(sender_id) :: :ok | {:error, :no_timer | any}
  def dismiss(timer_id) do
    destination = make_send_server_via_tuple(timer_id)
    SendServer.dismiss(server_name: destination)
  end

  @doc """
    Call the reminder func, with a given timeout in milliseconds. NOTE: the "ok" variant here is used to indicate
    that the function was successfully called. If your function returns an :error tuple, for instance, you may
    receive {:ok, {:error, some_error}}
  """
  @spec send_reminder(timer_id :: sender_id(), timeout: non_neg_integer | :infinity) ::
          {:ok, any} | {:error, any}
  def send_reminder(timer_id, opts \\ []) do
    destination = make_send_server_via_tuple(timer_id)
    send_server_opts = Keyword.put(opts, :server_name, destination)

    SendServer.send_reminder(send_server_opts)
  end

  @doc """
    Get the current pid of the SendServer for the given pid. Given how this is supervised, this should not be relied
    upon for sending to the process consistently. This is really only exposed for testing
  """
  @spec _get_current_send_server_pid(timer_id :: sender_id()) :: pid() | nil
  def _get_current_send_server_pid(timer_id) do
    send_server_id = make_send_server_id(timer_id)

    case Registry.lookup(@registry_name, send_server_id) do
      [] -> nil
      [{pid, _value}] -> pid
    end
  end

  def init(senders) do
    send_servers = Enum.map(senders, &make_send_server_spec/1)

    children =
      [
        {Registry, keys: :unique, name: @registry_name},
        {TimerManager, nil}
      ] ++ send_servers

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec make_send_server_spec({sender_id, SendServer.remind_func()}) :: Supervisor.child_spec()
  defp make_send_server_spec({timer_id, remind_func}) do
    Supervisor.child_spec(
      {SendServer,
       {remind_func,
        sender_id: make_send_server_id(timer_id),
        server_opts: [name: make_send_server_via_tuple(timer_id)]}},
      id: make_send_server_id(timer_id)
    )
  end

  @spec make_send_server_via_tuple(sender_id) :: {:via, module(), {term(), String.t()}}
  defp make_send_server_via_tuple(timer_id) do
    {:via, Registry, {@registry_name, make_send_server_id(timer_id)}}
  end

  @spec make_send_server_id(sender_id) :: String.t()
  defp make_send_server_id(name) do
    "SendServer:#{name}"
  end
end
