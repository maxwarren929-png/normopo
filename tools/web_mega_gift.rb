# Injected into the staged Normanhurst website archive only, never desktop scripts.
class PokemonGlobalMetadata
  attr_accessor :cli_web_mega_gift_received
end

module CLIWebMegaGift
  def self.grant
    return unless $player && $bag && $PokemonGlobal
    return unless CLINormanhurstGacha.available?
    return if $PokemonGlobal.cli_web_mega_gift_received
    return if $game_temp && $game_temp.in_battle
    now = System.uptime
    return if @next_attempt && now < @next_attempt
    @next_attempt = now + 2
    complete = true
    GameData::Item.each do |item|
      next unless item.is_mega_stone? || item.id == :MEGARING
      next if $bag.has?(item.id)
      complete = false unless $bag.add(item.id)
    end
    $PokemonGlobal.cli_web_mega_gift_received = true if complete
  end
end

# Runs after both New Game and Continue once the overworld is active.
EventHandlers.add(:on_frame_update, :cli_web_mega_gift, proc { CLIWebMegaGift.grant })
