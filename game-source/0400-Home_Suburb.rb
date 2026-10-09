# Shared opening for Normanhurst and Hornsby. State is serialized in the save.
module HomeSuburb
  STARTERS = [
    [:BULBASAUR, :CHIKORITA, :TREECKO, :TURTWIG, :SNIVY, :CHESPIN, :ROWLET, :GROOKEY, :SPRIGATITO],
    [:CHARMANDER, :CYNDAQUIL, :TORCHIC, :CHIMCHAR, :TEPIG, :FENNEKIN, :LITTEN, :SCORBUNNY, :FUECOCO],
    [:SQUIRTLE, :TOTODILE, :MUDKIP, :PIPLUP, :OSHAWOTT, :FROAKIE, :POPPLIO, :SOBBLE, :QUAXLY]
  ].map(&:freeze).freeze
  TYPES = ["Grass", "Fire", "Water"].freeze

  def self.state
    data = $PokemonGlobal.instance_variable_get(:@home_suburb_story)
    unless data
      data = { :offers => STARTERS.map { |pool| pool.sample }, :chosen => nil,
               :rival => nil, :battled => false, :supplies => false, :welcomed => false }
      $PokemonGlobal.instance_variable_set(:@home_suburb_story, data)
    end
    data
  end

  def self.initialize_player(name)
    if $player.character_ID < 1
      pbChangePlayer(1)
      pbTrainerName("Player")
    end
    $game_player.refresh_charset
    $game_player.opacity = 255
    state
    unless state[:welcomed]
      state[:welcomed] = true
      pbMessage("Mum: Up already? #{name} asked you to pop into the lab today. Don't leave them waiting.")
      pbMessage("Mum: Your friend knocked earlier. They've gone on ahead.")
      pbMessage("Mum: I'm walking to the shops. The train's cancelled again, apparently.")
    end
  end

  def self.mum(name)
    if state[:chosen]
      pbMessage("Mum: Look at you and your new partner! Take a rest before you head out.")
      $player.party.each(&:heal)
    else
      pbMessage("Mum: Haven't you left yet? Go on. Tell #{name} I said hello.")
    end
  end

  def self.talk(name)
    if state[:supplies]
      OzerimStory.professor(name)
    elsif state[:chosen]
      if state[:battled]
        supplies(name)
      else
        pbMessage("#{name}: Your rival is eager for a battle! Talk to them when you're ready.")
      end
    else
      pbMessage("#{name}: There you are! Come in. I've got something for the two of you.")
      pbMessage("#{name}: These three came from different regions. Grass, Fire and Water. Have a look, and choose a partner.")
      options = state[:offers].each_with_index.map { |species, i| "#{GameData::Species.get(species).name} (#{TYPES[i]})" }
      choice = pbMessage("#{name}: Which Pokemon would you like?", options + ["I'll think about it"], 4)
      choose(choice, name) if choice >= 0 && choice < 3
    end
  end

  def self.choose(index, name)
    if state[:chosen]
      pbMessage("#{name}: You've already chosen your partner.")
      return
    end
    species = state[:offers][index]
    display_name = GameData::Species.get(species).name
    return unless pbConfirmMessage("Choose #{display_name}, the #{TYPES[index]}-type Pokemon?")
    if $player.party.length >= Settings::MAX_PARTY_SIZE
      pbMessage("#{name}: Make room in your party first.")
      return
    end
    return unless pbAddPokemonSilent(species, 5)
    state[:chosen] = species
    state[:rival] = state[:offers][[1, 2, 0][index]]
    pbMessage("#{name}: #{display_name} is yours! Take good care of each other.")
    pbMessage("Rival: Then I'll take #{GameData::Species.get(state[:rival]).name}! Come on, let's try a battle!")
  end

  def self.ball(index, name)
    if state[:chosen]
      pbMessage("#{name}: You've made your choice. The other Pokemon are staying with us.")
      return
    end
    species = state[:offers][index]
    pbMessage("This Poke Ball contains #{GameData::Species.get(species).name}, a #{TYPES[index]}-type Pokemon.")
    choose(index, name)
  end

  def self.rival(name)
    unless state[:chosen]
      pbMessage("Rival: Finally! I walked here after they cancelled my train. Still beat you.")
      pbMessage("Rival: #{name} says you get first pick. Save a good one for me.")
      return
    end
    if state[:battled]
      pbMessage("Rival: I need to practise. Don't get too far ahead of me.")
      supplies(name) unless state[:supplies]
      return
    end
    return unless pbConfirmMessage("Rival: Ready for our first Pokemon battle?")
    trainer_type = :POKEMONTRAINER_Red
    if defined?(CLINormanhurstGacha) && CLINormanhurstGacha.available? && $game_map.map_id == 202
      trainer_type = :RIVAL1
    end
    opponent = NPCTrainer.new("Rival", trainer_type)
    opponent.party = [Pokemon.new(state[:rival], 5, opponent)]
    opponent.lose_text = "That was close! We'll have a rematch soon!"
    original_rules = $game_temp.battle_rules.dup
    begin
      $player.party.each(&:heal)
      $game_temp.battle_rules.clear
      setBattleRule("single", "canLose", "noMoney", "noPartner")
      result = TrainerBattle.start_core(opponent)
      state[:battled] = true if [1, 2, 5].include?(result)
    ensure
      $game_temp.battle_rules.replace(original_rules)
      $player.party.each(&:heal)
    end
    supplies(name) if state[:battled]
  end

  def self.supplies(name)
    return if state[:supplies]
    $player.has_pokedex = true
    $player.pokedex.unlock(-1)
    $bag.add(:POKEBALL, 5)
    $bag.add(:POTION, 3)
    state[:supplies] = true
    pbMessage("#{name}: All right, that's enough for today. Let me get those two patched up.")
    pbMessage("#{name}: Here. A Pokedex, some Poke Balls and a few Potions. You'll need them once you start exploring.")
    OzerimStory.issue_parcel(name)
  end
end
