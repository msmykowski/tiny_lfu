# TinyLfu

## Description
Window Tiny LFU is a low-memory cache addition policy with a near-optimal
cache hit rate. This addition policy can be used to supplement any cache
to increase the cache's hit rate, with very low memory overhead.

The implementation of this policy is based largely off http://www.cs.technion.ac.il/~gilga/TinyLFU_PDP2014.pdf.

This implementation makes use of erlang `atomics` to support safe, concurrent
writes. That means in theory the LFU can be put in `persistent_term` and processes
can access and update the LFU directly without any additional data copying or
triggering a global GC. It is still unclear to me if this is a good idea, but solves issues
with process bottlenecks.

## Benchamrks

When sampling 100% of requests, Tiny LFU gets near-optimal results, but at a major performance cost.

```
number_of_requests: 1_000_000
max_request_concurrency: 250
changes_in_traffic_patterns: 4

Memory [KB]: 3.136

Time With LFU [Seconds]: 67.580842
Time Without LFU [Seconds]: 33.981562

Optimal Hit Rate [%]: 25.0
LRW Cache With LFU Hit Rate [%]: 24.705
LRW Cache Without LFU Hit Rate [%]: 7.31
```

When sampling 1% of requests, Tiny LFU still more than doubles the cache-hit rate, but at a much more
reasonable performance cost.

```
number_of_requests: 1_000_000
max_request_concurrency: 250
changes_in_traffic_patterns: 4

Memory [KB]: 3.168

Time With LFU [Seconds]: 32.952012
Time Without LFU [Seconds]: 32.294992

Optimal Hit Rate [%]: 25.0
LRW Cache With LFU Hit Rate [%]: 16.3807
LRW Cache Without LFU Hit Rate [%]: 7.3939
```

## Should I use this in Production?
Absolutely not.
