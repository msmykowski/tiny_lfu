defmodule TinyLfu.Windows do
  defstruct [:windows, :current_window]

  alias TinyLfu.Windows.Window

  def new(opts) do
    window_opts = Keyword.fetch!(opts, :window_opts)
    number_of_windows = 3

    windows = Enum.map(1..number_of_windows, fn _ -> Window.new(window_opts) end)

    %__MODULE__{
      current_window: :counters.new(1, []),
      windows: windows
    }
  end

  def increment_current_window(windows) do
    current_window = current_window(windows)
    Window.increment(current_window)

    if Window.full?(current_window), do: rotate(windows)
  end

  def put_in_current_window(windows, key) do
    current_window = current_window(windows)

    Window.put(current_window, key)
  end

  def get_current_window_count(windows, key) do
    previous_count =
      windows
      |> previous_window()
      |> Window.count(key)
      |> halve()

    current_count =
      windows
      |> current_window()
      |> Window.count(key)

    previous_count + current_count
  end

  def get_min_count(windows) do
    windows
    |> current_window()
    |> Window.min_count()
  end

  def rotate(windows) do
    number_of_windows = length(windows.windows)
    current_window = current_window(windows)

    prepare_new_window_initial_state = fn ->
      min_count =
        current_window
        |> Window.min_count()
        |> halve()

      windows
      |> next_window()
      |> Window.set_state(%{min_count: min_count})
    end

    point_to_new_window = fn ->
      if :counters.get(windows.current_window, 1) >= number_of_windows - 1 do
        :counters.put(windows.current_window, 1, 0)
      else
        :counters.add(windows.current_window, 1, 1)
      end
    end

    refresh_window = fn ->
      windows
      |> window_to_refresh()
      |> Window.refresh()
    end

    prepare_new_window_initial_state.()
    point_to_new_window.()
    refresh_window.()
  end

  defp current_window(windows) do
    Enum.at(windows.windows, :counters.get(windows.current_window, 1))
  end

  defp previous_window(windows) do
    Enum.at(windows.windows, :counters.get(windows.current_window, 1) - 1)
  end

  defp next_window(windows) do
    Enum.at(
      windows.windows,
      :counters.get(windows.current_window, 1) + 1 - length(windows.windows)
    )
  end

  defp window_to_refresh(windows) do
    Enum.at(windows.windows, :counters.get(windows.current_window, 1) - 2)
  end

  defp halve(0), do: 0
  defp halve(number), do: trunc(number / 2)
end
