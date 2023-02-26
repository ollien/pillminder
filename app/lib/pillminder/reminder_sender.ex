defmodule Pillminder.ReminderSender do
  @moduledoc """
  The ReminderSender handles sending medication reminders evenly spaced reminders, such as every few minutes. It manages
  many SendServers, one for each reminder.
  """

  alias Pillminder.ReminderSender.TimerManager
  alias Pillminder.ReminderSender.SendServer
  use Supervisor

  @type sender_id :: String.t()
  @type senders :: %{sender_id => SendServer.remind_func()}

  @registry_name __MODULE__.Registry
  @task_supervisor_name __MODULE__.TaskSupervisor

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
    call_send_server(timer_id, fn destination ->
      send_server_opts = Keyword.put(opts, :server_name, destination)
      SendServer.send_reminder_on_interval(interval, send_server_opts)
    end)
  end

  @doc """
    Call the reminder every interval milliseconds. An error is returned if there is no timer currently running,
    or the timer failed to cancel.
  """
  @spec dismiss(sender_id) :: :ok | {:error, :not_timing | any}
  def dismiss(timer_id) do
    call_send_server(timer_id, &SendServer.dismiss(server_name: &1))
  end

  @spec snooze(sender_id, non_neg_integer()) :: any
  def snooze(timer_id, snooze_time) do
    call_send_server(timer_id, &SendServer.snooze(snooze_time, server_name: &1))
  end

  @doc """
    Call the reminder func, with a given timeout in milliseconds. NOTE: the "ok" variant here is used to indicate
    that the function was successfully called. If your function returns an :error tuple, for instance, you may
    receive {:ok, {:error, some_error}}
  """
  @spec send_reminder(timer_id :: sender_id(), timeout: non_neg_integer | :infinity) ::
          {:ok, any} | {:error, any}
  def send_reminder(timer_id, opts \\ []) do
    call_send_server(timer_id, fn destination ->
      send_server_opts = Keyword.put(opts, :server_name, destination)
      SendServer.send_reminder(send_server_opts)
    end)
  end

  @doc """
    Get the current pid of the SendServer for the given pid. Given how this is supervised, this should not be relied
    upon for sending to the process consistently. This is really only exposed for testing
  """
  @spec _get_current_send_server_pid(sender_id) :: pid() | nil
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
        {TimerManager, nil},
        {Task.Supervisor, name: @task_supervisor_name}
      ] ++ send_servers

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec make_send_server_spec({sender_id, SendServer.remind_func()}) :: Supervisor.child_spec()
  defp make_send_server_spec({timer_id, remind_func}) do
    Supervisor.child_spec(
      {SendServer,
       {remind_func, @task_supervisor_name,
        sender_id: make_send_server_id(timer_id),
        server_opts: [name: make_send_server_via_tuple(timer_id)]}},
      id: make_send_server_id(timer_id)
    )
  end

  defp call_send_server(timer_id, call) do
    via_tuple = make_send_server_via_tuple(timer_id)

    try do
      call.(via_tuple)
    catch
      :exit, {:noproc, _} -> {:error, :no_timer}
    end
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
