defmodule TinyLfu.Frequency.Default do
  defstruct [:max_cardinality, :limit, :current_window, :previous_window, :counter]

  alias Talan.CountingBloomFilter

  def new(opts) do
    limit = Keyword.fetch!(opts, :limit)
    max_cardinality = Keyword.fetch!(opts, :max_cardinality)
    max_frequency = Keyword.fetch!(opts, :max_frequency)
    current_window = CountingBloomFilter.new(max_cardinality, counters_bit_size: 16)
    previous_window = CountingBloomFilter.new(max_cardinality, counters_bit_size: 16)
    counter = :counters.new(max_frequency, [])

    %__MODULE__{
      max_cardinality: max_cardinality,
      limit: limit,
      counter: counter,
      current_window: current_window,
      previous_window: previous_window
    }
  end

  defimpl TinyLfu.Frequency, for: __MODULE__ do
    def count(frequency, key) do
      current_window_count = CountingBloomFilter.count(frequency.current_window, key)

      previous_window_count =
        frequency.previous_window
        |> CountingBloomFilter.count(key)
        |> halve()

      current_window_count + previous_window_count
    end

    def increment(frequency, key) do
      CountingBloomFilter.put(frequency.current_window, key)
      count = TinyLfu.Frequency.count(frequency, key)

      if count <= :counters.info(frequency.counter).size,
        do: :counters.add(frequency.counter, count, 1)
    end

    def min_count(frequency) do
      0..:counters.info(frequency.counter).size
      |> Enum.reverse()
      |> Enum.reduce_while(0, fn
        0, _acc ->
          {:halt, 0}

        index, _acc ->
          cardinality = :counters.get(frequency.counter, index)

          if cardinality >= frequency.limit,
            do: {:halt, index},
            else: {:cont, cardinality}
      end)
    end

    def reset(frequency) do
      current_window = CountingBloomFilter.new(frequency.limit, counters_bit_size: 16)
      previous_window = frequency.current_window

      :counters.put(frequency.counter, 1, 0)

      for index <- 2..:counters.info(frequency.counter).size do
        count = :counters.get(frequency.counter, index)
        :counters.put(frequency.counter, index, 0)
        :counters.add(frequency.counter, halve(index), count)
      end

      %TinyLfu.Frequency.Default{
        frequency
        | current_window: current_window,
          previous_window: previous_window
      }
    end

    defp halve(0), do: 0
    defp halve(number), do: trunc(number / 2)
  end
end
