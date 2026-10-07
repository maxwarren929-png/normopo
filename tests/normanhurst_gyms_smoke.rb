# Loaded by runtime_smoke.rb after boot. Runs real, disposable trainer battles.
module CLINormanhurstGymsSmoke
  ROSTER = [
    ["Max",    1, :LEADER_Cheren, 15, :single, [[:MORPEKO, 0], [:DITTO, 0]]],
    ["Ko",     2, :LEADER_Brock,  25, :single, [[:SHUCKLORD, 0], [:PORYGON2, 0]]],
    ["Warren", 3, :LEADER_Cilan,  35, :single, [[:SYLVEON, 0], [:VAPOREON, 0], [:GARDEVOIR, 2]]],
    ["Karna",  4, :LEADER_Morty,  45, :double, [[:GALLADE, 2], [:GARDEVOIR, 3], [:GENGAR, 0]]],
    ["Oliver", 6, :LEADER_Marlon, 65, :single, [[:LEAFEON, 0], [:LAPRAS, 0], [:BLASTOISE, 0]]],
    ["Kaelan", 8, :LEADER_Drayden,85, :single, [[:NOIVERN, 0], [:GLACEON, 0], [:ABSOL, 3]]],
    ["Martin", nil, :COOLTRAINER_M,55, :single, [[:DRAGONITE, 0]]]
  ].freeze

  def self.check(condition, message)
    raise "Normanhurst gyms: #{message}" unless condition
  end

  def self.active?
    !@spec.nil?
  end

  def self.install_hook
    return if @hooked
    Battle.prepend(Module.new do
      def pbCommandPhase
        return super unless CLINormanhurstGymsSmoke.active?
        CLINormanhurstGymsSmoke.command_phase(self)
        @decision = 3
      end
    end)
    @hooked = true
  end

  def self.composition(party)
    party.map { |pkmn| [pkmn.species, pkmn.form] }
  end

  def self.capture(battle, filename)
    battle.scene.pbRefresh
    Graphics.update
    Graphics.screenshot(filename)
  end

  def self.command_phase(battle)
    name, gym, trainer_type, level, format, team = @spec
    check(!@observed, "#{name}: command probe ran twice")
    @observed = true
    check(battle.trainerBattle?, "#{name}: not a trainer battle")
    opponent = battle.opponent[0]
    check(opponent.name == name && opponent.trainer_type == trainer_type,
          "#{name}: wrong real trainer opponent")
    check(composition(battle.pbParty(1)) == team, "#{name}: battle party/forms differ from PBS")
    size = format == :double ? 2 : 1
    check(battle.pbSideSize(0) == size && battle.pbSideSize(1) == size,
          "#{name}: expected #{format} battle")
    check(battle.respond_to?(:noBag) && battle.noBag, "#{name}: Bag is not disabled")
    check(!battle.expGain && !battle.moneyGain && battle.canLose,
          "#{name}: practice must disable experience/money and allow loss")
    borrowed = battle.pbParty(0)
    if @own_mode
      check(composition(borrowed) == composition(@original_party), "own-party species/forms changed")
      check(borrowed.all? { |pkmn| pkmn.hp == pkmn.totalhp && pkmn.status == :NONE }, "own-party copies were not healed")
      check(borrowed.all? { |pkmn| pkmn.egg? || pkmn.level == level }, "own-party copies did not match opponent level")
    else
      check(borrowed.length == 6 && borrowed.all? { |pkmn| pkmn.level == level && pkmn.form == 0 },
            "#{name}: borrowed party must contain six base-form Pokemon at level #{level}")
    end
    check(borrowed.none? { |pkmn| @original_party.include?(pkmn) },
          "#{name}: borrowed battle reused original Pokemon")
    if format == :double
      check(composition([battle.battlers[1].pokemon, battle.battlers[3].pokemon]) == team.first(2),
            "#{name}: custom Gallade/Gardevoir are not the double leads")
    end
    battle.pbCalculatePriority
    foe = battle.battlers[1]
    if name == "Oliver"
      check(foe.species == :LEAFEON, "Oliver: initial lead is not Leafeon")
      battle.pbRecallAndReplace(1, 2)
      battle.pbOnBattlerEnteringBattle(1)
      battle.pbCalculatePriority
      foe = battle.battlers[1]
      check(foe.species == :BLASTOISE && foe.item_id == :BLASTOISINITE && foe.form == 0,
            "Oliver: last-slot Blastoise/stone switch failed")
      check(battle.pbCanMegaEvolve?(1), "Oliver: normal enemy Mega eligibility failed")
      battle.pbRegisterMegaEvolution(1)
      battle.pbMegaEvolve(1) # Real DBK animation and callbacks, no forced form.
      check(foe.mega? && foe.form == 1 && foe.pokemon.form == 1,
            "Oliver: real enemy Mega did not produce Mega Blastoise form 1")
      @results["oliver_dbk_mega_blastoise"] = true
    end
    # A called move still runs damage calculation, animations and ability hooks.
    # Swift cannot randomly miss these leads; no fabricated hit or reward calls.
    hp = foe.hp
    battle.battlers[0].pbUseMoveSimple(:SWIFT, foe.index)
    check(foe.hp < hp && foe.damageState.hpLost > 0 && !foe.damageState.substitute,
          "#{name}: first actual move did not damage the opponent")
    capture(battle, "smoke-gym-#{name.downcase}.png")
    @results[name.downcase] = { "gym" => gym, "level" => level,
      "format" => format.to_s, "actual_move" => true }
  end

  def self.assert_restored(party_dump, bag_dump, stats_dump, rules)
    check($player.party.equal?(@original_party) && Marshal.dump($player.party) == party_dump,
          "original party changed")
    check($bag.equal?(@original_bag) && Marshal.dump($bag) == bag_dump, "original Bag changed")
    check($stats.equal?(@original_stats) && Marshal.dump($stats) == stats_dump,
          "original statistics changed")
    check($game_temp.battle_rules == rules, "original battle rules changed")
  end

  def self.summary_ui_checks
    [[:GALLADE, 2], [:GARDEVOIR, 3], [:GARDEVOIR, 2], [:ABSOL, 3], [:VENUSAUR, 2]].each do |species, form|
      pokemon = Pokemon.new(species, 30, $player)
      pokemon.form = form
      pokemon.status = :BONDOFLIFE if species == :ABSOL
      scene = PokemonSummary_Scene.new
      begin
        scene.pbStartScene([pokemon], 0)
        scene.instance_variable_set(:@page, 3)
        scene.drawPage(3)
        scene.pbUpdate
        Graphics.update
        Graphics.screenshot("smoke-ability-#{species.to_s.downcase}-#{form}.png")
      ensure
        scene.pbEndScene
      end
    end
    @results["compact_ability_summary_screens"] = true
  end

  def self.run
    smoke_results = PokeSmoke.instance_variable_get(:@results)
    present = defined?(GameData::Trainer) && GameData::Trainer.exists?(:LEADER_Cheren, "Max")
    unless present
      check(!defined?(CLINormanhurstGymTests) || !CLINormanhurstGymTests.available?,
            "gym helper is available without Normanhurst trainer data")
      result = { "skipped" => "Normanhurst gym trainer data unavailable" }
      smoke_results["normanhurst_gyms"] = result
      return result
    end
    check(defined?(CLINormanhurstGymTests), "missing integration module CLINormanhurstGymTests")
    [:available?, :opponent, :battle, :borrowed_party].each do |method|
      check(CLINormanhurstGymTests.respond_to?(method), "missing integration API .#{method}")
    end
    check(CLINormanhurstGymTests.available?, "gym helper unavailable despite Max PBS trainer")
    check(CLINormanhurstGymTests.const_defined?(:ROSTER), "missing integration ROSTER")
    roster = CLINormanhurstGymTests::ROSTER
    expected = ROSTER.map do |name, gym, type, level, format, team|
      { :name => name, :gym => gym, :trainer_type => type, :level => level, :format => format }
    end
    check(roster == expected, "ROSTER differs from six gyms and Martin's Dragonite challenge")
    install_hook
    @original_party, @original_bag, @original_stats = $player.party, $bag, $stats
    party_dump = Marshal.dump(@original_party)
    bag_dump = Marshal.dump(@original_bag)
    stats_dump = Marshal.dump(@original_stats)
    rules = $game_temp.battle_rules.dup
    pokedex = $player.instance_variable_get(:@pokedex)
    phase = PokeSmoke.instance_variable_get(:@phase)
    mega_disabled = $game_switches[Settings::NO_MEGA_EVOLUTION]
    money = $player.money
    @results = {}
    begin
      # Encounter/Mega counters and seen flags belong to disposable test copies.
      $stats = Marshal.load(stats_dump)
      $player.instance_variable_set(:@pokedex, Marshal.load(Marshal.dump(pokedex))) if pokedex
      $game_switches[Settings::NO_MEGA_EVOLUTION] = false
      PokeSmoke.instance_variable_set(:@phase, :battle)
      summary_ui_checks
      ROSTER.each_with_index do |spec, index|
        name, gym, type, level, format, team = spec
        loaded = pbLoadTrainer(type, name)
        check(loaded && composition(loaded.party) == team, "#{name}: PBS party/forms mismatch")
        check(loaded.party.all? { |pkmn| pkmn.level == level }, "#{name}: PBS levels mismatch")
        trainer = CLINormanhurstGymTests.opponent(index)
        check(trainer.name == name && trainer.trainer_type == type && composition(trainer.party) == team,
              "#{name}: .opponent does not match loaded PBS trainer")
        if name == "Oliver"
          check(loaded.party.last.item_id == :BLASTOISINITE && trainer.party.last.item_id == :BLASTOISINITE,
                "Oliver: PBS or opponent missing Blastoisinite")
        end
        party = CLINormanhurstGymTests.borrowed_party(level)
        check(party.length == 6 && party.all? { |pkmn| pkmn.form == 0 && pkmn.level == level && !pkmn.fainted? },
              "#{name}: borrowed_party is not six healthy base Pokemon at requested level")
        @spec, @observed = spec, false
        CLINormanhurstGymTests.battle(index, true)
        check(@observed, "#{name}: .battle did not reach real scene/command initialization")
        @spec = nil
        check($player.party.equal?(@original_party) && Marshal.dump($player.party) == party_dump,
              "#{name}: .battle failed to restore original party")
        check($bag.equal?(@original_bag) && Marshal.dump($bag) == bag_dump,
              "#{name}: .battle failed to restore original Bag")
        check($game_temp.battle_rules == rules, "#{name}: .battle failed to restore rules")
        check($player.money == money, "#{name}: practice changed player money")
      end
      # Also exercise own-party mode with injured/statused originals and a
      # double battle. Only temporary copies may be healed or damaged.
      boot_party = @original_party
      own_party = [Pokemon.new(:RAICHU, 45, $player), Pokemon.new(:MILOTIC, 45, $player)]
      own_party[0].hp = 1
      own_party[0].status = :POISON
      own_dump = Marshal.dump(own_party)
      begin
        $player.party = @original_party = own_party
        @own_mode = true
        @spec, @observed = ROSTER[3], false
        CLINormanhurstGymTests.battle(3, false)
        check(@observed, "own-party battle did not initialize")
        check($player.party.equal?(own_party) && Marshal.dump(own_party) == own_dump, "own-party battle changed originals")
        @results["own_party_copies_and_restoration"] = true
      ensure
        $player.party = @original_party = boot_party
        @own_mode = false
      end
    ensure
      @spec = nil
      $stats = @original_stats
      $player.instance_variable_set(:@pokedex, pokedex)
      $game_switches[Settings::NO_MEGA_EVOLUTION] = mega_disabled
      PokeSmoke.instance_variable_set(:@phase, phase)
    end
    assert_restored(party_dump, bag_dump, stats_dump, rules)
    @results["original_party_bag_stats_rules_restored"] = true
    smoke_results["normanhurst_gyms"] = @results
    @results
  end
end
