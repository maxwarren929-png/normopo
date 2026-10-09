# Disposable Normanhurst map renderer probe. No story state is saved.
require "json"
module OwnRegionProbe
  MAPS = [[201, 5, 9], [202, 7, 9], [200, 5, 8], [203, 10, 10], [204, 19, 23]]
  def self.assert(value, message)
    raise message unless value
  end
  def self.reachable?(target)
    queue = [[$game_player.x, $game_player.y]]
    seen = {queue.first => true}
    until queue.empty?
      x, y = queue.shift
      return true if [x, y] == target
      [[2,0,1],[4,-1,0],[6,1,0],[8,0,-1]].each do |d, dx, dy|
        next unless $game_player.passable?(x, y, d)
        p = [x + dx, y + dy]
        next if seen[p]
        seen[p] = true
        queue << p
      end
    end
    false
  end
  def self.step_transfer(map, x, y, direction, target)
    $game_temp.player_new_map_id, $game_temp.player_new_x, $game_temp.player_new_y = map, x, y
    $game_temp.player_new_direction = direction
    $scene.transfer_player
    30.times { Graphics.update; Input.update; $scene.update }
    {2=>:move_down,4=>:move_left,6=>:move_right,8=>:move_up}.fetch(direction).then { |move| $game_player.send(move) }
    120.times do
      Graphics.update
      Input.update
      $scene.update
      break if $game_map.map_id == target
    end
    assert($game_map.map_id == target, "actual doorway #{map}->#{target} failed")
  end
  def self.press?(key)
    return false if @done
    key == Input::USE && (@ticks || 0) % 15 == 0
  end
  def self.tick
    @ticks = (@ticks || 0) + 1
    return if @done || !defined?(Scene_Map) || !$scene.is_a?(Scene_Map)
    @done = true
    begin
      MAPS.each do |id, x, y|
        $game_temp.player_new_map_id, $game_temp.player_new_x, $game_temp.player_new_y = id, x, y
        $game_temp.player_new_direction = 2
        $scene.transfer_player
        $scene.update
        Graphics.update
        assert($game_map.map_id == id, "transfer failed #{id}")
        assert($game_map.metadata.snap_edges, "snap_edges missing #{id}")
        targets = {201=>[[5,9],[6,5],[3,8]], 202=>[[7,4],[9,5],[10,5],[11,5],[7,9]], 200=>[[5,8],[15,15],[16,15],[12,8],[11,1]], 203=>[[8,11],[4,12],[4,9],[12,11],[9,13],[10,1],[10,14]], 204=>[[18,23],[19,23],[20,23],[12,38]]}[id]
        reached = targets.map { |p| [p, reachable?(p)] }
        assert(reached.all? { |entry| entry[1] }, "unreachable approach #{id}: #{reached.inspect}")
        if id == 200
          [1,2,4,5,8].each do |eid|
            assert(!$game_map.events[eid].over_trigger?, "door/sign #{eid} lacks facing interaction")
          end
        end
        Graphics.screenshot("norm-opening-#{id}.png")
        (@results ||= []) << {map: id, reachable: reached}
      end
      step_transfer(200, 5, 8, 8, 201)
      step_transfer(201, 5, 9, 2, 200)
      step_transfer(200, 15, 15, 8, 202)
      step_transfer(202, 7, 9, 2, 200)
      [[202,6,12,7,9],[203,15,21,10,14],[201,3,8,3,8]].each do |id,x,y,safe_x,safe_y|
        $game_temp.player_new_map_id, $game_temp.player_new_x, $game_temp.player_new_y = id, 5, 5
        $scene.transfer_player
        $game_player.instance_variable_set(:@x,x)
        $game_player.instance_variable_set(:@y,y)
        Game.load_map
        assert([$game_player.x,$game_player.y]==[safe_x,safe_y], "saved-position recovery failed #{id}")
      end
      File.write("own-region-report.json", JSON.pretty_generate({passed: true, maps: @results, actual_house_lab_door_transfers: true, saved_position_recovery: true, valid_saved_position_preserved: true}))
      exit
    rescue => e
      File.write("own-region-report.json", JSON.pretty_generate({passed: false, maps: @results, error: "#{e.class}: #{e.message}", backtrace: e.backtrace.first(8)}))
      exit 1
    end
  end
end
Object.prepend(Module.new do
  # Daylight for artwork review only. The actual game still uses real time.
  def pbGetTimeNow
    Time.local(2026, 10, 8, 12, 0, 0)
  end
  def pbMessage(message, *args, &block)
    return 0 if defined?(Scene_Map) && $scene.is_a?(Scene_Map)
    super
  end
end)
module Input
  class << self
    alias own_region_original_trigger trigger?
    def trigger?(key)
      OwnRegionProbe.press?(key) || own_region_original_trigger(key)
    end
  end
end
module Graphics
  class << self
    alias own_region_original_update update
    def update
      own_region_original_update
      OwnRegionProbe.tick
    end
  end
end
