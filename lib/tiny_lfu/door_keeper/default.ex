defmodule TinyLfu.DoorKeeper.Default do
  defstruct [:store, :opts]

  alias Talan.BloomFilter

  def new(opts) do
    max_size = Keyword.fetch!(opts, :max_size)
    %__MODULE__{opts: opts, store: BloomFilter.new(max_size)}
  end

  defimpl TinyLfu.DoorKeeper, for: __MODULE__ do
    def add(door_keeper, key) do
      BloomFilter.put(door_keeper.store, key)
    end

    def member?(door_keeper, key) do
      BloomFilter.member?(door_keeper.store, key)
    end

    def reset(door_keeper) do
      TinyLfu.DoorKeeper.Default.new(door_keeper.opts)
    end
  end
end
