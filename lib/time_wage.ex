defmodule TimeWage do
  def get_rescuetime_data do
    {{y, m, d}, _h} = :calendar.local_time()
    date = "#{y}-#{m}-#{d}"

    params = %{
      key: Application.get_env(:time_wage, :rescuetime_key),
      perspective: "interval",
      resolution_time: "day",
      restrict_begin: date,
      restrict_end: date,
      format: "json"
    }

    url = "https://www.rescuetime.com/anapi/data?#{URI.encode_query(params)}"
    %HTTPoison.Response{body: body} = HTTPoison.get!(url)

    body
    |> Poison.decode!()
    |> Map.fetch!("rows")
  end

  def get_distracted_minutes(data) do
    seconds =
      data
      |> Enum.filter(fn item -> Enum.at(item, -1) < 0 end)
      |> Enum.map(fn item -> Enum.at(item, 1) end)
      |> Enum.sum()

    seconds / 60
  end

  def get_todoist_completes do
    url =
      "https://todoist.com/API/v7/completed/get_all?token=#{
        Application.get_env(:time_wage, :todoist_token)
      }"

    %HTTPoison.Response{body: body} = HTTPoison.get!(url)

    Poison.decode!(body)
    |> Map.fetch!("items")
  end

  def completed_today?(item, today \\ nil) do
    date_string =
      item
      |> Map.fetch!("completed_date")

    date =
      Regex.replace(~r{ }, date_string, ", ", global: false)
      |> Timex.parse!("{RFC1123}")
      |> DateTime.to_date()

    if today do
      date == today
    else
      date == Timex.now("America/Chicago") |> DateTime.to_date()
    end
  end

  def todoist_completes_today do
    get_todoist_completes()
    |> Enum.filter(&completed_today?/1)
    |> Enum.count()
  end

  def copy_todays_db do
    File.cp!(
      Application.get_env(:time_wage, :todays_db_path),
      "data\\HabitTracker.sqlite"
    )
  end

  def extract_habit_progress_csv do
    {csv_string, _status} =
      System.cmd("C:\\bin\\sqlite3.exe", [
        "-header",
        "-csv",
        "data\\HabitTracker.sqlite",
        "select * from ZHABITPROGRESSENTRY;"
      ])

    {:ok, csv_stream} = StringIO.open(csv_string)

    CSV.decode!(IO.binstream(csv_stream, :line)) |> Enum.to_list()
  end

  def last_habit_checkin do
    extract_habit_progress_csv() |> Enum.at(-1)
  end

  def date_for_item(item) do
    item
    |> Enum.at(-2)
    |> String.to_integer()
  end

  def checked_today?(item) do
    # 6/9/18 == 550_213_201
    date_for_item(item) == 550_299_601
  end

  def todays_today do
    copy_todays_db()

    extract_habit_progress_csv()
    |> Enum.drop(1)
    |> Enum.filter(&checked_today?/1)
    |> Enum.count()
  end

  def make_request(url) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    :httpc.request(:get, {url, []}, [], [])
  end

  def get_time_budget do
    (todays_today() + todoist_completes_today()) * 15
  end

  def run do
    budget = get_time_budget() |> round()
    used = get_rescuetime_data() |> get_distracted_minutes() |> round()

    IO.puts("Total used: #{used}")
    IO.puts("Total allowed: #{budget}")
    IO.puts("Remaining: #{budget - used}")
  end
end
