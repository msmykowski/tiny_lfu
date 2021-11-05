defmodule TinyLfu.Frequencies do
  defstruct [:max_cardinality, :limit, :windows, :frequency_counter, :current_window]

  alias Talan.CountingBloomFilter

  def new(opts) do
    limit = Keyword.fetch!(opts, :limit)
    max_cardinality = Keyword.fetch!(opts, :max_cardinality)
    max_frequency = Keyword.fetch!(opts, :max_frequency)
    number_of_windows = Keyword.get(opts, :number_of_windows, 3)

    windows =
      Enum.map(1..number_of_windows, fn _ ->
        CountingBloomFilter.new(max_cardinality, counters_bit_size: 16)
      end)

    %__MODULE__{
      current_window: :counters.new(1, []),
      frequency_counter: :counters.new(max_frequency, []),
      limit: limit,
      max_cardinality: max_cardinality,
      windows: windows
    }
  end

  def count(frequency, key) do
    previous_count =
      frequency
      |> previous_window()
      |> CountingBloomFilter.count(key)
      |> halve()

    current_count =
      frequency
      |> current_window()
      |> CountingBloomFilter.count(key)

    previous_count + current_count
  end

  def put(frequency, key) do
    current_window = current_window(frequency)

    CountingBloomFilter.put(current_window, key)
    count = count(frequency, key)

    if count > 0 and count <= :counters.info(frequency.frequency_counter).size,
      do: :counters.add(frequency.frequency_counter, count, 1)
  end

  def min_count(frequency) do
    0..:counters.info(frequency.frequency_counter).size
    |> Enum.reverse()
    |> Enum.reduce_while(0, fn
      0, _acc ->
        {:halt, 0}

      index, _acc ->
        cardinality = :counters.get(frequency.frequency_counter, index)

        if cardinality >= frequency.limit,
          do: {:halt, index},
          else: {:cont, cardinality}
    end)
  end

  def reset(frequency) do
    :ok = rotate_window(frequency)

    CountingBloomFilter.reset(rotating_window(frequency))

    for index <- 1..:counters.info(frequency.frequency_counter).size do
      count = :counters.get(frequency.frequency_counter, index)
      :counters.put(frequency.frequency_counter, index, 0)

      if halve(index) > 0,
        do: :counters.add(frequency.frequency_counter, halve(index), count)
    end

    :ok
  end

  defp rotate_window(frequency) do
    number_of_windows = length(frequency.windows)
    current_window = :counters.get(frequency.current_window, 1)

    if current_window >= number_of_windows - 1 do
      :counters.put(frequency.current_window, 1, 0)
    else
      :counters.add(frequency.current_window, 1, 1)
    end

    :ok
  end

  defp current_window(frequency) do
    Enum.at(frequency.windows, :counters.get(frequency.current_window, 1))
  end

  defp previous_window(frequency) do
    Enum.at(frequency.windows, :counters.get(frequency.current_window, 1) - 1)
  end

  defp rotating_window(frequency) do
    Enum.at(frequency.windows, :counters.get(frequency.current_window, 1) - 2)
  end

  defp halve(0), do: 0
  defp halve(number), do: trunc(number / 2)
end
