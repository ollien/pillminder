defmodule PillminderTest.Stats do
  alias Pillminder.Stats

  # Cannot use async tests, as it's a limitation of the sqlite ecto adapter
  use ExUnit.Case
  doctest Pillminder.Stats

  setup_all do
    {:ok, _} = Application.ensure_all_started(:ecto)
    start_supervised!(Stats.Repo)
    # We can only do this after we start the repo
    Ecto.Adapters.SQL.Sandbox.mode(Stats.Repo, :manual)
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Stats.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Stats.Repo, {:shared, self()})

    # Start tzdata, as the test's Timex needs it. test.exs disables network calls for this.
    {:ok, _} = Application.ensure_all_started(:tzdata)
  end

  describe "last_taken_at" do
    test "returns nil if nothing was recorded" do
      {:ok, last_taken_at} = Stats.last_taken_at("test-pillminder")
      assert last_taken_at == nil
    end

    test "returns the only entry if one entry is recorded" do
      taken_time = ~U[2022-12-12 10:30:00Z]
      :ok = Stats.record_taken("test-pillminder", taken_time)
      {:ok, last_taken_at} = Stats.last_taken_at("test-pillminder")

      assert Timex.equal?(last_taken_at, taken_time)
    end

    test "does not get a taken time from another timer" do
      taken_time = ~U[2022-12-12 10:30:00Z]
      :ok = Stats.record_taken("test-pillminder", taken_time)
      {:ok, last_taken_at} = Stats.last_taken_at("someone-elses-pillminder")

      assert last_taken_at == nil
    end

    test "gets the latest time inserted if there are multiple" do
      latest_time = ~U[2022-12-12 10:30:00Z]
      :ok = Stats.record_taken("test-pillminder", ~U[2022-12-10 10:30:00Z])
      :ok = Stats.record_taken("test-pillminder", ~U[2022-12-11 10:30:00Z])
      :ok = Stats.record_taken("test-pillminder", latest_time)
      {:ok, last_taken_at} = Stats.last_taken_at("test-pillminder")
      assert Timex.equal?(last_taken_at, latest_time)
    end

    test "fails to insert two on the same day" do
      :ok = Stats.record_taken("test-pillminder", ~U[2022-12-10 10:30:00Z])
      {:error, _} = Stats.record_taken("test-pillminder", ~U[2022-12-10 10:32:00Z])
      # No explicit assertion, the pattern match will cover this
    end

    test "allows two on the same day if they're different pillminders" do
      :ok = Stats.record_taken("test-pillminder", ~U[2022-12-10 10:30:00Z])
      :ok = Stats.record_taken("another--pillminder", ~U[2022-12-10 10:32:00Z])
      # No explicit assertion, the pattern match will cover this
    end

    test "preserves timezone of fetched data" do
      utc_taken_at = ~U[2022-12-12 10:30:00Z]
      eastern_time = Timex.Timezone.get("America/New_York", utc_taken_at)
      taken_at = Timex.Timezone.convert(utc_taken_at, eastern_time)

      :ok = Stats.record_taken("test-pillminder", taken_at)
      {:ok, last_taken_at} = Stats.last_taken_at("test-pillminder")

      assert Timex.equal?(last_taken_at, taken_at)
    end
  end
end
