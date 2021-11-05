import Cachex.Spec

cache_size = 50

#metrics setup
hit_rate_w_lfu = :ets.new(:hit_rate_w_lfu, [:public, :set, read_concurrency: true])
:ets.insert(hit_rate_w_lfu, {:miss, 0})
:ets.insert(hit_rate_w_lfu, {:hit, 0})

hit_rate_wo_lfu = :ets.new(:hit_rate_wo_lfu, [:public, :set, read_concurrency: true])
:ets.insert(hit_rate_wo_lfu, {:miss, 0})
:ets.insert(hit_rate_wo_lfu, {:hit, 0})

#cache setup
Cachex.start(:cache_w_lfu, [limit: limit(size: cache_size, policy: Cachex.Policy.LRW, reclaim: 0.05)])
Cachex.start(:cache_wo_lfu, [limit: limit(size: cache_size, policy: Cachex.Policy.LRW, reclaim: 0.05)])

#request distribution
hot = Enum.to_list(1..cache_size)
warm = Enum.to_list(51..300)
cool = Enum.to_list(301..2000)
cold = Enum.to_list(2001..5000)

number_of_requests = 1_000_000
max_request_concurrency = 250
changes_in_traffic_patterns = 4

inputs = 1..number_of_requests
|> Enum.chunk_every(trunc(number_of_requests/changes_in_traffic_patterns))
|> Stream.flat_map(fn chunk ->
  multiplier = Enum.random(2..10)
  Enum.map(chunk, fn(_i) ->
    category = Enum.random([hot, warm, cool, cold])
    Enum.random(category) + multiplier * length(category)
  end)
end)

starting_memory = :persistent_term.info().memory
:persistent_term.put(:lfu, TinyLfu.new(limit: cache_size, sample_rate: 0.01))

stream_wo_lfu = Task.async_stream(inputs, fn (input) ->
  case Cachex.get(:cache_wo_lfu, input) do
    {:ok, true} ->
      Cachex.put(:cache_wo_lfu, input, true)
      :ets.update_counter(hit_rate_wo_lfu, :hit, 1)

    {:ok, nil} ->
      Cachex.put(:cache_wo_lfu, input, true)
      :ets.update_counter(hit_rate_wo_lfu, :miss, 1)
  end
end, max_concurrency: max_request_concurrency)

stream_w_lfu = Task.async_stream(inputs, fn (input) ->
  case Cachex.get(:cache_w_lfu, input) do
    {:ok, true} ->
      :ets.update_counter(hit_rate_w_lfu, :hit, 1)

    {:ok, nil} ->
      :ets.update_counter(hit_rate_w_lfu, :miss, 1)
  end

  lfu = :persistent_term.get(:lfu)
  if TinyLfu.sample?(lfu, input), do: Cachex.put(:cache_w_lfu, input, true)
end, max_concurrency: max_request_concurrency)

{time_w_lfu, :ok} = :timer.tc(Stream, :run, [stream_w_lfu])
{time_wo_lfu, :ok} = :timer.tc(Stream, :run, [stream_wo_lfu])

ending_memory = :persistent_term.info().memory

[{:hit, hits_w_lfu}] = :ets.lookup(hit_rate_w_lfu, :hit)
[{:miss, misses_w_lfu}] = :ets.lookup(hit_rate_w_lfu, :miss)

[{:hit, hits_wo_lfu}] = :ets.lookup(hit_rate_wo_lfu, :hit)
[{:miss, misses_wo_lfu}] = :ets.lookup(hit_rate_wo_lfu, :miss)

IO.inspect (ending_memory - starting_memory)/1_000, label: "Memory [KB]"
IO.inspect time_w_lfu/1_000_000, label: "Time With LFU [Seconds]"
IO.inspect time_wo_lfu/1_000_000, label: "Time Without LFU [Seconds]"
IO.inspect (hits_w_lfu/(hits_w_lfu + misses_w_lfu)) * 100, label: "LRW Cache With LFU Hit Rate [%]"
IO.inspect (hits_wo_lfu/(hits_wo_lfu + misses_wo_lfu)) * 100, label: "LRW Cache Without LFU Hit Rate [%]"
