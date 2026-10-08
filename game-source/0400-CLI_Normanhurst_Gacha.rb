# Scripts/Plugins are shared by all editions. Compiled gym trainers identify
# Normanhurst even in packaged games without PBS source files.
class PokemonGlobalMetadata
  attr_accessor :normanhurst_gacha_claimed, :normanhurst_gacha_pulls_used
end

module CLINormanhurstGacha
  LIMIT = 30
  # Weight per species, not per tier. Only ordinary species IDs, no custom forms.
  CATEGORIES = {
    :NORMANHURST_CLASSICS => ["Kanto & Johto All-Stars",
      [:BUTTERFREE, :BEEDRILL, :PIDGEOT, :RAICHU, :NINETALES, :VILEPLUME, :POLIWRATH, :AMPHAROS, :QUAGSIRE, :HERACROSS],
      [:VENUSAUR, :CHARIZARD, :BLASTOISE, :ARCANINE, :ALAKAZAM, :GENGAR, :GYARADOS, :LAPRAS, :DRAGONITE, :TYRANITAR],
      [:MEWTWO, :LUGIA, :HOOH]],
    :NORMANHURST_CHAMPIONS => ["Hoenn to Unova Champions",
      [:SWELLOW, :BRELOOM, :SHARPEDO, :FLYGON, :ROSERADE, :LUXRAY, :TOGEKISS, :EXCADRILL, :CHANDELURE, :GALVANTULA],
      [:SCEPTILE, :BLAZIKEN, :SWAMPERT, :GARDEVOIR, :MILOTIC, :SALAMENCE, :METAGROSS, :GARCHOMP, :LUCARIO, :VOLCARONA, :HONCHKROW],
      [:RAYQUAZA, :RESHIRAM, :ZEKROM]],
    :NORMANHURST_PALDEA => ["Paldea Powerhouses",
      [:OINKOLOGNE, :SPIDOPS, :LOKIX, :PAWMOT, :KILOWATTREL, :DACHSBUN, :ARBOLIVA, :GARGANACL, :SCOVILLAIN, :CLODSIRE],
      [:MEOWSCARADA, :SKELEDIRGE, :QUAQUAVAL, :CERULEDGE, :ARMAROUGE, :TINKATON, :PALAFIN, :ANNIHILAPE, :KINGAMBIT, :BAXCALIBUR],
      [:KORAIDON, :MIRAIDON, :CHIENPAO]]
  }.freeze

  def self.available?
    defined?(CLINormanhurstGymTests) && CLINormanhurstGymTests.available?
  end

  def self.remaining
    [LIMIT - ($PokemonGlobal.normanhurst_gacha_pulls_used || 0), 0].max
  end

  def self.terminal_species?(species)
    data = GameData::Species.try_get(species)
    data && data.form == 0 && ((1..5).include?(data.generation) || data.generation == 9) &&
      data.get_evolutions.empty?
  end

  def self.banners
    @banners ||= CATEGORIES.each_with_object({}) do |(id, category), result|
      name, common, rare, legendary = category
      pools = []
      [[common, 12, false], [rare, 5, false], [legendary, 1, true]].each do |species_list, weight, main|
        species_list.each do |species|
          next unless terminal_species?(species)
          pools << { :type => :pokemon, :species => species, :level => 50,
                     :probability => weight, :is_main_prize => main, :shiny_chance => 5 }
        end
      end
      next if pools.empty?
      result[id] = { :name => name, :cost_item => :GACHATICKET, :cost_amount => 1,
        :banner_image => "Graphics/UI/Gacha/empty_banner", :bgm => "Evolution",
        :anim_closed => "Graphics/UI/Gacha/pokeball_closed", :anim_style => :shake,
        :pity_limit => 10, :soft_pity_start => 8, :soft_pity_increase => 10, :pools => pools }
    end
  end

  def self.claim_tickets
    return false unless available? && $PokemonGlobal
    return false if $PokemonGlobal.normanhurst_gacha_claimed
    # Check before granting: a full Bag must not consume the one-time claim.
    return false unless $bag.can_add?(:GACHATICKET, LIMIT)
    return false unless $bag.add(:GACHATICKET, LIMIT)
    $PokemonGlobal.normanhurst_gacha_claimed = true
    true
  end

  def self.scientist
    return unless available?
    if claim_tickets
      pbMessage("30 tickets, once per save. Every prize is a fully evolved Pokemon.")
    elsif !$PokemonGlobal.normanhurst_gacha_claimed
      pbMessage("Make room in your Bag for your one-time gift of 30 Gacha Tickets.")
      return
    end
    if remaining == 0
      pbMessage("You've used all 30 pulls on this save. Enjoy your new team!")
      return
    end
    choice = pbMessage("#{remaining}/30 pulls left. Legendary pity: 10. Shiny chance: 5%.", ["Open gacha", "Cancel"], 2)
    pbGacha if choice == 0
  end

  # No normal banner contents are changed. Resolve the edition after compiled
  # trainer data is loaded, including when callers inspect the Hash's pools.
  module BannerLookup
    def [](key)
      return CLINormanhurstGacha.banners[key] if CLINormanhurstGacha.available?
      super
    end

    def keys
      return CLINormanhurstGacha.banners.keys if CLINormanhurstGacha.available?
      super
    end

    def has_key?(key)
      return CLINormanhurstGacha.banners.has_key?(key) if CLINormanhurstGacha.available?
      super
    end
    alias key? has_key?
    alias include? has_key?
    alias member? has_key?

    def values
      return CLINormanhurstGacha.banners.values if CLINormanhurstGacha.available?
      super
    end

    def each(&block)
      return CLINormanhurstGacha.banners.each(&block) if CLINormanhurstGacha.available?
      super
    end
    alias each_pair each

    def each_value(&block)
      return CLINormanhurstGacha.banners.each_value(&block) if CLINormanhurstGacha.available?
      super
    end

    def each_key(&block)
      return CLINormanhurstGacha.banners.each_key(&block) if CLINormanhurstGacha.available?
      super
    end

    def fetch(key, *args, &block)
      return CLINormanhurstGacha.banners.fetch(key, *args, &block) if CLINormanhurstGacha.available?
      super
    end

    def size
      return CLINormanhurstGacha.banners.size if CLINormanhurstGacha.available?
      super
    end
    alias length size

    def empty?
      return CLINormanhurstGacha.banners.empty? if CLINormanhurstGacha.available?
      super
    end
  end

  module PaidPulls
    def can_afford?(banner_id, times = 1)
      if CLINormanhurstGacha.available?
        return false unless $PokemonGlobal && times.is_a?(Integer) && times > 0
        return false if times > CLINormanhurstGacha.remaining
      end
      super
    end

    def pay_cost(banner_id, times = 1)
      paid = super
      if paid && CLINormanhurstGacha.available?
        $PokemonGlobal.normanhurst_gacha_pulls_used =
          ($PokemonGlobal.normanhurst_gacha_pulls_used || 0) + times
      end
      paid
    end
  end

  module SceneMenu
    def pbDrawOverlay
      super
      return unless CLINormanhurstGacha.available?
      pbDrawTextPositions(@sprites["overlay"].bitmap, [
        ["Pulls left: #{CLINormanhurstGacha.remaining}/30", 16, 16, 0,
         Color.new(248, 248, 248), Color.new(40, 40, 40)],
        ["#{GachaConfig::BANNERS.keys.index(@banner_id).to_i + 1}/#{GachaConfig::BANNERS.size} #{@banner[:name]}", Graphics.width / 2, 42, 2,
         Color.new(248, 248, 248), Color.new(40, 40, 40)]
      ])
    end

    def pbConfirmMultiRoll
      return super unless CLINormanhurstGacha.available?
      left = CLINormanhurstGacha.remaining
      if left == 0
        pbMessage("You've used all 30 pulls on this save.")
        return 0
      end
      super
    end
  end

  module Installer
    def runPlugins(*args)
      result = super
      unless @cli_normanhurst_gacha_installed
        if defined?(GachaConfig) && defined?(GachaLogic)
          GachaConfig::BANNERS.singleton_class.prepend(BannerLookup)
          GachaLogic.singleton_class.prepend(PaidPulls)
          GachaScene.prepend(SceneMenu) if defined?(GachaScene)
        end
        @cli_normanhurst_gacha_installed = true
      end
      result
    end
  end
end
PluginManager.singleton_class.prepend(CLINormanhurstGacha::Installer)

# Also reach storage from older saves that retain an old copy of the room map.
if defined?(MenuHandlers)
  MenuHandlers.add(:pause_menu, :normanhurst_pc, {
    "name" => "PC",
    "order" => 45,
    "condition" => proc { next CLINormanhurstGacha.available? && $game_map && $game_map.map_id == 1 },
    "effect" => proc { |menu|
      menu.pbHideMenu
      pbPokeCenterPC
      menu.pbRefresh
      menu.pbShowMenu
      next false
    }
  })
end
