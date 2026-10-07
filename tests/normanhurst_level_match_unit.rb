# Standalone preload harness. No battle assets or production save data are used.
module GameData
  module Trainer
    def self.exists?(*args); true; end
  end
end
module Settings
  NO_MEGA_EVOLUTION = 1
end
class PokemonBag; end
class LevelProbePokemon
  attr_accessor :level, :hp, :totalhp, :status, :form, :moves, :item, :stats_calls
  def initialize(level, egg = false)
    @level, @egg, @hp, @totalhp, @status = level, egg, 1, 100, :POISON
    @form, @moves, @item, @stats_calls = 2, [:SURF, :PROTECT], :LEFTOVERS, 0
  end
  def egg?; @egg; end
  def calc_stats; @stats_calls += 1; @totalhp = @level * 3; end
  def heal; @hp = @totalhp; @status = :NONE; end
end
module TrainerBattle
  class << self
    attr_accessor :expected_level, :original_party, :throw_after_check
    def start_core(opponent)
      raise 'copy identity changed' if $player.party.equal?(@original_party)
      $player.party.each do |pokemon|
        next if pokemon.egg?
        raise 'unmatched level' unless pokemon.level == @expected_level
        raise 'stats not recalculated' unless pokemon.stats_calls == 1 && pokemon.totalhp == pokemon.level * 3
        raise 'not healed' unless pokemon.hp == pokemon.totalhp && pokemon.status == :NONE
        raise 'moves/form/item changed' unless pokemon.moves == [:SURF, :PROTECT] && pokemon.form == 2 && pokemon.item == :LEFTOVERS
      end
      raise 'intentional battle failure' if @throw_after_check
      :passed
    end
  end
end
def pbLoadTrainer(*args); :opponent; end
def setBattleRule(*args); $game_temp.battle_rules[:temporary] = true; end
source = ENV['CLI_LEVEL_MATCH_SOURCE'] || File.expand_path('../demo/scripts/0400-CLI_Normanhurst_Gym_Tests.rb', __dir__)
load source
$player = Struct.new(:party).new([LevelProbePokemon.new(15), LevelProbePokemon.new(50), LevelProbePokemon.new(100)])
$bag, $stats = Object.new, { :original => true }
$game_temp = Struct.new(:battle_rules).new({ :original => true })
$PokemonSystem = Struct.new(:battlescene).new(1)
$game_switches = { Settings::NO_MEGA_EVOLUTION => true }
original_party, original_bag, original_stats = $player.party, $bag, $stats
party_dump = Marshal.dump(original_party)
TrainerBattle.original_party = original_party
CLINormanhurstGymTests::ROSTER.each_with_index do |entry, index|
  TrainerBattle.expected_level = entry[:level]
  raise 'battle result' unless CLINormanhurstGymTests.battle(index, false) == :passed
  raise 'original levels or objects mutated' unless $player.party.equal?(original_party) && Marshal.dump(original_party) == party_dump
  raise 'globals not restored' unless $bag.equal?(original_bag) && $stats.equal?(original_stats) && $game_temp.battle_rules == { :original => true }
  raise 'settings not restored' unless $PokemonSystem.battlescene == 1 && $game_switches[Settings::NO_MEGA_EVOLUTION]
end
martin = CLINormanhurstGymTests::ROSTER.find { |entry| entry[:name] == 'Martin' }
raise 'Martin missing or wrong level' unless martin && martin[:level] == 55 && martin[:gym].nil?
TrainerBattle.expected_level = 15
TrainerBattle.throw_after_check = true
begin
  CLINormanhurstGymTests.battle(0, false)
  raise 'expected exception'
rescue => error
  raise unless error.message == 'intentional battle failure'
end
raise 'exception restoration failed' unless $player.party.equal?(original_party) && Marshal.dump(original_party) == party_dump && $bag.equal?(original_bag)
File.write(ENV['CLI_LEVEL_MATCH_RESULT'] || 'level-match-result.txt', 'NORMANHURST_LEVEL_MATCH_UNIT_PASSED')
puts 'NORMANHURST_LEVEL_MATCH_UNIT_PASSED: all seven opponent levels; originals and exception restoration'
exit
