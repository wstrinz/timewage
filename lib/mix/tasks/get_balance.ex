defmodule Mix.Tasks.GetBalance do
  use Mix.Task

  @shortdoc "Get Time balance"
  def run(_) do
    TimeWage.run()
  end
end
