# Chapter one. Later chapters are planned in docs/story.md.
module OzerimStory
  def self.state
    data = $PokemonGlobal.instance_variable_get(:@ozerim_story)
    unless data
      data = { :parcel => false, :cancelled => false, :defeated => false,
               :repaired => false, :delivered => false, :reported => false }
      $PokemonGlobal.instance_variable_set(:@ozerim_story, data)
    end
    data
  end

  def self.issue_parcel(name)
    return if state[:parcel] || state[:delivered]
    state[:parcel] = true
    pbMessage("#{name}: If you're heading past the station, could you drop these notes off for me? A colleague of mine is waiting outside the ticket hall.")
    pbMessage("#{name}: They've got a white coat on. Tell them I sent you.")
    pbMessage("You put the research parcel in your bag.")
  end

  def self.professor(name)
    issue_parcel(name)
    if state[:delivered] && !state[:reported]
      pbMessage("#{name}: Someone was deliberately damaging the signals? And they called themselves Team Ozerim?")
      pbMessage("#{name}: Let me see that report... Missing components. That explains the fault, at least.")
      pbMessage("#{name}: I'll make a few calls. Go home and get some rest. You've had quite a first day.")
      state[:reported] = true
    elsif state[:reported]
      pbMessage("#{name}: Still waiting to hear back. I'll let you know when I find out more.")
    elsif state[:delivered]
      pbMessage("#{name}: Thank you for delivering the research notes.")
    else
      pbMessage("#{name}: Thanks for taking those notes. They'd have sat on my desk all week otherwise.")
    end
  end

  def self.station_staff
    state[:cancelled] = true
    if state[:repaired]
      pbMessage("Station staff: We've had word that the signal's fixed. No departure time yet, though. They still have to check the line.")
    else
      pbMessage("Station staff: Travelling today? Sorry, nothing's running at the moment. Signal fault up the line.")
      pbMessage("Station staff: Someone's gone out to look at it. The walking track's still open if you're only going a short way.")
    end
  end

  def self.departure_board
    pbMessage(state[:repaired] ? "NEXT SERVICE: AWAITING SAFETY CHECKS\nSignal repaired. Please speak to station staff." : "NEXT SERVICE: CANCELLED\nSignal fault. Please speak to station staff.")
  end

  def self.colleague
    if state[:delivered]
      pbMessage("Research colleague: Thanks again for the notes. I hope your trip home was quieter than mine!")
      return
    end
    unless state[:parcel]
      pbMessage("Research colleague: Oh, hello. Do you know if there's been an announcement? I can't hear a thing over here.")
      return
    end
    unless state[:introduced]
      pbMessage("Research colleague: Hello. Can I help you?")
      return unless pbConfirmMessage("Mention the professor's parcel?")
      state[:introduced] = true
      pbMessage("Research colleague: Ah, those notes! Thank you. Give me a moment to make room in my case.")
    end
    unless state[:repaired]
      state[:cancelled] = true
      pbMessage("Research colleague: The staff said there's a signal fault. A technician went up the walking track, but I heard someone shouting a minute ago.")
      pbMessage("Research colleague: Could you see if they're all right? I'll keep an eye on things here.")
      return
    end
    state[:delivered] = true
    state[:parcel] = false
    pbMessage("You handed over the research parcel.")
    pbMessage("Research colleague: Someone was taking the signal apart? No wonder the technician sounded shaken.")
    pbMessage("Research colleague: They've sent a report through. Would you take a copy back to the professor? They ought to hear about this.")
    pbMessage("You take a copy of the technician's report.")
  end

  def self.travel(map_id, x, y, direction = 8, require_station = false)
    unless HomeSuburb.state[:supplies]
      pbMessage("You still have things to finish at the lab before heading out.")
      return
    end
    if require_station && !state[:cancelled]
      pbMessage("The path leads away from the station. You should check what's happening with the trains before leaving.")
      return
    end
    $game_temp.player_new_map_id = map_id
    $game_temp.player_new_x = x
    $game_temp.player_new_y = y
    $game_temp.player_new_direction = direction
    $scene.transfer_player
  end

  def self.grunt
    if state[:defeated]
      pbMessage("Ozerim grunt: Fine! I'm leaving the equipment alone. Don't think you've stopped the others.")
      return
    end
    pbMessage("Worker: Closed for maintenance. Keep walking.")
    pbMessage("Technician: Put that back! You don't even work here!")
    pbMessage("Worker: Oh, you've brought help? Fine. Let's see what that Pokemon can do.")
    return unless pbConfirmMessage("Stand up to the worker?")
    return pbMessage("Your Pokemon needs a rest. Mum can heal your team at home.") unless $player.party.any?(&:able?)
    opponent = NPCTrainer.new("Ozerim Grunt", :TEAMROCKET_M)
    opponent.party = [Pokemon.new(:RATTATA, 4, opponent)]
    opponent.lose_text = "I was told this would be an easy job!"
    rules = $game_temp.battle_rules.dup
    begin
      $game_temp.battle_rules.clear
      setBattleRule("single", "canLose", "noMoney", "noPartner")
      result = TrainerBattle.start_core(opponent)
    ensure
      $game_temp.battle_rules.replace(rules)
      $player.party.each(&:heal)
    end
    if result == 1
      state[:defeated] = true
      pbMessage("Ozerim grunt: I wasn't paid enough for this. Ozerim can send someone else next time.")
      pbMessage("Technician: Ozerim? Team Ozerim? What have they got to do with our signals?")
      pbMessage("Ozerim grunt: Ask them yourself. I'm done here.")
      pbMessage("Technician: Thanks for stepping in. Let me check your Pokemon, then I'll have a look at the damage.")
    else
      pbMessage("Technician: Here, let me help your Pokemon. Don't push yourself. That person isn't going anywhere just yet.")
    end
  end

  def self.technician
    unless state[:defeated]
      pbMessage("Technician: I came out to fix a fault, and found someone emptying the cabinet. Now they won't let me near it.")
      return
    end
    if state[:repaired]
      pbMessage("Technician: It's holding steady now. I've sent word back to the station.")
      return
    end
    state[:repaired] = true
    pbMessage("Technician: There it is. They'd pulled the components right out. Nothing wrong with the signal itself.")
    pbMessage("The technician replaces the components and radios the station.")
    pbMessage("Technician: I'll stay for the checks. Thanks again. I don't fancy having that argument twice.")
  end

  def self.signal
    pbMessage(state[:repaired] ? "The signal is working again. Services are awaiting safety checks." : "The signal cabinet is open. Several components are missing.")
  end
end
