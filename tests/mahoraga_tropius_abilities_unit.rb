# Focused standalone Ruby/mkxp-z preload harness. No game assets or real battle.
# CLI_MAHORAGA_TROPIUS_SOURCE may select the ability script from a temp run dir.
# mkxp-z: preloadScript=[absolute path to this file], rubyLoadpath=["stdlib"].
# Use an isolated run directory, a valid Game.ini and empty Scripts.rxdata
# (Ruby Marshal empty array bytes 04 08 5b 00); copy the native executable there.
# This tests handlers and plugin-safe wrappers with fakes, not a live battle.
def _INTL(text, *args)
  args.each_with_index { |arg, i| text = text.gsub("{#{i + 1}}", arg.to_s) }
  text
end
def check(value, message); raise message unless value; end
class Battle
  attr_accessor :moldBreaker, :roll
  attr_reader :rolls
  def initialize; @moldBreaker = false; @roll = 24; @rolls = 0; end
  def pbRandom(n); @rolls += 1; @roll; end
  def pbShowAbilitySplash(*args); end
  def pbHideAbilitySplash(*args); end
  def pbDisplay(*args); end
  module AbilityEffects
    class Registry
      def initialize; @handlers = {}; end
      def add(id, handler); @handlers[id] = handler; end
      def [](id); @handlers.fetch(id); end
    end
    OnBeingHit = Registry.new
    DamageCalcFromTarget = Registry.new
    OnEndOfUsingMove = Registry.new
  end
  class Move
    attr_accessor :id, :calcType, :damage
    def initialize(battle, id = :BULLETSEED)
      @battle, @id, @calcType, @damage = battle, id, :GRASS, true
    end
    def damagingMove?; @damage; end
    def pbCalcType(user); :GRASS; end
    class FixedDamageMove < Move
      def pbCalcDamage(user, target, n = 1); target.damageState.calcDamage = 41; :fixed; end
    end
  end
  class Battler
    attr_accessor :ability, :active, :hp, :totalhp, :blocked, :mode, :snatcher
    attr_reader :damageState
    def initialize(battle)
      @battle = battle
      @ability, @active, @hp, @totalhp, @blocked = :ADAPTATION, true, 40, 101, false
      @damageState = Struct.new(:substitute, :unaffected, :hpLost, :calcDamage).new(false, false, 10, 40)
      pbInitEffects(false)
    end
    def pbInitEffects(baton); :reset; end
    def hasActiveAbility?(id); @active && @hp > 0 && @ability == id; end
    def canHeal?; @hp > 0 && @hp < @totalhp && !@blocked; end
    def pbRecoverHP(amount)
      old = @hp
      @hp = [@hp + amount, @totalhp].min
      @hp - old
    end
    def pbThis; 'User'; end
    def pbChangeUser(choice, move, user); @snatcher || user; end
    def pbEffectsAfterMove(user, targets, move, hits)
      if user.hasActiveAbility?(:FRUITFULCANOPY)
        AbilityEffects::OnEndOfUsingMove[:FRUITFULCANOPY].call(user.ability, user, targets, move, @battle)
      end
      :after
    end
    def pbEndTurn(choice); :end; end
    # Mimic the audited core's committed-use vs unable-to-act branches.
    def pbUseMove(choice, special = false)
      move = choice[2]
      return pbEndTurn(choice) if @mode == :unable
      user = pbChangeUser(choice, move, self)
      pbEffectsAfterMove(user, [], move, 0) unless @mode == :early_block
      pbEndTurn(choice)
      :used
    end
  end
end
class Pokemon
  attr_accessor :species, :form
  def speciesName; 'Machamp'; end
end
module PluginManager
  def self.runPlugins
    # Simulate aliases being installed during plugin loading. No prepend may
    # have occurred yet, otherwise their captured method would recurse.
    check(!Battle::Battler.ancestors.include?(CLIMahoragaTropiusAbilities::BattlerHooks), 'installed before plugins') unless @loaded
    unless @loaded
      Battle::Battler.class_eval do
        alias plugin_init pbInitEffects
        def pbInitEffects(baton); plugin_init(baton); end
      end
      @loaded = true
    end
    :plugins
  end
end
source = ENV['CLI_MAHORAGA_TROPIUS_SOURCE'] || File.expand_path('../demo/scripts/0400-CLI_Mahoraga_Tropius_Abilities.rb', __dir__)
load source
check(PluginManager.runPlugins == :plugins, 'installer changed return')
PluginManager.runPlugins
check(Battle::Battler.ancestors.count { |a| a == CLIMahoragaTropiusAbilities::BattlerHooks } == 1, 'duplicate install')
battle = Battle.new
user = Battle::Battler.new(battle)
target = Battle::Battler.new(battle)
move = Battle::Move.new(battle)
hit = Battle::AbilityEffects::OnBeingHit[:ADAPTATION]
calc = Battle::AbilityEffects::DamageCalcFromTarget[:ADAPTATION]
def multiplier(calc, user, target, move)
  mult = { :final_damage_multiplier => 1.0 }
  calc.call(:ADAPTATION, user, target, move, mult, 40, :GRASS)
  mult[:final_damage_multiplier]
