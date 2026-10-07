# ruby tests/normanhurst_gacha_unit.rb
# Uses production gacha logic and curated pools; doubles replace only the game
# host. Species IDs/generations/evolution edges come from the actual PBS files.
$stdout.sync = true
ROOT = File.expand_path("..", __dir__)
class PokemonGlobalMetadata; end
module CLINormanhurstGymTests
  class << self
    attr_accessor :enabled
    def available?; !!enabled; end
  end
end
module GameData
  class Species
    DATA = {}
    attr_accessor :id, :form, :generation, :evos
    def self.try_get(id); DATA[id]; end
    def get_evolutions; evos; end
  end
end
Dir.glob(File.join(ROOT, "demo/game/PBS/pokemon*.txt")).select do |path|
  ["pokemon.txt", "pokemon_base_Gen_9_Pack.txt"].include?(File.basename(path))
end.each do |path|
  data = nil
  File.foreach(path) do |line|
    if line =~ /^\[(\w+)\]/
      data = GameData::Species.new
      data.id, data.form, data.generation, data.evos = $1.to_sym, 0, 0, []
      GameData::Species::DATA[data.id] = data
    elsif data && line =~ /^Generation\s*=\s*(\d+)/
      data.generation = $1.to_i
    elsif data && line =~ /^Evolutions\s*=\s*(.+)/
      data.evos = $1.split(",").each_slice(3).to_a
    end
  end
end
class PokemonBag
  def initialize; @items = Hash.new(0); end
  def quantity(item); @items[item]; end
  def can_add?(*); true; end
  def add(item, amount); @items[item] += amount; true; end
  def has?(item, amount); quantity(item) >= amount; end
  def remove(item, amount)
    return false unless has?(item, amount)
    @items[item] -= amount
    true
  end
end
class PokemonStorage
  def initialize; @boxes = Array.new(4) { Array.new(30) }; end
  def maxBoxes; @boxes.length; end
  def maxPokemon(box); @boxes[box].length; end
  def [](box, slot); @boxes[box][slot]; end
  def []=(box, slot, value); @boxes[box][slot] = value; end
end
class UnitDex
  def register(*); end
  def set_owned(*); end
  def owned?(*); false; end
end
class Player
  attr_accessor :party, :money
  def initialize; @party = []; @money = 100; @pokedex = UnitDex.new; end
  def pokedex; @pokedex; end
end
class Pokemon
  attr_accessor :species, :level, :shiny, :nature, :ability, :ability_index
  def initialize(species, level); @species, @level = species, level; end
  def name; species.to_s; end
  def form; 0; end
  def calc_stats; end
end
def _INTL(text, *args); text; end
def pbAddPokemonSilent(pokemon)
  if $player.party.length < 6
    $player.party << pokemon
    return true
  end
  $PokemonStorage.maxBoxes.times do |box|
    $PokemonStorage.maxPokemon(box).times do |slot|
      next if $PokemonStorage[box, slot]
      $PokemonStorage[box, slot] = pokemon
      return true
    end
  end
  false
end
module PluginManager
  def self.runPlugins
    load File.join(ROOT, "demo/game/Plugins/Gacha System/001_Config.rb")
    load File.join(ROOT, "demo/game/Plugins/Gacha System/002_Logic.rb")
  end
end
load File.join(ROOT, "demo/scripts/0400-CLI_Normanhurst_Gacha.rb")
raise "installed before plugins" if defined?(GachaLogic)
PluginManager.runPlugins
$PokemonGlobal, $PokemonStorage, $bag, $player = PokemonGlobalMetadata.new, PokemonStorage.new, PokemonBag.new, Player.new
load File.join(ROOT, "tests/normanhurst_gacha_smoke.rb")
CLINormanhurstGymTests.enabled = true
puts CLINormanhurstGachaSmoke.run.inspect
# Full storage must reject payment without consuming a ticket or a pull.
$player.party = Array.new(6, :occupied)
$PokemonStorage.maxBoxes.times do |box|
  $PokemonStorage.maxPokemon(box).times { |slot| $PokemonStorage[box, slot] = :occupied }
end
$bag.add(:GACHATICKET, 30)
raise "full storage paid" if GachaLogic.pay_cost(GachaConfig::BANNERS.keys.first)
raise "full storage consumed cap" unless CLINormanhurstGacha.remaining == 30
raise "full storage consumed ticket" unless $bag.quantity(:GACHATICKET) == 30
# Both non-Normanhurst editions use precisely the original configuration.
CLINormanhurstGymTests.enabled = false
raise "normal banners changed" unless GachaConfig::BANNERS.keys == [:RESHIRAM_BANNER, :ITEM_PREMIUM_BANNER]
raise "normal item banner changed" unless GachaConfig::BANNERS[:ITEM_PREMIUM_BANNER][:pools].all? { |p| p[:type] == :item }
raise "normal pity changed" unless GachaConfig::BANNERS[:RESHIRAM_BANNER][:pity_limit] == 90
raise "non-Normanhurst grant" if CLINormanhurstGacha.claim_tickets
$player.party, $PokemonStorage = [], PokemonStorage.new
$PokemonGlobal.normanhurst_gacha_pulls_used = 30
raise "normal cap changed" unless GachaLogic.pay_cost(:RESHIRAM_BANNER, 10)
raise "normal cap storage changed" unless $PokemonGlobal.normanhurst_gacha_pulls_used == 30
puts "PASS Normanhurst gacha unit checks, including unchanged non-Normanhurst banners"
