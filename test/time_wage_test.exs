defmodule TimeWageTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  doctest TimeWage

  setup do
    HTTPoison.start()
    ExVCR.Config.cassette_library_dir("fixture/vcr_cassettes")

    ExVCR.Config.filter_sensitive_data(
      Application.get_env(:time_wage, :todoist_token),
      "TODOIST_TOKEN"
    )

    :ok
  end

  test "greets the world" do
    use_cassette "todoist" do
      completes =
        TimeWage.get_todoist_completes()
        |> Enum.filter(fn item -> TimeWage.completed_today?(item, ~D[2018-06-09]) end)
        |> Enum.count()

      assert completes == 2
    end
  end
end
