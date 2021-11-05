defmodule TinyLfu do
  @moduledoc """
  Documentation for `TinyLfu`.
  """

  defstruct [:frequencies, :sample_rate, :threshold, :window_size, :window]

  alias TinyLfu.Frequencies

  def new(opts \\ []) do
    limit = trunc(Keyword.get(opts, :limit, 50))
    window_size = trunc(Keyword.get(opts, :window_size, 1_000))
    threshold = trunc(window_size / limit)
    sample_rate = Keyword.get(opts, :sample_rate, 1.0)

    frequencies =
      Frequencies.new(
        max_frequency: threshold,
        max_cardinality: window_size,
        limit: limit
      )

    %__MODULE__{
      frequencies: frequencies,
      sample_rate: sample_rate,
      threshold: threshold,
      window: :counters.new(1, []),
      window_size: window_size
    }
  end

  def sample?(lfu, _, sample \\ :rand.uniform())

  def sample?(%__MODULE__{sample_rate: sample_rate}, _key, sample) when sample_rate <= sample,
    do: false

  def sample?(lfu, key, _sample), do: add?(lfu, key)

  def add?(lfu, key) do
    :counters.add(lfu.window, 1, 1)

    if :counters.get(lfu.window, 1) == lfu.window_size, do: reset(lfu)

    count = Frequencies.count(lfu.frequencies, key)

    if count >= lfu.threshold do
      true
    else
      min_count = Frequencies.min_count(lfu.frequencies)

      cond do
        min_count >= lfu.threshold ->
          false

        count > min_count ->
          Frequencies.put(lfu.frequencies, key)
          true

        true ->
          Frequencies.put(lfu.frequencies, key)
          false
      end
    end
  end

  defp reset(lfu) do
    :ok = Frequencies.reset(lfu.frequencies)
    :counters.put(lfu.window, 1, 0)

    :ok
  end
end
