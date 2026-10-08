# Original CLI abilities. These handlers only affect battlers whose compiled
# ability records select ADAPTATION or FRUITFULCANOPY; no species/global changes.
module CLIMahoragaTropiusAbilities
  def self.adapted?(target, move)
    moves = target.instance_variable_get(:@cli_adaptation_moves)
    return moves && moves[move.id]
  end

  def self.fruitful_canopy(user, move, battle)
    return if !user.hasActiveAbility?(:FRUITFULCANOPY) || !user.canHeal?
    type = move.calcType || move.pbCalcType(user)
    return if type != :GRASS || battle.pbRandom(100) >= 25
    battle.pbShowAbilitySplash(user)
    if user.pbRecoverHP([user.totalhp / 4, 1].max) > 0
      battle.pbDisplay(_INTL("{1}'s HP was restored.", user.pbThis))
    end
    battle.pbHideAbilitySplash(user)
  end

  module BattlerHooks
    # Runs on every new occupant, including Baton Pass, rather than putting
    # memory in PBEffects where it could be passed to the next Pokemon.
    def pbInitEffects(batonPass)
      @cli_adaptation_moves = {}
      super
    end

    # A separate context per invocation also permits called moves/Instruct.
    def pbUseMove(*args)
      previous = @cli_canopy_use
      @cli_canopy_use = {}
      begin
        super
      ensure
        @cli_canopy_use = previous
      end
    end

    # Core reaches this only after trying the move, spending PP and setting
    # calcType. Capture the final user, including Snatch, not the chosen user.
    def pbChangeUser(choice, move, user)
      actual_user = super
      if @cli_canopy_use
        @cli_canopy_use[:user] = actual_user
        @cli_canopy_use[:move] = move
      end
      actual_user
    end

    # Core invokes OnEndOfUsingMove for status as well as damaging moves,
    # even when accuracy/Protect fails. Leave that normal path untouched.
    def pbEffectsAfterMove(user, targets, move, numHits)
      @cli_canopy_use[:ended] = true if @cli_canopy_use
      super
    end

    # Global ability blocking, move-wide failure, or missing targets can
    # bypass pbEffectsAfterMove. They still used the move. Paralysis/sleep,
    # confusion and no PP never captured a user, so cannot trigger this.
    def pbEndTurn(choice)
      context = @cli_canopy_use
      if context && !context[:ended] && context[:user]
        context[:ended] = true
        CLIMahoragaTropiusAbilities.fruitful_canopy(context[:user], context[:move], @battle)
      end
      super
    end
  end

  # Fixed-damage moves bypass DamageCalcFromTarget entirely. Apply just this
  # ability after their normal calculation, retaining Raid shield adjustments.
  module FixedDamageHooks
    def pbCalcDamage(user, target, numTargets = 1)
      result = super
      if !@battle.moldBreaker && target.hasActiveAbility?(:ADAPTATION) &&
         CLIMahoragaTropiusAbilities.adapted?(target, self)
        target.damageState.calcDamage = [(target.damageState.calcDamage / 2.0).round, 1].max
      end
      result
    end
  end

  module PokemonNames
    def speciesName
      return _INTL("Mahoraga") if species == :MACHAMP && form == 1
      super
    end
  end

  module Installer
    def runPlugins(*args)
      result = super
      unless @cli_mahoraga_tropius_installed
        # DBK/Gen 9 aliases must capture the core/plugin methods, not our
        # prepends. Install only after all plugin aliases have been evaluated.
        Battle::Battler.prepend(CLIMahoragaTropiusAbilities::BattlerHooks)
        Battle::Move::FixedDamageMove.prepend(CLIMahoragaTropiusAbilities::FixedDamageHooks)
        Pokemon.prepend(CLIMahoragaTropiusAbilities::PokemonNames)
        @cli_mahoraga_tropius_installed = true
      end
      result
    end
  end
end

Battle::AbilityEffects::OnBeingHit.add(:ADAPTATION,
  proc { |ability, user, target, move, battle|
    next if !move || !move.damagingMove?
    state = target.damageState
    next if state.substitute || state.unaffected || state.hpLost <= 0
    moves = target.instance_variable_get(:@cli_adaptation_moves) || {}
    moves[move.id] = true
    target.instance_variable_set(:@cli_adaptation_moves, moves)
  }
)

# This ignorable callback inherits the engine's suppression and Mold Breaker
# checks. It reads memory without learning during damage calculation/AI probes.
Battle::AbilityEffects::DamageCalcFromTarget.add(:ADAPTATION,
  proc { |ability, user, target, move, mults, power, type|
    mults[:final_damage_multiplier] *= 0.5 if CLIMahoragaTropiusAbilities.adapted?(target, move)
  }
)

Battle::AbilityEffects::OnEndOfUsingMove.add(:FRUITFULCANOPY,
  proc { |ability, user, targets, move, battle|
    CLIMahoragaTropiusAbilities.fruitful_canopy(user, move, battle)
  }
)

PluginManager.singleton_class.prepend(CLIMahoragaTropiusAbilities::Installer)
