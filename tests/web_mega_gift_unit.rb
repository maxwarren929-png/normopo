class PokemonGlobalMetadata; end
module CLINormanhurstGacha
  def self.available?; true; end
end
module EventHandlers
  def self.add(*args); end
end
module System
  class << self
    attr_accessor :clock
    def uptime; @clock || 0; end
  end
end
module GameData
  module Item
    Entry = Struct.new(:id, :mega) do
      def is_mega_stone?; mega; end
    end
    def self.each
      [Entry.new(:CHARIZARDITEX, true), Entry.new(:VENUSAURITEX, true),
       Entry.new(:HONCHKROWITE, true), Entry.new(:MEGARING, false), Entry.new(:REDORB, false), Entry.new(:POKEBALL, false)].each { |item| yield item }
    end
  end
end
class GiftBag
  attr_accessor :capacity
  attr_reader :items
  def initialize(capacity = 99); @capacity, @items = capacity, {}; end
  def has?(id); @items.key?(id); end
  def add(id)
    return false if @items.length >= @capacity
    @items[id] = (@items[id] || 0) + 1
    true
  end
end
load ENV.fetch('CLI_WEB_GIFT_SOURCE', 'web_mega_gift.rb')
$player = true
$game_temp = Struct.new(:in_battle).new(false)
$PokemonGlobal, $bag = PokemonGlobalMetadata.new, GiftBag.new
CLIWebMegaGift.grant
expected = { :CHARIZARDITEX => 1, :VENUSAURITEX => 1, :HONCHKROWITE => 1, :MEGARING => 1 }
raise 'gift incomplete or wrong items' unless $bag.items == expected && $PokemonGlobal.cli_web_mega_gift_received
System.clock = 3
CLIWebMegaGift.grant
raise 'duplicate gift' unless $bag.items == expected
$PokemonGlobal, $bag = PokemonGlobalMetadata.new, GiftBag.new(1)
CLIWebMegaGift.grant
raise 'full bag falsely marked complete' if $PokemonGlobal.cli_web_mega_gift_received
$bag.capacity = 99
System.clock = 6
CLIWebMegaGift.grant
raise 'retry duplicated items or missed gift' unless $bag.items == expected && $PokemonGlobal.cli_web_mega_gift_received
$PokemonGlobal, $bag = PokemonGlobalMetadata.new, GiftBag.new
$game_temp.in_battle = true
System.clock = 9
CLIWebMegaGift.grant
raise 'gift went to temporary battle bag' unless $bag.items.empty? && !$PokemonGlobal.cli_web_mega_gift_received
$game_temp.in_battle = false
CLIWebMegaGift.grant
raise 'post-battle grant missed' unless $bag.items == expected
$PokemonGlobal, $bag = PokemonGlobalMetadata.new, GiftBag.new
$PokemonGlobal.cli_web_mega_gift_received = true
System.clock = 12
CLIWebMegaGift.grant
raise 'legacy save did not get only the new stone' unless $bag.items == { :HONCHKROWITE => 1 } && $PokemonGlobal.cli_web_mega_gift_received
File.write('web-gift-result.txt', 'PASSED')
puts 'WEB_MEGA_GIFT_UNIT_PASSED'
exit