end
check(multiplier(calc, user, target, move) == 1.0, 'first hit reduced')
3.times do
  hit.call(:ADAPTATION, user, target, move, battle)
  check(multiplier(calc, user, target, move) == 0.5, 'same-use later hit not half or stacked')
end
other = Battle::Move.new(battle, :RAZORLEAF)
check(multiplier(calc, user, target, other) == 1.0, 'learned type rather than move ID')
[false, true].each do |baton|
  check(target.pbInitEffects(baton) == :reset, 'reset return changed')
  check(multiplier(calc, user, target, move) == 1.0, 'switch/Baton Pass retained memory')
end
[:substitute, :unaffected, :zero, :status, :nil_move].each do |bad|
  target.pbInitEffects(false)
  target.damageState.substitute = bad == :substitute
  target.damageState.unaffected = bad == :unaffected
  target.damageState.hpLost = bad == :zero ? 0 : 10
  move.damage = bad != :status
  hit.call(:ADAPTATION, user, target, bad == :nil_move ? nil : move, battle)
  check(multiplier(calc, user, target, move) == 1.0, "learned invalid hit #{bad}")
end
move.damage = true
target.damageState.substitute = target.damageState.unaffected = false
fixed = Battle::Move::FixedDamageMove.new(battle, :SONICBOOM)
hit.call(:ADAPTATION, user, target, fixed, battle)
check(fixed.pbCalcDamage(user, target) == :fixed && target.damageState.calcDamage == 21, 'fixed damage not half')
[:suppressed, :mold_breaker].each do |bad|
  target.active = bad != :suppressed
  battle.moldBreaker = bad == :mold_breaker
  fixed.pbCalcDamage(user, target)
  check(target.damageState.calcDamage == 41, "fixed bypass failed #{bad}")
end
battle.moldBreaker = false
user.ability = :FRUITFULCANOPY
[:normal, :status, :early_block, :miss, :protect].each do |mode|
  user.hp, user.mode = 40, mode
  move.damage = mode != :status
  before = battle.rolls
  check(user.pbUseMove([:UseMove, 0, move]) == :used, 'use return changed')
  check(user.hp == 65 && battle.rolls == before + 1, "not once per use #{mode}")
end
[:unable, :full, :fainted, :inactive, :heal_block_or_bond, :wrong_type, :roll_25].each do |bad|
  user.hp, user.mode, user.active, user.blocked = 40, :normal, true, false
  move.calcType, battle.roll = :GRASS, 24
  case bad
  when :unable then user.mode = :unable
  when :full then user.hp = user.totalhp
  when :fainted then user.hp = 0
  when :inactive then user.active = false
  when :heal_block_or_bond then user.blocked = true
  when :wrong_type then move.calcType = :NORMAL
  when :roll_25 then battle.roll = 25
  end
  before = user.hp
  user.pbUseMove([:UseMove, 0, move])
  check(user.hp == before, "healed despite #{bad}")
end
user.hp, user.active, user.blocked, user.mode = 1, true, false, :normal
user.totalhp = 3
move.calcType, battle.roll = nil, 24
user.pbUseMove([:UseMove, 0, move])
check(user.hp == 2, 'fallback type/minimum heal failed')
# Snatched status moves heal the actual user, never the original chooser.
user.totalhp, user.hp = 101, 40
snatcher = Battle::Battler.new(battle)
snatcher.ability = :FRUITFULCANOPY
user.snatcher = snatcher
before = battle.rolls
user.pbUseMove([:UseMove, 0, move])
check(user.hp == 40 && snatcher.hp == 65 && battle.rolls == before + 1, 'Snatch healed wrong user')
# The early-return fallback uses that same captured user exactly once.
user.mode = :early_block
snatcher.hp = 40
user.pbUseMove([:UseMove, 0, move])
check(user.hp == 40 && snatcher.hp == 65, 'blocked Snatch fallback healed wrong user')
pokemon = Pokemon.new
pokemon.species, pokemon.form = :MACHAMP, 1
check(pokemon.speciesName == 'Mahoraga', 'Mahoraga name missing')
pokemon.form = 0
check(pokemon.speciesName == 'Machamp', 'base species name changed')
puts 'MAHORAGA_TROPIUS_ABILITIES_UNIT_PASSED'
File.write('mahoraga-tropius-ability-result.txt', 'PASSED') if defined?(System)
exit
