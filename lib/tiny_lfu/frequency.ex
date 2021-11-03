defprotocol TinyLfu.Frequency do
  def count(frequency, key)

  def increment(frequency, key)

  def min_count(frequency)

  def reset(frequency)
end
