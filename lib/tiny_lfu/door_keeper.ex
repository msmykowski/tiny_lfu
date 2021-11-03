defprotocol TinyLfu.DoorKeeper do
  def add(door_keeper, key)

  def member?(door_keeper, key)

  def reset(door_keeper)
end
