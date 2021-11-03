defmodule TinyLfu do
  @moduledoc """
  Documentation for `TinyLfu`.
  """

  defstruct [:window_size, :threshold, :frequency, :door_keeper, :window]

  alias TinyLfu.{DoorKeeper, Frequency}

  def new(opts \\ []) do
    window_size = trunc(Keyword.get(opts, :window_size, 10_000))
    limit = trunc(Keyword.get(opts, :limit, 100))
    threshold = trunc(window_size / limit)

    door_keeper = Keyword.get(opts, :door_keeper, DoorKeeper.Default.new(max_size: window_size))

    frequency =
      Keyword.get(
        opts,
        :frequency,
        Frequency.Default.new(
          max_frequency: threshold,
          max_cardinality: window_size,
          limit: limit
        )
      )

    %__MODULE__{
      door_keeper: door_keeper,
      frequency: frequency,
      threshold: threshold,
      window: :counters.new(1, []),
      window_size: window_size
    }
  end

  def add(lfu, key) do
    lfu = if :counters.get(lfu.window, 1) >= lfu.window_size, do: reset(lfu), else: lfu

    :counters.add(lfu.window, 1, 1)

    if DoorKeeper.member?(lfu.door_keeper, key) do
      count = Frequency.count(lfu.frequency, key)

      if count >= lfu.threshold do
        {:ok, lfu}
      else
        Frequency.increment(lfu.frequency, key)
        min_count = Frequency.min_count(lfu.frequency)

        if count + 1 > min_count do
          {:ok, lfu}
        else
          {:error, lfu}
        end
      end
    else
      DoorKeeper.add(lfu.door_keeper, key)
      {:error, lfu}
    end
  end

  defp reset(lfu) do
    frequency = Frequency.reset(lfu.frequency)
    door_keeper = DoorKeeper.reset(lfu.door_keeper)
    :counters.put(lfu.window, 1, 0)
    %__MODULE__{lfu | door_keeper: door_keeper, frequency: frequency}
  end
end
