# Only Normanhurst installs trainers_GymTests.txt. Shared engine code does not
# expose these names/teams in Hornsby or turn the test room into story gyms.
module CLINormanhurstGymTests
  ROSTER = [
    { :name => "Max", :gym => 1, :trainer_type => :LEADER_Cheren, :level => 15, :format => :single },
    { :name => "Ko", :gym => 2, :trainer_type => :LEADER_Brock, :level => 25, :format => :single },
    { :name => "Warren", :gym => 3, :trainer_type => :LEADER_Cilan, :level => 35, :format => :single },
    { :name => "Karna", :gym => 4, :trainer_type => :LEADER_Morty, :level => 45, :format => :double },
    { :name => "Oliver", :gym => 6, :trainer_type => :LEADER_Marlon, :level => 65, :format => :single },
    { :name => "Kaelan", :gym => 8, :trainer_type => :LEADER_Drayden, :level => 85, :format => :single },
    { :name => "Martin", :gym => nil, :trainer_type => :COOLTRAINER_M, :level => 55, :format => :single },
    { :name => "Isaac", :gym => 5, :trainer_type => :LEADER_Clay, :level => 55, :format => :single },
    { :name => "Mr Lin", :gym => nil, :trainer_type => :ELITEFOUR_Will,
      :partner_name => "Mr Howel", :partner_type => :ELITEFOUR_Lucian,
      :elite_four => true, :level => 95, :format => :double }
  ].map(&:freeze).freeze

  LOAN_TEAM = [
    [:RAICHU, [:THUNDERBOLT, :GRASSKNOT, :FOCUSBLAST, :PROTECT]],
    [:CHARIZARD, [:FLAMETHROWER, :AIRSLASH, :DRAGONPULSE, :PROTECT]],
    [:MILOTIC, [:SURF, :ICEBEAM, :RECOVER, :PROTECT]],
    [:LUCARIO, [:AURASPHERE, :FLASHCANNON, :DARKPULSE, :PROTECT]],
    [:GARCHOMP, [:DRAGONCLAW, :EARTHQUAKE, :ROCKSLIDE, :PROTECT]],
    [:VENUSAUR, [:ENERGYBALL, :SLUDGEBOMB, :SLEEPPOWDER, :PROTECT]]
  ].freeze

  def self.available?
    ROSTER.all? do |entry|
      GameData::Trainer.exists?(entry[:trainer_type], entry[:name], 0) &&
        (!entry[:partner_name] || GameData::Trainer.exists?(entry[:partner_type], entry[:partner_name], 0))
    end
  end

  def self.entry(index)
    raise ArgumentError, "Unknown gym test" unless index.is_a?(Integer) && index.between?(0, ROSTER.length - 1)
    ROSTER[index]
  end

  def self.opponent(index)
    data = entry(index)
    trainer = pbLoadTrainer(data[:trainer_type], data[:name])
    raise "Normanhurst gym test data is not installed" unless trainer
    trainer
  end

  def self.opponents(index)
    data = entry(index)
    trainers = [opponent(index)]
    if data[:partner_name]
      partner = pbLoadTrainer(data[:partner_type], data[:partner_name])
      raise "Normanhurst duo partner data is not installed" unless partner
      trainers << partner
    end
    trainers
  end

  def self.borrowed_party(level)
    LOAN_TEAM.map do |species, moves|
      pokemon = Pokemon.new(species, level, $player)
      pokemon.form = 0
      pokemon.item = nil
      pokemon.moves.clear
      moves.each { |move| pokemon.learn_move(move) }
      pokemon
    end
  end

  def self.level_matched_party(party, level)
    copies = Marshal.load(Marshal.dump(party))
    copies.each do |pokemon|
      next if pokemon.egg?
      pokemon.level = level
      pokemon.calc_stats
      pokemon.heal
    end
    copies
  end

  def self.menu
    return unless available?
    ordered = ROSTER.each_with_index.sort_by { |data, index| [data[:level], data[:gym] ? 0 : 1] }
    commands = ordered.map do |data, index|
      if data[:elite_four]
        "#{data[:name]} & #{data[:partner_name]} - Elite Four doubles, Lv. #{data[:level]}"
      else
        data[:gym] ? "#{data[:name]} - Gym #{data[:gym]}, Lv. #{data[:level]}" : "#{data[:name]} - Lv. #{data[:level]}"
      end
    end
    choice = pbMessage("Choose a test battle.", commands + ["Cancel"], commands.length + 1)
    return unless choice.between?(0, ordered.length - 1)
    index = ordered[choice][1]
    mode = pbMessage("Your team will match Lv. #{entry(index)[:level]} for this battle.", ["Use my party", "Borrow matching test team", "Cancel"], 3)
    return unless mode.between?(0, 1)
    battle(index, mode == 1)
  end

  def self.battle(index, borrow = true)
    return false unless available?
    data = entry(index)
    if !borrow && $player.party.count { |p| !p.egg? } < (data[:format] == :double ? 2 : 1)
      pbMessage(data[:format] == :double ? "You need two Pokemon for this double battle." : "You need a Pokemon first.")
      return false
    end
    original_party, original_bag, original_stats = $player.party, $bag, $stats
    original_dex = $player.instance_variable_get(:@pokedex)
    rules = $game_temp.battle_rules.dup
    battle_scene = $PokemonSystem.battlescene
    mega_disabled = $game_switches[Settings::NO_MEGA_EVOLUTION]
    begin
      # Fight with healed copies, never mutate the caller's Pokemon or Bag.
      $player.party = borrow ? borrowed_party(data[:level]) : level_matched_party(original_party, data[:level])
      $player.party.each { |pokemon| pokemon.heal }
      $bag = PokemonBag.new
      $stats = Marshal.load(Marshal.dump(original_stats))
      $player.instance_variable_set(:@pokedex, Marshal.load(Marshal.dump(original_dex))) if original_dex
      $PokemonSystem.battlescene = 0
      $game_switches[Settings::NO_MEGA_EVOLUTION] = false
      $game_temp.battle_rules.clear
      setBattleRule(data[:format] == :double ? "double" : "single", "setStyle",
                    "canLose", "noExp", "noMoney", "noBag", "noPartner", "outcome", -1)
      TrainerBattle.start_core(*opponents(index))
    ensure
      $player.party, $bag, $stats = original_party, original_bag, original_stats
      $player.instance_variable_set(:@pokedex, original_dex)
      $game_temp.battle_rules.replace(rules)
      $PokemonSystem.battlescene = battle_scene
      $game_switches[Settings::NO_MEGA_EVOLUTION] = mega_disabled
      if defined?(FollowingPkmn)
        FollowingPkmn.refresh_internal
        FollowingPkmn.refresh(false)
      end
    end
  end
end
