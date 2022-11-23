defmodule Pillminder.WebRouter do
  require Logger
  alias Pillminder.ReminderSender

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  delete "/timer/:timer_id" do
    with {:ok, pid} <- get_pid_for_timer_id(timer_id),
         :ok <- ReminderSender.dismiss(server_name: pid) do
      Logger.info("Cleared timer id #{timer_id}")
      send_resp(conn, 200, "")
    else
      {:error, :no_servers} ->
        Logger.info(
          "Attempted to dismiss timer id #{timer_id} but no corresponding reminder sender was found"
        )

        send_resp(conn, 404, "")

      {:error, :multiple_servers} ->
        # This is a violation of the expected state; we could crash, but I'd prefer to log it explicitly.
        Logger.error(
          "Multiple servers are registered for #{timer_id};  not notifying any of them"
        )

        send_resp(conn, 500, "")

      {:error, :no_timer} ->
        Logger.debug("Attempted to dismiss timer id #{timer_id} but no timers are running")
        send_resp(conn, 200, "")

      {:error, err} ->
        Logger.error("Failed to dismiss timer with id #{timer_id}: #{inspect(err)}")
        send_resp(conn, 500, "")
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end

  @spec get_pid_for_timer_id(String.t()) :: {:ok, pid} | {:error, :no_servers | :multiple_servers}
  defp get_pid_for_timer_id(timer_id) do
    entries =
      Registry.lookup(
        Pillminder.Application.reminder_sender_registry(),
        Pillminder.Application.make_reminder_sender_id(timer_id)
      )

    case entries do
      [entry] ->
        {pid, _} = entry
        {:ok, pid}

      [] ->
        {:error, :no_servers}

      [_head | _rest] ->
        {:error, :multiple_servers}
    end
  end
end
