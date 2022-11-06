defmodule Pillminder.ReminderServer do
  use GenServer

  @type state :: %{remind_func: function}

  @spec start_link(function, keyword) :: {:error, any} | {:ok, pid} | {:error, any} | :ignore
  def start_link(remind_func, opts \\ []) do
    full_opts = Keyword.merge([name: __MODULE__], opts)
    GenServer.start_link(__MODULE__, remind_func, full_opts)
  end

  def send_reminder(timeout \\ 5000) do
    GenServer.call(__MODULE__, :remind, timeout)
  end

  @impl true
  @spec init(function) :: {:ok, state}
  def init(remind_func) do
    {:ok, %{remind_func: remind_func}}
  end

  @impl true
  @spec handle_call(:remind, {pid, term}, state) :: {:reply, :ok, state}
  def handle_call(:remind, _from, state) do
    ret = state.remind_func.()
    {:reply, ret, state}
  end
end
