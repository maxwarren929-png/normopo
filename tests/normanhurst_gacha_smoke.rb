# Real-data checks after boot, also runnable with the small unit-test doubles.
module CLINormanhurstGachaSmoke
  def self.check(condition, message)
    raise "Normanhurst gacha: #{message}" unless condition
  end

  def self.run
    check(CLINormanhurstGacha.available?, "compiled edition gate unavailable")
    original = [$PokemonGlobal, $PokemonStorage, $bag, $player.party, $player.gacha_pity]
    original_dex = $player.instance_variable_get(:@pokedex)
    begin
      $PokemonGlobal = Marshal.load(Marshal.dump($PokemonGlobal))
      $PokemonGlobal.normanhurst_gacha_claimed = nil
      $PokemonGlobal.normanhurst_gacha_pulls_used = nil
      $PokemonStorage = PokemonStorage.new
      $bag = PokemonBag.new
      $player.party = []
      $player.gacha_pity = {}
      $player.instance_variable_set(:@pokedex, Marshal.load(Marshal.dump(original_dex))) if original_dex
      check(CLINormanhurstGacha.remaining == 30, "old saves must default to 30 remaining")
      $bag.define_singleton_method(:can_add?) { |*_args| false }
      check(!CLINormanhurstGacha.claim_tickets && !$PokemonGlobal.normanhurst_gacha_claimed,
            "full Bag consumed claim")
      $bag.singleton_class.send(:remove_method, :can_add?)
      check(CLINormanhurstGacha.claim_tickets && $bag.quantity(:GACHATICKET) == 30, "grant is not 30")
      check(!CLINormanhurstGacha.claim_tickets && $bag.quantity(:GACHATICKET) == 30, "repeat claim refilled tickets")
      keys = GachaConfig::BANNERS.keys
      check(keys == CLINormanhurstGacha::CATEGORIES.keys, "normal item/unevolved banners leaked")
      check(!GachaConfig::BANNERS.has_key?(:ITEM_PREMIUM_BANNER), "item banner selectable")
      check(!CLINormanhurstGacha.terminal_species?(:SHUCKLE), "Shuckle evolves to Shucklord")
      check(!CLINormanhurstGacha.terminal_species?(:RIOLU), "baby accepted")
      check(!CLINormanhurstGacha.terminal_species?(:PORYGON2), "intermediate accepted")
      keys.each do |id|
        banner = GachaConfig::BANNERS[id]
        check(banner[:pools].length >= 10, "curated pool too small: #{id}")
        check(banner[:pools].any? { |p| p[:is_main_prize] }, "missing legendary pity prize")
        banner[:pools].each do |prize|
          check(prize[:type] == :pokemon && CLINormanhurstGacha.terminal_species?(prize[:species]), "invalid final pool prize")
          check(!prize.key?(:form), "custom form configured")
        end
        $player.gacha_pity[id] = 9
        check(GachaLogic.roll_prize(id)[:is_main_prize] && $player.gacha_pity[id] == 0, "10-pull legendary pity")
        100.times do
          prize = GachaLogic.roll_prize(id)
          check(prize[:type] == :pokemon && CLINormanhurstGacha.terminal_species?(prize[:species]), "invalid final selection")
        end
      end
      id = keys.first
      [0, -1, 31, 1.5, nil].each { |n| check(!GachaLogic.pay_cost(id, n), "invalid payment accepted") }
      check(CLINormanhurstGacha.remaining == 30, "failed payments spent cap")
      check(!GachaLogic.pay_cost(:ITEM_PREMIUM_BANNER), "normal item banner charged")
      $bag.remove(:GACHATICKET, 30)
      check(!GachaLogic.pay_cost(id) && CLINormanhurstGacha.remaining == 30, "no-ticket attempt spent cap")
      $bag.add(:GACHATICKET, 30)
      check(GachaLogic.pay_cost(id) && CLINormanhurstGacha.remaining == 29, "single paid pull did not spend one")
      check(GachaLogic.pay_cost(keys[1], 10) && CLINormanhurstGacha.remaining == 19, "batch cap is not shared")
      _, pokemon = GachaLogic.give_prize(GachaLogic.roll_prize(id))
      check(pokemon && pokemon.form == 0, "ordinary reward form not preserved")
      prizes = GachaLogic.roll_multiple(keys[1], 10)
      _, details = GachaLogic.give_multiple_prizes(prizes)
      check(details.length == 10 && details.all? { |d| d[:pkmn].form == 0 }, "batch reward failed/changed forms")
      $PokemonGlobal = Marshal.load(Marshal.dump($PokemonGlobal))
      check($PokemonGlobal.normanhurst_gacha_claimed && CLINormanhurstGacha.remaining == 19, "claim/cap lost on save reload")
      check(!CLINormanhurstGacha.claim_tickets, "reload permits another grant")
      check(GachaLogic.pay_cost(keys[2], 10) && CLINormanhurstGacha.remaining == 9, "third banner cap not shared")
      check(!GachaLogic.pay_cost(id, 10) && CLINormanhurstGacha.remaining == 9, "batch overshot remaining cap")
      check(GachaLogic.pay_cost(id, 9) && CLINormanhurstGacha.remaining == 0, "last nine failed")
      $bag.add(:GACHATICKET, 50)
      check(!GachaLogic.pay_cost(id) && $bag.quantity(:GACHATICKET) == 50, "extra tickets bypass 30-pull cap")
      $PokemonGlobal = Marshal.load(Marshal.dump($PokemonGlobal))
      check(!GachaLogic.pay_cost(id) && !CLINormanhurstGacha.claim_tickets, "reload resets exhausted cap/claim")
      if defined?(GachaScene)
        previous_bgm = $game_system.getPlayingBGM
        scene = nil
        details_scene = nil
        begin
          keys.each do |banner_id|
            scene = GachaScene.new(banner_id)
            scene.pbStartScene
            scene.pbUpdate
            Graphics.update
            Graphics.screenshot("smoke-gacha-#{banner_id.to_s.downcase}.png")
            scene.pbEndScene
            scene = nil
            details_scene = GachaDetails_Scene.new
            details_scene.pbStartScene(banner_id)
            details_scene.pbUpdate
            Graphics.update
            Graphics.screenshot("smoke-gacha-rates-#{banner_id.to_s.downcase}.png")
            details_scene.pbEndScene
            details_scene = nil
          end
        ensure
          scene.pbEndScene if scene
          details_scene.pbEndScene if details_scene
          previous_bgm ? pbBGMPlay(previous_bgm) : pbBGMStop
        end
      end
      result = { "one_time_30_tickets" => true, "shared_paid_pull_cap" => 30,
        "claim_and_cap_marshal_roundtrip" => true, "pokemon_only_terminal_pools" => true,
        "ordinary_forms" => true, "legendary_pity" => 10 }
      PokeSmoke.instance_variable_get(:@results)["gacha"] = result if defined?(PokeSmoke)
      result
    ensure
      $PokemonGlobal, $PokemonStorage, $bag, $player.party, $player.gacha_pity = original
      $player.instance_variable_set(:@pokedex, original_dex)
    end
  end
end
