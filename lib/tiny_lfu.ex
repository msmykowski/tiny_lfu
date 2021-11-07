defmodule TinyLfu do
  @moduledoc """
  Documentation for `TinyLfu`.
  """

  defstruct [
    :limit,
    :sample_rate,
    :threshold,
    :windows
  ]

  alias TinyLfu.Windows

  def new(opts \\ []) do
    limit = trunc(Keyword.get(opts, :limit, 50))
    window_size = trunc(Keyword.get(opts, :window_size, 500))
    threshold = trunc(window_size / limit)
    sample_rate = Keyword.get(opts, :sample_rate, 1.0)

    window_opts = [cardinality: limit, limit: window_size, max_frequency: threshold]
    windows = Windows.new(window_opts: window_opts)

    %__MODULE__{
      limit: limit,
      sample_rate: sample_rate,
      threshold: threshold,
      windows: windows
    }
  end

  def sample?(lfu, _, sample \\ :rand.uniform())

  def sample?(%__MODULE__{sample_rate: sample_rate}, _key, sample) when sample_rate <= sample,
    do: false

  def sample?(lfu, key, _sample), do: add?(lfu, key)

  def add?(lfu, key) do
    window = Windows.get_current_window(lfu.windows)
    count = Windows.get_window_count(lfu.windows, key, window)

    if count >= lfu.threshold do
      true
    else
      min_count = Windows.get_min_count(lfu.windows, window)

      cond do
        min_count >= lfu.threshold ->
          false

        count > min_count ->
          Windows.put_in_window(lfu.windows, key, window)
          true

        true ->
          Windows.put_in_window(lfu.windows, key, window)
          false
      end
    end
  end
end
