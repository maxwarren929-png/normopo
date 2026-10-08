# Normanhurst-only navigation; map 1 remains the separate development room.
module CLINormanhurstStoryAccess
  def self.travel(map, x, y, direction)
    $game_temp.player_new_map_id = map
    $game_temp.player_new_x = x
    $game_temp.player_new_y = y
    $game_temp.player_new_direction = direction
    $scene.transfer_player
  end
end
MenuHandlers.add(:pause_menu, :normanhurst_story_access, {
  "name" => proc { ($game_map.map_id == 1) ? "Story opening" : "Development room" },
  "order" => 47,
  "condition" => proc { |menu| CLINormanhurstGacha.available? && ([1, 200, 201, 202, 203, 204].include?($game_map.map_id)) },
  "effect" => proc { |menu|
    menu.pbEndScene
    if $game_map.map_id == 1
      CLINormanhurstStoryAccess.travel(201, 3, 8, 8)
    else
      CLINormanhurstStoryAccess.travel(1, 5, 5, 2)
    end
    next true
  }
})
