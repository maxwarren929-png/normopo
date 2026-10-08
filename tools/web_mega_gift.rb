# Injected into the staged Normanhurst website archive only, never desktop scripts.
class PokemonGlobalMetadata
  attr_accessor :cli_web_mega_gift_received
  attr_accessor :cli_web_mega_gift_items
end

module CLIWebMegaGift
  def self.item_ids
    @item_ids ||= begin
      ids = []
      GameData::Item.each do |item|
        ids << item.id if item.is_mega_stone? || item.id == :MEGARING
      end
      ids.freeze
    end
  end

  def self.grant
    return unless $player && $bag && $PokemonGlobal
    return unless CLINormanhurstGacha.available?
    return if $game_temp && $game_temp.in_battle
    # Legacy website gifts predate Honchkrowite and Tropiusite. Preserve those claims even if
    # their stones are now held/sold, but deliver the newly registered stone.
    if !$PokemonGlobal.cli_web_mega_gift_items
      $PokemonGlobal.cli_web_mega_gift_items = $PokemonGlobal.cli_web_mega_gift_received ? item_ids.reject { |id| [:HONCHKROWITE, :TROPIUSITE].include?(id) } : []
    end
    claimed = $PokemonGlobal.cli_web_mega_gift_items
    missing = item_ids - claimed
    return if missing.empty?
    now = System.uptime
    return if @next_attempt && now < @next_attempt
    @next_attempt = now + 2
    missing.each do |id|
      claimed << id if $bag.has?(id) || $bag.add(id)
    end
    $PokemonGlobal.cli_web_mega_gift_received = (item_ids - claimed).empty?
  end
end

# Runs after both New Game and Continue once the overworld is active.
EventHandlers.add(:on_frame_update, :cli_web_mega_gift, proc { CLIWebMegaGift.grant })
