# Disposable Normanhurst map renderer probe. No story state is saved.
require "json"
module OwnRegionProbe
  MAPS = [[201, 3, 8], [202, 6, 12], [200, 5, 8], [203, 15, 21], [204, 12, 38]]
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
  def self.press?(key)
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
        targets = {201=>[[3,8],[7,5]], 202=>[[6,4],[8,5],[6,12]], 200=>[[5,8],[15,15],[11,1]], 203=>[[18,15],[12,8],[14,2]], 204=>[[18,23],[19,23],[20,23],[12,1]]}[id]
        reached = targets.map { |p| [p, reachable?(p)] }
        Graphics.screenshot("norm-opening-#{id}.png")
        (@results ||= []) << {map: id, reachable: reached}
      end
      File.write("own-region-report.json", JSON.pretty_generate({passed: true, maps: @results}))
      exit
    rescue => e
      File.write("own-region-report.json", JSON.pretty_generate({passed: false, maps: @results, error: "#{e.class}: #{e.message}", backtrace: e.backtrace.first(8)}))
    end
  end
end
Object.prepend(Module.new do
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
