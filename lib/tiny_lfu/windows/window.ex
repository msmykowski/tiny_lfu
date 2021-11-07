defmodule TinyLfu.Windows.Window do
  defstruct [:cardinality, :index, :limit, :state, :bloom_filter, :frequency_counter]

  @state %{
    size: 1,
    min_count: 2
  }

  alias Talan.CountingBloomFilter

  def new(opts) do
    index = Keyword.fetch!(opts, :index)
    limit = Keyword.fetch!(opts, :limit)
    max_frequency = Keyword.fetch!(opts, :max_frequency)
    cardinality = Keyword.fetch!(opts, :cardinality)

    %__MODULE__{
      bloom_filter: CountingBloomFilter.new(limit, counters_bit_size: 16),
      cardinality: cardinality,
      index: index,
      state: :atomics.new(length(Map.keys(@state)), []),
      frequency_counter: :counters.new(max_frequency, [:write_concurrency]),
      limit: limit
    }
  end

  def count(window, key), do: CountingBloomFilter.count(window.bloom_filter, key)

  def index(window), do: window.index

  def limit(window), do: window.limit

  def put(window, key) do
    CountingBloomFilter.put(window.bloom_filter, key)
    count = count(window, key)

    if count > 0 and count <= :counters.info(window.frequency_counter).size,
      do: :counters.add(window.frequency_counter, count, 1)
  end

  def set_state(window, state) do
    for {k, v} <- state do
      :atomics.put(window.state, @state[k], v)
    end
  end

  def increment(window) do
    :atomics.add_get(window.state, @state.size, 1)
  end

  def min_count(window) do
    initial_min_count = :atomics.get(window.state, @state.min_count)

    running_count =
      0..:counters.info(window.frequency_counter).size
      |> Enum.reverse()
      |> Enum.reduce_while(0, fn
        0, _acc ->
          {:halt, 0}

        index, _acc ->
          acc = :counters.get(window.frequency_counter, index)

          if acc >= window.cardinality,
            do: {:halt, index},
            else: {:cont, acc}
      end)

    if initial_min_count > running_count, do: initial_min_count, else: running_count
  end

  def refresh(window) do
    CountingBloomFilter.reset(window.bloom_filter)

    set_state(window, %{min_count: 0, size: 0})

    1..:counters.info(window.frequency_counter).size
    |> Stream.each(&:counters.put(window.frequency_counter, &1, 0))
    |> Stream.run()

    :ok
  end
end
