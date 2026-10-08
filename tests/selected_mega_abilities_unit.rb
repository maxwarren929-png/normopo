# Standalone native Ruby preload harness. Does not start a real battle.
class Battle
  module Scene
    USE_ABILITY_SPLASH = true
  end
  module AbilityEffects
    class Registry
      def initialize; @handlers = {}; end
      def add(id, handler); @handlers[id] = handler; end
      def [](id); @handlers.fetch(id); end
    end
    DamageCalcFromTarget = Registry.new
    OnEndOfUsingMove = Registry.new
  end
end
load ENV.fetch('CLI_MEGA_ABILITIES_SOURCE', 'mega-abilities.rb')
thermal = Battle::AbilityEffects::DamageCalcFromTarget[:THERMALARMOR]
[:WATER, :GROUND, :FIRE, :FIGHTING].each do |type|
  mult = { :final_damage_multiplier => 1.0 }
  thermal.call(:THERMALARMOR, nil, nil, nil, mult, 80, type)
  expected = [:WATER, :GROUND].include?(type) ? 0.5 : 1.0
  raise 'wrong Thermal Armor type or multiplier' unless mult[:final_damage_multiplier] == expected
end
class AbilityProbeUser
  attr_accessor :active
  def initialize; @active = true; end
  def hasActiveAbility?(id); @active && id == :PLAGUEDOCTOR; end
end
class AbilityProbeMove
  attr_accessor :type, :damage
  def initialize; @type, @damage = :DARK, true; end
  def calcType; @type; end
  def damagingMove?; @damage; end
end
class AbilityProbeTarget
  attr_accessor :status, :poisons, :immune, :cloak, :dust, :dead
  attr_reader :damageState
  def initialize
    @damageState = Struct.new(:protected, :substitute, :hpLost).new(false, false, 10)
    @status, @poisons, @immune, @cloak, @dust, @dead = false, 0, false, false, false, false
  end
  def fainted?; @dead; end
  def pbHasAnyStatus?; @status; end
  def hasActiveItem?(id); @cloak && id == :COVERTCLOAK; end
  def hasActiveAbility?(id); @dust && id == :SHIELDDUST; end
  def pbCanPoison?(*args); !@immune; end
  def pbPoison(*args); @poisons += 1; @status = true; end
end
class AbilityProbeBattle
  attr_accessor :roll, :moldBreaker
  attr_reader :rolls
  def initialize; @roll, @rolls, @moldBreaker = 29, 0, false; end
  def pbRandom(max); @rolls += 1; @roll; end
  def pbShowAbilitySplash(*args); end
  def pbHideAbilitySplash(*args); end
end
plague = Battle::AbilityEffects::OnEndOfUsingMove[:PLAGUEDOCTOR]
user, move, battle = AbilityProbeUser.new, AbilityProbeMove.new, AbilityProbeBattle.new
target = AbilityProbeTarget.new
plague.call(:PLAGUEDOCTOR, user, [target, target], move, battle)
raise 'poison did not proc once per target' unless target.poisons == 1 && battle.rolls == 1
[:immune, :cloak, :dust, :dead, :status, :protected, :substitute, :zero_hp, :inactive, :wrong_type, :status_move, :roll_30].each do |blocker|
  target = AbilityProbeTarget.new
  user.active, move.type, move.damage, battle.roll = true, :DARK, true, 29
  case blocker
  when :protected, :substitute then target.damageState.send("#{blocker}=", true)
  when :zero_hp then target.damageState.hpLost = 0
  when :inactive then user.active = false
  when :wrong_type then move.type = :FLYING
  when :status_move then move.damage = false
  when :roll_30 then battle.roll = 30
  else target.send("#{blocker}=", true)
  end
  plague.call(:PLAGUEDOCTOR, user, [target], move, battle)
  raise "poison incorrectly procced with #{blocker}" unless target.poisons == 0
end
File.write('mega-ability-result.txt', 'PASSED')
puts 'SELECTED_MEGA_ABILITIES_UNIT_PASSED'
exit
