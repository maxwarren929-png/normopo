# Disposable native probe: load both rosters and inspect the real doubles start.
# It ends at the first command phase, not after a complete Elite Four battle.
require 'json'
module EliteDuoProbe
  def self.check(value, message)
    raise message unless value
  end
  def self.tick
    @ticks = (@ticks || 0)+1
    return if @done || !defined?(Scene_Map) || !$scene.is_a?(Scene_Map)
    @done = true
    begin
      index = CLINormanhurstGymTests::ROSTER.index { |r| r[:elite_four] }
      check(index, 'duo menu entry missing')
      trainers = CLINormanhurstGymTests.opponents(index)
      check(trainers.map(&:name) == ['Mr Lin','Mr Howel'], 'trainer identities')
      check(trainers.map { |t| t.party.map(&:species) } == [
        [:DRAGAPULT,:CHANDELURE,:TYRANITAR,:MUK,:GOODRA,:GARDEVOIR],
        [:NOIVERN,:TOXTRICITY,:EXPLOUD,:KOMMOO,:PRIMARINA,:SKELEDIRGE]], 'roster composition')
      check(trainers.all? { |t| t.party.length==6 && t.party.all? { |p| p.level==95 } }, 'levels/counts')
      tyranitar=trainers[0].party[2]
      check(tyranitar.item_id==:TYRANITARITE && tyranitar.getMegaForm==1, 'custom Mega eligibility')
      check(trainers[0].items.include?(:MEGARING), 'Lin Mega Ring')
      Battle.prepend(Module.new do
        def pbCommandPhase
          EliteDuoProbe.check(@opponent.map(&:name)==['Mr Lin','Mr Howel'], 'real battle trainers')
          EliteDuoProbe.check(pbSideSize(0)==2 && pbSideSize(1)==2, '2v2 battle size')
          EliteDuoProbe.check(@party2.length==12 && @party2starts==[0,6], 'separate six-Pokemon pools')
          EliteDuoProbe.check(@battlers[1].species==:DRAGAPULT && @battlers[3].species==:NOIVERN, 'one lead per trainer')
          EliteDuoProbe.check(pbHasMegaRing?(1), 'Lin Mega Ring in battle')
          @scene.pbRefresh
          Graphics.update
          Graphics.screenshot('elite-duo-battle.png')
          EliteDuoProbe.observed = true
          @decision=3
        end
      end)
      original=$player.party
      CLINormanhurstGymTests.battle(index, true)
      check(observed && $player.party.equal?(original), 'battle start/party restoration')
      File.write('elite-duo-report.json',JSON.pretty_generate({passed:true,trainers:trainers.map(&:name),party_counts:[6,6],level:95,custom_mega_eligible:true,real_double_start_verified:true,full_battle_playthrough:false}))
      exit
    rescue => e
      File.write('elite-duo-report.json',JSON.pretty_generate({passed:false,error:"#{e.class}: #{e.message}",backtrace:e.backtrace.first(8)}))
      exit 1
    end
  end
  class << self
    attr_accessor :observed
  end
  def self.press?(key)
    key==Input::USE && (@ticks||0)%10==0
  end
end
Object.prepend(Module.new do
  def pbMessage(message,*args,&block)
    return 0 if defined?(Scene_Map) && $scene.is_a?(Scene_Map)
    super
  end
end)
module Graphics
  class << self
    alias elite_duo_original_update update
    def update
      elite_duo_original_update
      EliteDuoProbe.tick
    end
  end
end
module Input
  class << self
    alias elite_duo_original_trigger trigger?
    def trigger?(key)
      EliteDuoProbe.press?(key) || elite_duo_original_trigger(key)
    end
  end
end
