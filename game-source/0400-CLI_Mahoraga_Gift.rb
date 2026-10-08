# One development gift, separately from the paid gacha budget, in Normanhurst.
class PokemonGlobalMetadata
  attr_accessor :cli_mahoraga_claimed
end

module CLIMahoragaGift
  def self.claim
    return unless CLINormanhurstGacha.available?
    if $PokemonGlobal.cli_mahoraga_claimed
      pbMessage("You've already received Mahoraga on this save.")
      return
    end
    pokemon = Pokemon.new(:MACHAMP, 50, $player)
    pokemon.form = 1
    pokemon.calc_stats
    pokemon.heal
    if pbAddPokemonSilent(pokemon)
      $PokemonGlobal.cli_mahoraga_claimed = true
      pbMessage("You received Mahoraga! Check your party or Pokemon boxes.")
    else
      pbMessage("Make space in your party or Pokemon boxes first.")
    end
  end
end

MenuHandlers.add(:pause_menu, :normanhurst_mahoraga, {
  "name" => "Mahoraga",
  "order" => 46,
  "condition" => proc { |menu| CLINormanhurstGacha.available? && $game_map.map_id == 1 && !$PokemonGlobal.cli_mahoraga_claimed },
  "effect" => proc { |menu|
    menu.pbHideMenu
    CLIMahoragaGift.claim
    menu.pbRefresh
    menu.pbShowMenu
    next false
  }
})
