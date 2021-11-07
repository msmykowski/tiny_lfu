defmodule TinyLfu.Windows do
  defstruct [:windows, :current_window]

  alias TinyLfu.Windows.Window

  def new(opts) do
    window_opts = Keyword.fetch!(opts, :window_opts)
    number_of_windows = 3

    windows =
      Enum.map(1..number_of_windows, fn index ->
        window_opts = Keyword.put(window_opts, :index, index)
        Window.new(window_opts)
      end)

    %__MODULE__{
      current_window: :counters.new(1, []),
      windows: windows
    }
  end

  def get_current_window(windows) do
    current_window = current_window(windows)
    window_size = Window.increment(current_window)

    if window_size == Window.limit(current_window), do: rotate(windows), else: current_window
  end

  def put_in_window(windows, key, window \\ nil) do
    window = window || current_window(windows)

    Window.put(window, key)
  end

  def get_window_count(windows, key, window \\ nil) do
    window = window || current_window(windows)

    previous_count =
      windows
      |> previous_window(window)
      |> Window.count(key)
      |> halve()

    current_count = Window.count(window, key)

    previous_count + current_count
  end

  def get_min_count(windows, window \\ nil) do
    window = window || current_window(windows)
    Window.min_count(window)
  end

  def rotate(windows) do
    number_of_windows = length(windows.windows)
    current_window = current_window(windows)
    next_window = next_window(windows, current_window)

    prepare_new_window_initial_state = fn ->
      min_count =
        current_window
        |> Window.min_count()
        |> halve()

      Window.set_state(next_window, %{min_count: min_count})

      :ok
    end

    point_to_new_window = fn ->
      if :counters.get(windows.current_window, 1) >= number_of_windows - 1 do
        :counters.put(windows.current_window, 1, 0)
      else
        :counters.add(windows.current_window, 1, 1)
      end

      :ok
    end

    refresh_window = fn ->
      windows
      |> window_to_refresh(current_window)
      |> Window.refresh()

      :ok
    end

    with :ok <- prepare_new_window_initial_state.(),
         :ok <- point_to_new_window.(),
         :ok <- refresh_window.() do
      next_window
    end
  end

  defp current_window(windows) do
    window_at(windows, :counters.get(windows.current_window, 1))
  end

  defp previous_window(windows, window) do
    window_at(windows, Window.index(window) - 1)
  end

  defp next_window(windows, window) do
    window_at(windows, Window.index(window) + 1 - length(windows.windows))
  end

  defp window_to_refresh(windows, window) do
    window_at(windows, Window.index(window) - 2)
  end

  defp window_at(windows, index) do
    Enum.at(windows.windows, index)
  end

  defp halve(0), do: 0
  defp halve(number), do: trunc(number / 2)
end
