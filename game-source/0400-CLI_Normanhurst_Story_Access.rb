# Normanhurst-only navigation; map 1 remains the separate development room.
module CLINormanhurstStoryAccess
  SAFE_ENTRIES = {200=>[11,1],201=>[5,9],202=>[7,9],203=>[10,14],204=>[12,38]}.freeze

  def self.refresh_saved_opening
    return unless CLINormanhurstGacha.available? && $game_map && SAFE_ENTRIES.key?($game_map.map_id)
    map_id = $game_map.map_id
    x, y = $game_player.x, $game_player.y
    # Saves serialize MapFactory/map events. Reload authored data even if the
    # engine magic number happens to match, then repair only blocked positions.
    $map_factory.setup(map_id)
    unless $map_factory.isPassableStrict?(map_id, x, y, $game_player)
      x, y = SAFE_ENTRIES.fetch(map_id)
    end
    $game_player.moveto(x, y)
    $game_player.center(x, y)
    $PokemonEncounters.setup(map_id) if $PokemonEncounters
  end

  def self.travel(map, x, y, direction)
    $game_temp.player_new_map_id = map
    $game_temp.player_new_x = x
    $game_temp.player_new_y = y
    $game_temp.player_new_direction = direction
    $scene.transfer_player
  end
end
Game.singleton_class.prepend(Module.new do
  def load_map
    super
    CLINormanhurstStoryAccess.refresh_saved_opening
  end
end)

MenuHandlers.add(:pause_menu, :normanhurst_story_access, {
  "name" => proc { ($game_map.map_id == 1) ? "Story opening" : "Development room" },
  "order" => 47,
  "condition" => proc { |menu| CLINormanhurstGacha.available? && ([1, 200, 201, 202, 203, 204].include?($game_map.map_id)) },
  "effect" => proc { |menu|
    menu.pbEndScene
    if $game_map.map_id == 1
      CLINormanhurstStoryAccess.travel(201, 5, 9, 8)
    else
      CLINormanhurstStoryAccess.travel(1, 5, 5, 2)
    end
    next true
  }
})
