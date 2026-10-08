# Selected Mega abilities. PBS owns their forms and ability assignments.
# Register only new IDs; leave base abilities and DBK Mega presentation alone.

# The normal target damage handler is gated by abilityActive? and Mold Breaker
# in Essentials and DBK. Change final damage only, not power or effectiveness.
Battle::AbilityEffects::DamageCalcFromTarget.add(:THERMALARMOR,
  proc { |ability, user, target, move, mults, power, type|
    mults[:final_damage_multiplier] *= 0.5 if [:WATER, :GROUND].include?(type)
  }
)

# End-of-move dispatch gives one roll per target, not one per multi-hit strike.
# It runs before target switching and before the engine clears Mold Breaker.
# Require real HP loss on the last successful hit. totalHPLost also includes
# Substitute damage, so it cannot alone prove that the target lost actual HP.
# A later accuracy miss preserves the preceding successful hit's damage state.
# Limitation: earlier HP damage followed by a successful zero-HP final hit does
# not qualify. Avoid inventing a move-use latch or patching core battle methods.
Battle::AbilityEffects::OnEndOfUsingMove.add(:PLAGUEDOCTOR,
  proc { |ability, user, targets, move, battle|
    next if !user.hasActiveAbility?(:PLAGUEDOCTOR)
    next if !move.damagingMove? || move.calcType != :DARK
    targets.uniq.each do |target|
      next if target.fainted? || target.pbHasAnyStatus?
      next if target.damageState.protected || target.damageState.substitute
      next if target.damageState.hpLost <= 0
      # Match Poison Touch/Toxic Chain's secondary-effect protection, with no
      # contact requirement. Mold Breaker ignores Shield Dust, not Covert Cloak.
      next if target.hasActiveItem?(:COVERTCLOAK)
      next if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
      # The move argument preserves Safeguard and Substitute-bypass rules;
      # the helper also owns type, terrain and ability-based poison immunities.
      next if !target.pbCanPoison?(user, false, move)
      next if battle.pbRandom(100) >= 30
      battle.pbShowAbilitySplash(user)
      msg = nil
      if !Battle::Scene::USE_ABILITY_SPLASH
        msg = _INTL("{1}'s {2} poisoned {3}!", user.pbThis,
                    user.abilityName, target.pbThis(true))
      end
      target.pbPoison(user, msg, false)
      battle.pbHideAbilitySplash(user)
    end
  }
)
