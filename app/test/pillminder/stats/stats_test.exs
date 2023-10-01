defmodule PillminderTest.Stats do
  alias Pillminder.Stats

  # Cannot use async tests, as it's a limitation of the sqlite ecto adapter
  use ExUnit.Case
  doctest Pillminder.Stats

  setup_all do
    {:ok, _} = Application.ensure_all_started(:ecto)
    configure_tmpfile_repo(Stats.Repo)
    start_supervised!(Stats.Repo)
    run_migrations()

    # We can only do this after we start the repo
    Ecto.Adapters.SQL.Sandbox.mode(Stats.Repo, :manual)
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Stats.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Stats.Repo, {:shared, self()})

    :ok
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

    test "strips microseconds when recording time" do
      taken_time = ~U[2022-12-12 10:30:00.500Z]
      :ok = Stats.record_taken("test-pillminder", taken_time)
      {:ok, last_taken_at} = Stats.last_taken_at("test-pillminder")

      assert Timex.equal?(last_taken_at, ~U[2022-12-12 10:30:00Z])
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

      {:error, :already_taken_today} =
        Stats.record_taken("test-pillminder", ~U[2022-12-10 10:32:00Z])

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

  describe "streak length" do
    test "a timer with no entries give zero streak" do
      {:ok, streak_length} = Stats.streak_length("test-pillminder")
      assert streak_length == 0
    end

    test "a timer with no entries give zero streak and a date provided" do
      {:ok, streak_length} = Stats.streak_length("test-pillminder", ~D[2022-12-10])
      assert streak_length == 0
    end

    test "a timer with an entry gives one streak" do
      taken_at = ~U[2022-12-10 10:32:00Z]
      :ok = Stats.record_taken("test-pillminder", taken_at)
      {:ok, streak_length} = Stats.streak_length("test-pillminder")

      assert streak_length == 1
    end

    test "a streak with no gap gives the length" do
      taken_ats = [
        ~U[2022-12-10 10:32:00Z],
        ~U[2022-12-09 10:32:00Z],
        ~U[2022-12-08 10:32:00Z],
        ~U[2022-12-07 10:32:00Z]
      ]

      taken_ats
      |> Enum.each(fn taken_at ->
        :ok =
          Stats.record_taken(
            "test-pillminder",
            taken_at
          )
      end)

      {:ok, streak_length} = Stats.streak_length("test-pillminder")

      assert streak_length == 4
    end

    test "the streak should not break if the UTC date is on different days" do
      taken_ats = [
        # These second and third are on the same day in UTC, but are on different days to a user
        Timex.to_datetime({{2023, 9, 25}, {15, 0, 5}}, "America/New_York"),
        Timex.to_datetime({{2023, 9, 26}, {22, 46, 44}}, "America/New_York"),
        Timex.to_datetime({{2023, 9, 27}, {15, 2, 4}}, "America/New_York"),
        Timex.to_datetime({{2023, 9, 28}, {15, 0, 38}}, "America/New_York")
      ]

      taken_ats
      |> Enum.each(fn taken_at ->
        :ok =
          Stats.record_taken(
            "test-pillminder",
            taken_at
          )
      end)

      {:ok, streak_length} = Stats.streak_length("test-pillminder")

      assert streak_length == 4
    end

    test "the streak should not break if the UTC date is on different days, with the streak boundary being that date" do
      taken_ats = [
        # These second and third are on the same day in UTC, but are on different days to a user
        Timex.to_datetime({{2023, 9, 24}, {15, 0, 5}}, "America/New_York"),
        Timex.to_datetime({{2023, 9, 26}, {22, 46, 44}}, "America/New_York"),
        Timex.to_datetime({{2023, 9, 27}, {15, 2, 4}}, "America/New_York"),
        Timex.to_datetime({{2023, 9, 28}, {15, 0, 38}}, "America/New_York"),
        Timex.to_datetime({{2023, 9, 29}, {13, 48, 43}}, "America/New_York"),
        Timex.to_datetime({{2023, 9, 30}, {13, 26, 08}}, "America/New_York")
      ]

      taken_ats
      |> Enum.each(fn taken_at ->
        :ok =
          Stats.record_taken(
            "test-pillminder",
            taken_at
          )
      end)

      {:ok, streak_length} = Stats.streak_length("test-pillminder")

      assert streak_length == 5
    end

    test "taking medication the next day (even if more than 24h) keeps a streak" do
      taken_ats = [
        ~U[2022-12-07 02:32:00Z],
        ~U[2022-12-08 04:32:00Z],
        ~U[2022-12-09 10:32:00Z],
        ~U[2022-12-10 15:32:00Z]
      ]

      taken_ats
      |> Enum.each(fn taken_at ->
        :ok =
          Stats.record_taken(
            "test-pillminder",
            taken_at
          )
      end)

      {:ok, streak_length} = Stats.streak_length("test-pillminder")

      assert streak_length == 4
    end

    test "taking medication with a gap day but less than 48h apart breaks the streak" do
      taken_ats = [
        ~U[2023-07-07 17:33:00Z],
        ~U[2023-07-08 17:33:00Z],
        ~U[2023-07-09 19:33:00Z],
        ~U[2023-07-11 15:33:00Z]
      ]

      taken_ats
      |> Enum.each(fn taken_at ->
        :ok =
          Stats.record_taken(
            "test-pillminder",
            taken_at
          )
      end)

      {:ok, streak_length} = Stats.streak_length("test-pillminder")

      assert streak_length == 1
    end

    test "two entries less than 24 hours apart still count as a streak of two" do
      taken_ats = [
        ~U[2023-08-14 21:04:00Z],
        ~U[2023-08-21 20:04:00Z],
        ~U[2023-08-22 16:31:00Z]
      ]

      taken_ats
      |> Enum.each(fn taken_at ->
        :ok =
          Stats.record_taken(
            "test-pillminder",
            taken_at
          )
      end)

      {:ok, streak_length} = Stats.streak_length("test-pillminder")

      assert streak_length == 2
    end

    test "three entries, fewer than 24 hours apart from each other, will count as a streak of three" do
      taken_ats = [
        ~U[2023-08-14 21:04:00Z],
        ~U[2023-08-21 20:04:00Z],
        ~U[2023-08-22 16:31:00Z],
        ~U[2023-08-23 09:31:00Z]
      ]

      taken_ats
      |> Enum.each(fn taken_at ->
        :ok =
          Stats.record_taken(
            "test-pillminder",
            taken_at
          )
      end)

      {:ok, streak_length} = Stats.streak_length("test-pillminder")

      assert streak_length == 3
    end

    test "a gap in the streak produces the number of days after the gap" do
      base_taken_at = ~U[2022-12-10 10:32:00Z]

      taken_ats = [
        base_taken_at,
        base_taken_at |> Timex.subtract(Timex.Duration.from_days(1)),
        base_taken_at |> Timex.subtract(Timex.Duration.from_days(3))
      ]

      taken_ats
      |> Enum.each(fn taken_at ->
        :ok =
          Stats.record_taken(
            "test-pillminder",
            taken_at
          )
      end)

      {:ok, streak_length} = Stats.streak_length("test-pillminder")

      assert streak_length == 2
    end

    test "providing a date invalidates the streak if we've missed a day" do
      base_taken_at = ~U[2022-12-10 10:32:00Z]

      :ok =
        Stats.record_taken(
          "test-pillminder",
          base_taken_at
        )

      :ok =
        Stats.record_taken(
          "test-pillminder",
          base_taken_at |> Timex.subtract(Timex.Duration.from_days(1))
        )

      {:ok, streak_length} =
        Stats.streak_length(
          "test-pillminder",
          base_taken_at |> DateTime.to_date() |> Timex.add(Timex.Duration.from_days(2))
        )

      assert streak_length == 0
    end

    test "providing a date keeps the streak if it's the day after" do
      base_taken_at = ~U[2022-12-10 10:32:00Z]

      :ok =
        Stats.record_taken(
          "test-pillminder",
          base_taken_at
        )

      :ok =
        Stats.record_taken(
          "test-pillminder",
          base_taken_at |> Timex.subtract(Timex.Duration.from_days(1))
        )

      {:ok, streak_length} =
        Stats.streak_length(
          "test-pillminder",
          base_taken_at |> DateTime.to_date() |> Timex.add(Timex.Duration.from_days(1))
        )

      assert streak_length == 2
    end
  end

  describe "taken dates" do
    test "no entries returns the last n days as a map full of falses" do
      {:ok, log} = Stats.taken_dates("test-pillminder", ~D[2023-01-08], 5)

      assert log == %{
               ~D[2023-01-08] => false,
               ~D[2023-01-07] => false,
               ~D[2023-01-06] => false,
               ~D[2023-01-05] => false,
               ~D[2023-01-04] => false
             }
    end

    test "one entry yesterday is reflected in the map" do
      :ok =
        Stats.record_taken(
          "test-pillminder",
          ~U[2023-01-07 10:50:00Z]
        )

      {:ok, log} = Stats.taken_dates("test-pillminder", ~D[2023-01-08], 5)

      assert log == %{
               ~D[2023-01-08] => false,
               ~D[2023-01-07] => true,
               ~D[2023-01-06] => false,
               ~D[2023-01-05] => false,
               ~D[2023-01-04] => false
             }
    end

    test "several entries are reflected in the map" do
      base_taken_at = ~U[2023-01-08 10:50:00Z]

      taken_ats = [
        base_taken_at |> Timex.subtract(Timex.Duration.from_days(1)),
        base_taken_at |> Timex.subtract(Timex.Duration.from_days(3)),
        base_taken_at |> Timex.subtract(Timex.Duration.from_days(4))
      ]

      taken_ats
      |> Enum.each(fn taken_at ->
        :ok =
          Stats.record_taken(
            "test-pillminder",
            taken_at
          )
      end)

      {:ok, log} = Stats.taken_dates("test-pillminder", base_taken_at |> DateTime.to_date(), 5)

      assert log == %{
               ~D[2023-01-08] => false,
               ~D[2023-01-07] => true,
               ~D[2023-01-06] => false,
               ~D[2023-01-05] => true,
               ~D[2023-01-04] => true
             }
    end

    test "entries outside the date range are not reflected in the output" do
      base_taken_at = ~U[2023-01-08 10:50:00Z]

      taken_ats = [
        base_taken_at |> Timex.subtract(Timex.Duration.from_days(1)),
        base_taken_at |> Timex.subtract(Timex.Duration.from_days(8)),
        base_taken_at |> Timex.subtract(Timex.Duration.from_days(9)),
        base_taken_at |> Timex.subtract(Timex.Duration.from_days(10)),
        base_taken_at |> Timex.subtract(Timex.Duration.from_days(11))
      ]

      taken_ats
      |> Enum.each(fn taken_at ->
        :ok =
          Stats.record_taken(
            "test-pillminder",
            taken_at
          )
      end)

      {:ok, log} = Stats.taken_dates("test-pillminder", base_taken_at |> DateTime.to_date(), 3)

      assert log == %{
               ~D[2023-01-08] => false,
               ~D[2023-01-07] => true,
               ~D[2023-01-06] => false
             }
    end
  end

  defp configure_tmpfile_repo(repo) do
    {:ok, _} = Application.ensure_all_started(:briefly)

    db_file =
      Briefly.create!(prefix: "pillminderdb", directory: true)
      |> Path.join("pillminder.db")

    # This is a hack, but because briefly only lives for the lifetime of our process,
    # We cannot create a tmpfile in test.exs or runtime.exs
    repo_env =
      Application.get_env(:pillminder, repo)
      |> Keyword.put(:database, db_file)

    Application.put_env(:pillminder, repo, repo_env)
  end

  defp run_migrations() do
    Application.load(:pillminder)

    Application.fetch_env!(:pillminder, :ecto_repos)
    |> Enum.each(fn repo ->
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end)
  end
end
