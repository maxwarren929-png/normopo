# Optional live integration test, passed through mkxp-z's preloadScript setting.
# Run only in a disposable game copy. This drives the game without desktop keys.
# It is not part of the game or any packaged runtime.
begin
  require "json"
rescue LoadError
  # Essentials' bundled Windows runtime ships no Ruby standard library. This
  # covers only the plain JSON this probe reads and writes.
  module JSON
    def self.generate(value, indent = nil, depth = 0)
      pad = indent ? "\n" + indent * (depth + 1) : ""
      close = indent ? "\n" + indent * depth : ""
      case value
      when Hash
        return "{}" if value.empty?
        "{" + value.map { |k, v| pad + generate(k.to_s) + (indent ? ": " : ":") + generate(v, indent, depth + 1) }.join(",") + close + "}"
      when Array
        return "[]" if value.empty?
        "[" + value.map { |v| pad + generate(v, indent, depth + 1) }.join(",") + close + "]"
      when String, Symbol
        '"' + value.to_s.gsub(/["\\\u0000-\u001f]/) { |c| c == '"' || c == "\\" ? "\\" + c : format("\\u%04x", c.ord) } + '"'
      when nil then "null"
      when Float then value.finite? ? value.to_s : "null"
      else value.to_s
      end
    end

    def self.pretty_generate(value)
      generate(value, "  ")
    end

    def self.parse(text)
      @text = text
      @pos = 0
      value = parse_value
      skip_space
      raise ArgumentError, "trailing JSON at #{@pos}" if @pos < @text.length
      value
    end

    def self.skip_space
      @pos += 1 while @pos < @text.length && " \t\r\n".include?(@text[@pos])
    end

    def self.parse_value
      skip_space
      case @text[@pos]
      when "{"
        @pos += 1
        result = {}
        skip_space
        return (@pos += 1) && result if @text[@pos] == "}"
        loop do
          skip_space
          key = parse_value
          skip_space
          raise ArgumentError, "expected : at #{@pos}" unless @text[@pos] == ":"
          @pos += 1
          result[key] = parse_value
          skip_space
          @pos += 1
          return result if @text[@pos - 1] == "}"
          raise ArgumentError, "expected , at #{@pos - 1}" unless @text[@pos - 1] == ","
        end
      when "["
        @pos += 1
        result = []
        skip_space
        return (@pos += 1) && result if @text[@pos] == "]"
        loop do
          result << parse_value
          skip_space
          @pos += 1
          return result if @text[@pos - 1] == "]"
          raise ArgumentError, "expected , at #{@pos - 1}" unless @text[@pos - 1] == ","
        end
      when '"'
        @pos += 1
        result = +""
        until @text[@pos] == '"'
          char = @text[@pos]
          raise ArgumentError, "unterminated JSON string" if char.nil?
          if char == "\\"
            escape = @text[@pos + 1]
            if escape == "u"
              result << @text[@pos + 2, 4].to_i(16).chr(Encoding::UTF_8)
              @pos += 6
              next
            end
            result << ({"n" => "\n", "t" => "\t", "r" => "\r", "b" => "\b", "f" => "\f"}[escape] || escape)
            @pos += 2
          else
            result << char
            @pos += 1
          end
        end
        @pos += 1
        result
      else
        token = @text[@pos..][/\A(?:true|false|null|-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)/]
        raise ArgumentError, "invalid JSON at #{@pos}" unless token
        @pos += token.length
        {"true" => true, "false" => false, "null" => nil}.fetch(token) { token.match?(/[.eE]/) ? token.to_f : token.to_i }
      end
    end
  end
end
$stdout.sync = true

module PokeSmoke
  @ticks = 0
  @phase = :menu
  @pulse = false
  @results = { "ruby" => RUBY_VERSION, "mkxp_z" => System::VERSION }

  def self.finish(error = nil)
    @results["error"] = error if error
    @results["passed"] = error.nil?
    File.write("smoke-results.json", JSON.pretty_generate(@results) + "\n")
    puts "POKE_SMOKE #{@results.inspect}"
    exit(error ? 1 : 0)
  end

  def self.run_bitmap_font_tests
    return unless defined?(CLIBitmapFonts)
    bitmap = Bitmap.new(240, 90)
    copy = Bitmap.new(240, 90)
    viewport = Viewport.new(0, 0, 240, 90)
    sprite_text = nil
    owned_text = nil
    begin
      pbSetSystemFont(bitmap)
      bitmap.text_offset_y = 0
      bitmap.font.color = Color.new(17, 33, 49)
      data = CLIBitmapFonts.definition(bitmap.font)
      raise "Bitmap font not selected" unless data
      raise "FireRed atlas not selected" unless data["filename"] == "cliFirered"
      [[16, "cliFireredTiny"], [21, "cliFireredSmall"], [36, "cliFireredLarge"]].each do |size, filename|
        bitmap.font.size = size
        raise "Incorrect font size variant" unless CLIBitmapFonts.definition(bitmap.font)["filename"] == filename
      end
      pbSetSystemFont(bitmap)
      bitmap.text_offset_y = 0
      raise "Accented glyph still substitutes plain e" if CLIBitmapFonts.glyph("é", data) == CLIBitmapFonts.glyph("e", data)
      raise "Gender symbol still uses hand-drawn substitute" unless data.key?("♀") && data.key?("♂")
      expected = data["advances"]["A"] + data["advances"][" "] + data["advances"]["B"]
      raise "Glyph measurements disagree" unless bitmap.text_size("A B").width == expected
      raise "Multiline height" unless bitmap.text_size("A\nB").height == data["height"] * 2 + 2
      raise "Accented/symbol text unavailable" unless CLIBitmapFonts.supported?("Pokémon ♀♂ × …", data)
      before = CLIBitmapFonts.draw_calls
      bitmap.draw_text(0, 0, 240, 90, "Pokémon ♀♂")
      raise "TTF used instead of PNG" unless CLIBitmapFonts.draw_calls == before + 1
      ink = 0
      bitmap.height.times do |y|
        bitmap.width.times do |x|
          pixel = bitmap.get_pixel(x, y)
          next if pixel.alpha == 0
          raise "Anti-aliased bitmap text" unless pixel.alpha == 255
          raise "Wrong glyph tint" unless [pixel.red, pixel.green, pixel.blue] == [17, 33, 49]
          ink += 1
        end
      end
      raise "Empty bitmap glyphs" unless ink > 0
      bitmap.clear
      copy.font = bitmap.font.clone
      copy.text_offset_y = 0
      bitmap.draw_text(Rect.new(0, 0, 240, 90), "AB", 2)
      copy.draw_text(0, 0, 240, 90, "AB", 2)
      bitmap.height.times do |y|
        bitmap.width.times do |x|
          raise "Rect overload/alignment differs" unless bitmap.get_pixel(x, y) == copy.get_pixel(x, y)
        end
      end
      bitmap.clear
      before = CLIBitmapFonts.draw_calls
      pbDrawShadowText(bitmap, 0, 0, 240, 90, "AB", Color.new(1, 2, 3), Color.new(4, 5, 6))
      raise "Drop shadow still draws duplicate glyphs" unless CLIBitmapFonts.draw_calls == before + 1
      before = CLIBitmapFonts.draw_calls
      chunks = [["AB", 0, 0, bitmap.text_size("AB").width, 32, Color.new(1, 2, 3)]]
      renderLineBrokenChunksWithShadow(bitmap, 0, 0, chunks, 32, Color.new(1, 2, 3), Color.new(4, 5, 6))
      raise "Wrapped text still draws duplicate shadows" unless CLIBitmapFonts.draw_calls == before + 1
      before = CLIBitmapFonts.fallback_calls
      bitmap.draw_text(0, 30, 240, 30, "漢")
      raise "Missing-glyph fallback unavailable" unless CLIBitmapFonts.fallback_calls == before + 1
      sprite_text = BitmapText.new("A\nB", nil, nil, viewport, nil, 1)
      raise "Sprite multiline sizing" unless sprite_text.getHeight("A\nB") == data["height"] * 2 + 2
      sprite_text.update("Pokémon")
      sprite_text.dispose
      sprite_text.dispose
      raise "Caller viewport disposed" if viewport.disposed?
      owned_text = BitmapText.new("AB", 0, 0, nil, $PowerClear36, 1, Color.new(20, 40, 60))
      owned_viewport = owned_text.instance_variable_get(:@viewport)
      owned_bitmap = owned_text.instance_variable_get(:@sprite).bitmap
      owned_text.dispose
      raise "Owned bitmap/viewport leaked" unless owned_viewport.disposed? && owned_bitmap.disposed?
      @results["bitmap_fonts"] = {"style" => "FireRed", "png_renderer" => true, "binary_alpha" => true,
        "measurements" => true, "unicode" => true, "fallback" => true,
        "sprite_update_disposal" => true}
    ensure
      sprite_text.dispose if sprite_text && !sprite_text.disposed?
      owned_text.dispose if owned_text && !owned_text.disposed?
      bitmap.dispose
      copy.dispose
      viewport.dispose unless viewport.disposed?
    end
  end

  def self.warren_battle_test?
    @warren_battle_test
  end

  def self.check_warren_battle(battle)
    user, target = battle.battlers[0], battle.battlers[1]
    battle.pbCalculatePriority
    user.hp = user.totalhp / 2
    start_hp = user.hp
    target_hp = target.hp
    user.pbUseMoveSimple(:SALONSOLITARE, 1)
    damage = target_hp - target.hp
    expected = [start_hp + (damage / 2.0).round, user.totalhp].min
    finish("Salon Solitare did not deal damage") unless damage > 0
    finish("Salon Solitare did not heal half damage") unless user.hp == expected
    @results["warren_gardevoir"]["battle_damage"] = damage
    @results["warren_gardevoir"]["battle_healing"] = user.hp - start_hp
    Graphics.screenshot("smoke-warren-gardevoir-battle.png")
  end

  def self.run_warren_tests
    pokemon = Pokemon.new(:GARDEVOIR, 30, $player)
    pokemon.form = 2
    finish("Warren's Gardevoir typing wrong") unless pokemon.types == [:WATER, :FEMBOY]
    expected = { :HP => 88, :ATTACK => 55, :DEFENSE => 75, :SPECIAL_ATTACK => 110, :SPECIAL_DEFENSE => 110, :SPEED => 70 }
    finish("Warren's Gardevoir stats wrong") unless pokemon.baseStats == expected
    finish("Warren's Gardevoir ability wrong") unless pokemon.ability_id == :FANFAREGAUGE
    finish("Warren's Gardevoir has unrelated Mega form") if pokemon.hasMegaForm?
    finish("Warren's Gardevoir NPC missing") unless $game_map.events[14] || (defined?(CLINormanhurstGacha) && CLINormanhurstGacha.available?)
    move = GameData::Move.get(:SALONSOLITARE)
    finish("Salon Solitare move data wrong") unless move.type == :WATER && move.power == 70 && move.category == 1 && move.function_code == "HealUserByHalfOfDamageDone"
    [pokemon.totalhp, pokemon.totalhp / 2, 1].each do |hp|
      pokemon.hp = hp
      mults = { :final_damage_multiplier => 1.0 }
      Battle::AbilityEffects::DamageCalcFromUser[:FANFAREGAUGE].call(:FANFAREGAUGE, pokemon, nil, nil, mults, 70, :WATER)
      finish("Fanfare Gauge scaling wrong") unless (mults[:final_damage_multiplier] - (1 + 0.5 * hp.to_f / pokemon.totalhp)).abs < 0.000001
    end
    pokemon.heal
    @results["warren_gardevoir"] = { "form" => 2, "typing" => pokemon.types, "stats" => pokemon.baseStats, "ability_scaling" => true }
    scene = PokemonSummary_Scene.new
    scene.pbStartScene([pokemon], 0)
    scene.pbUpdate
    Graphics.update
    Graphics.screenshot("smoke-warren-gardevoir.png")
    scene.pbEndScene
    Battle.prepend(Module.new do
      def pbCommandPhase
        return super unless PokeSmoke.warren_battle_test?
        PokeSmoke.check_warren_battle(self)
        @decision = 3
      end
    end)
    begin
      @warren_battle_test = true
      @phase = :battle
      CLIDemo.with_practice_raichu do
        $player.party = [pokemon]
        WildBattle.start_core(:LECHONK, 50)
      end
    ensure
      @warren_battle_test = false
      @phase = :ui_test
    end
  end

  def self.run_gacha_tests
    if defined?(CLINormanhurstGacha) && CLINormanhurstGacha.available?
      return CLINormanhurstGachaSmoke.run
    end
    finish("Gacha NPC missing") unless $game_map.events.values.any? { |event| event.name == "Gacha tester" }
    original_pity = $player.gacha_pity.dup
    original_storage = $PokemonStorage
    original_bgm = $game_system.getPlayingBGM
    scene = nil
    begin
      $PokemonStorage = PokemonStorage.new
      CLIDemo.with_practice_raichu do
        $player.gacha_pity = {}
        finish("Gacha can charge without tickets") if GachaLogic.pay_cost(:RESHIRAM_BANNER)
        $bag.add(:GACHATICKET, 12)
        $bag.define_singleton_method(:can_add?) { |*_args| false }
        finish("Gacha charged for unavailable reward space") if GachaLogic.pay_cost(:ITEM_PREMIUM_BANNER)
        finish("Gacha lost ticket on rejected payment") unless $bag.quantity(:GACHATICKET) == 12
        $bag.singleton_class.send(:remove_method, :can_add?)
        finish("Gacha single cost wrong") unless GachaLogic.pay_cost(:RESHIRAM_BANNER) && $bag.quantity(:GACHATICKET) == 11
        $player.gacha_pity[:RESHIRAM_BANNER] = 89
        prize = GachaLogic.roll_prize(:RESHIRAM_BANNER)
        finish("Gacha hard pity failed") unless prize[:is_main_prize] && $player.gacha_pity[:RESHIRAM_BANNER] == 0
        _, pokemon = GachaLogic.give_prize(prize)
        finish("Gacha Pokemon reward wrong") unless pokemon && pokemon.species == :RESHIRAM && pokemon.level == 50 && pokemon.nature_id == :MODEST && pokemon.ability_id == :TURBOBLAZE
        finish("Gacha ten-pull cost wrong") unless GachaLogic.pay_cost(:ITEM_PREMIUM_BANNER, 10) && $bag.quantity(:GACHATICKET) == 1
        prizes = GachaLogic.roll_multiple(:ITEM_PREMIUM_BANNER, 10)
        finish("Gacha returned wrong batch size") unless prizes.length == 10
        GachaLogic.give_multiple_prizes(prizes)
        prizes.group_by { |p| p[:item] }.each do |item, entries|
          finish("Gacha batch item quantities wrong") unless $bag.quantity(item) == entries.sum { |p| p[:amount] || 1 }
        end
        serialized = Marshal.load(Marshal.dump($player))
        finish("Gacha pity did not serialize") unless serialized.gacha_pity == $player.gacha_pity
        scene = GachaScene.new(:RESHIRAM_BANNER)
        scene.pbStartScene
        3.times { scene.pbUpdate; Graphics.update }
        Graphics.screenshot("smoke-gacha-pokemon.png")
        scene.pbChangeBanner(:ITEM_PREMIUM_BANNER)
        scene.pbUpdate
        Graphics.update
        Graphics.screenshot("smoke-gacha-items.png")
        scene.pbSetMainPrizeVisibility(false)
        scene.pbRollAnimation(prizes.first)
        @phase = :ui_confirm
        scene.pbShowMultiplePrizesGrid(prizes, [])
        scene.pbSetMainPrizeVisibility(true)
        scene.pbEndScene
        scene = nil
        details = GachaDetails_Scene.new
        details.pbStartScene(:RESHIRAM_BANNER)
        details.pbUpdate
        Graphics.update
        Graphics.screenshot("smoke-gacha-rates.png")
        details.pbEndScene
        @results["gacha"] = { "single_cost" => true, "ten_pull_cost" => true, "pokemon_reward" => true, "item_rewards" => true, "hard_pity" => true, "serialized_pity" => true, "ui" => true }
      end
    ensure
      scene.pbEndScene if scene
      $PokemonStorage = original_storage
      $player.gacha_pity = original_pity
      original_bgm ? pbBGMPlay(original_bgm) : pbBGMStop
      @phase = :ui_test
    end
  end

  def self.animation_sample_test?
    @animation_sample_test
  end

  def self.play_animation_samples(battle)
    @results["animation_samples_played"] = []
    Graphics.screenshot("smoke-gojo-battle-framing.png")
    sprite = battle.scene.sprites["pokemon_0"]
    finish("Gojo back extends beneath command UI") if sprite.y > Graphics.height - 96
    @results["gojo_battle_framing"] = { "bottom" => sprite.y, "command_ui_top" => Graphics.height - 96 }
    [:DARKPULSE, :BUGBUZZ, :UTURN, :STICKYWEB, :KNOCKOFF, :NASTYPLOT, :DRACOMETEOR, :TERABLAST, :LAPSEBLUE, :REVERSALRED, :HOLLOWPURPLE].each do |move|
      @animation_sample_move = move
      @animation_sample_started = System.uptime
      @animation_sample_captured = false
      @animation_sample_capture_count = 0
      target = move == :NASTYPLOT ? battle.battlers[0] : battle.battlers[1]
      battle.scene.pbAnimation(move, battle.battlers[0], target)
      @results["animation_samples_played"] << move
      @animation_sample_move = nil
    end
  end

  def self.run_plugin_ui_tests
    run_bitmap_font_tests
    # These fixtures exist only in the disposable test session, never real saves.
    @phase = :ui_test
    $game_temp.in_menu = true
    pokemon = @expanded_pokemon || Pokemon.new(:BULBASAUR, 20, $player)
    pokemon.level = 20
    pokemon.calc_stats
    pokemon.moves.clear
    pokemon.learn_move(:TACKLE)
    $player.party << pokemon unless $player.party.include?(pokemon)
    $player.has_pokedex = true
    $player.pokedex.register(pokemon)
    $player.pokedex.set_seen(pokemon.species)
    $player.pokedex.set_owned(pokemon.species)
    $bag.add(:POTION, 3)
    $bag.last_viewed_pocket = GameData::Item.get(:POTION).pocket
    pokemon.hp = pokemon.totalhp - 10
    run_load_ui_tests

    bag_scene = PokemonBag_Scene.new
    bag_scene.pbStartScene($bag, $player.party)
    bag_scene.pbSelect(0)
    bag_scene.pbUpdate
    Graphics.update
    Graphics.screenshot("smoke-bag.png")
    before_hp = pokemon.hp
    before_quantity = $bag.quantity(:POTION)
    @phase = :ui_confirm
    pbBagUseItem($bag, :POTION, PokemonBagScreen, bag_scene, 0)
    @phase = :ui_test
    finish("Bag Potion use did not heal and consume one item") unless pokemon.hp > before_hp && $bag.quantity(:POTION) == before_quantity - 1
    @results["bag_party_and_item_use"] = true
    bag_scene.pbEndScene

    summary = PokemonSummary_Scene.new
    summary.pbStartScene($player.party, 0)
    summary_pages = summary.instance_variable_get(:@page_list).dup
    summary_pages.each_with_index do |page, index|
      summary.instance_variable_set(:@page, index + 1)
      # Normal LEFT/RIGHT page navigation resets this before drawing ribbons.
      summary.instance_variable_set(:@ribbonOffset, 0)
      summary.drawPage(index + 1)
      summary.pbUpdate
      Graphics.update
      Graphics.screenshot("smoke-summary-#{index + 1}.png")
      finish("Summary did not select #{page}") unless summary.instance_variable_get(:@page_id) == page
    end
    @results["summary_pages"] = summary_pages
    summary.pbEndScene

    if GameData::Species.exists?(:LUCARIO_3)
      finish("Gojo still registered as separate species") if GameData::Species.exists?(:GOJOLUCARIO)
      gojo = Pokemon.new(:LUCARIO, 30, $player)
      gojo.form = 3
      finish("Gojo is not a persistent Lucario form") unless gojo.species == :LUCARIO && gojo.form == 3
      finish("Regional Lucario inherits an unrelated Mega form") if gojo.hasMegaForm?
      finish("Gojo typing incorrect") unless gojo.types == [:FIGHTING, :PSYCHIC]
      finish("Gojo ability incorrect") unless gojo.ability_id == :INFINITY
      finish("Gojo stats incorrect") unless gojo.baseStats == { :HP => 70, :ATTACK => 65, :DEFENSE => 70, :SPEED => 115, :SPECIAL_ATTACK => 135, :SPECIAL_DEFENSE => 70 }
      riolu = Pokemon.new(:RIOLU, 29, $player)
      riolu.item = :BLINDFOLD
      riolu.happiness = 255
      finish("Blindfold evolution missing") unless riolu.check_evolution_on_level_up == :LUCARIO
      # Match the real evolution scene's callback-before-species-assignment order.
      riolu.action_after_evolution(:LUCARIO)
      riolu.species = :LUCARIO
      finish("Blindfold produced wrong form") unless riolu.form == 3 && riolu.item.nil? && riolu.ability_id == :INFINITY
      finish("Evolution move missing") unless riolu.getMoveList.include?([0, :LAPSEBLUE])
      gojo.moves.clear
      [:LAPSEBLUE, :REVERSALRED, :HOLLOWPURPLE, :AURASPHERE].each { |move| gojo.learn_move(move) }
      mults = { :final_damage_multiplier => 1.0 }
      Battle::AbilityEffects::DamageCalcFromTarget[:INFINITY].call(:INFINITY, nil, gojo, nil, mults, 100, :NORMAL)
      finish("Infinity full-HP reduction failed") unless mults[:final_damage_multiplier] == 0.5
      gojo.hp -= 1
      mults[:final_damage_multiplier] = 1.0
      Battle::AbilityEffects::DamageCalcFromTarget[:INFINITY].call(:INFINITY, nil, gojo, nil, mults, 100, :NORMAL)
      finish("Infinity reduced damage below full HP") unless mults[:final_damage_multiplier] == 1.0
      gojo.heal
      finish("Gojo gift NPC missing") unless $game_map.events[10] || (defined?(CLINormanhurstGacha) && CLINormanhurstGacha.available?)
      [false, true].each do |back|
        bitmap = GameData::Species.sprite_bitmap_from_pokemon(gojo, back)
        finish("Gojo sprite missing") unless bitmap && bitmap.bitmap.width == 192
        bitmap.dispose
      end
      scene = PokemonSummary_Scene.new
      scene.pbStartScene([gojo], 0)
      scene.pbUpdate
      Graphics.update
      Graphics.screenshot("smoke-gojo-lucario.png")
      scene.pbEndScene
      @results["gojo_lucario"] = { "species" => gojo.species, "form" => gojo.form, "level" => gojo.level, "sprites" => true }
    end

    if GameData::Species.exists?(:SHUCKLORD)
      shuckle = Pokemon.new(:SHUCKLE, 39, $player)
      finish("Shuckle evolves too early") if shuckle.check_evolution_on_level_up
      shuckle.level = 40
      finish("Shuckle evolution missing") unless shuckle.check_evolution_on_level_up == :SHUCKLORD
      finish("Shuckle gift NPC missing") unless $game_map.events[11] || (defined?(CLINormanhurstGacha) && CLINormanhurstGacha.available?)
      evolved = Pokemon.new(:SHUCKLORD, 40, $player)
      finish("Shucklord typing incorrect") unless evolved.types == [:BUG, :ROCK]
      [false, true].each do |back|
        bitmap = GameData::Species.sprite_bitmap_from_pokemon(evolved, back)
        finish("Shucklord sprite missing") unless bitmap && bitmap.bitmap.width == 192
        bitmap.dispose
      end
      scene = PokemonSummary_Scene.new
      scene.pbStartScene([evolved], 0)
      scene.pbUpdate
      Graphics.update
      Graphics.screenshot("smoke-shucklord.png")
      scene.pbEndScene
      @results["shucklord"] = { "evolves_from" => :SHUCKLE, "level" => 40, "sprites" => true }
    end

    animation_scene = Battle::Scene.new
    move_to_anim = pbLoadMoveToAnim
    animation_audit = { "dedicated" => [], "fallback" => [], "none" => [] }
    GameData::Move.each do |move|
      direct = animation_scene.pbFindMoveAnimDetails(move_to_anim, move.id, 0)
      resolved = animation_scene.pbFindMoveAnimation(move.id, 0, 0)
      group = direct ? "dedicated" : (resolved ? "fallback" : "none")
      animation_audit[group] << move.id
    end
    @results["move_animation_audit"] = animation_audit
    if defined?(CLIGojoMoveAnimationBindings)
      animations = pbLoadBattleAnimations
      @results["gojo_animation_bindings"] = {}
      CLIGojoMoveAnimationBindings::SOURCES.each do |move, (source, graphic, background)|
        2.times do |side|
          original_id = move_to_anim[side][source] || move_to_anim[0][source]
          copy_id = move_to_anim[side][move] || move_to_anim[0][move]
          original, copy = animations[original_id], animations[copy_id]
          finish("Custom animation did not clone source") unless copy_id != original_id && copy.length == original.length
          finish("Wrong custom animation sheet") unless copy.graphic == graphic
          finish("Source animation recolored") if original.graphic.start_with?("CLI-Gojo")
        end
        @results["gojo_animation_bindings"][move] = { "source" => source, "sheet" => graphic,
          "timings" => animations[move_to_anim[0][move]].timing.map { |t| [t.timingType, t.name] } }
      end
    end
    if defined?(CLIPreserveDBKMegaAnimation)
      finish("Animation pack replaced DBK Mega") if animation_scene.pbCommonAnimationExists?("MegaEvolution")
      samples = [:DARKPULSE, :BUGBUZZ, :UTURN, :STICKYWEB, :KNOCKOFF, :NASTYPLOT, :DRACOMETEOR, :TERABLAST]
      samples.each do |move|
        next if move == :TERABLAST
        finish("Pack lacks dedicated #{move}") unless animation_audit["dedicated"].include?(move)
      end
      @animation_sample_test = true
      Battle.prepend(Module.new do
        def pbCommandPhase
          return super unless PokeSmoke.animation_sample_test?
          PokeSmoke.play_animation_samples(self)
          @decision = 3
        end
      end)
      @phase = :battle
      begin
        CLIDemo.with_practice_raichu do
          pokemon = Pokemon.new(:LUCARIO, 30, $player)
          pokemon.form = 3
          $player.party = [pokemon]
          WildBattle.start_core(:LECHONK, 5)
        end
      ensure
        @animation_sample_test = false
        @phase = :ui_test
      end
    end

    dex = PokemonPokedexInfo_Scene.new
    data = GameData::Species.get(pokemon.species)
    dex_number = 0
    GameData::Species.each_species do |species_data|
      dex_number += 1
      break if species_data.id == data.id
    end
    dex_region = @expanded_pokemon ? -1 : 0
    dex.pbStartScene([{species: data.id, name: data.name, height: data.height,
                       weight: data.weight, number: dex_number, shift: false}], 0, dex_region)
    dex_pages = dex.instance_variable_get(:@page_list).dup
    dex_pages.each_with_index do |page, index|
      dex.instance_variable_set(:@page, index + 1)
      dex.drawPage(index + 1)
      dex.pbUpdate
      Graphics.update
      Graphics.screenshot("smoke-pokedex-#{index + 1}.png")
      finish("Pokedex did not select #{page}") unless dex.instance_variable_get(:@page_id) == page
    end
    @results["pokedex_pages"] = dex_pages
    dex.pbEndScene
    CLICustomVariantsSmoke.run if defined?(CLICustomVariantsSmoke) && GameData::Species.exists?(:ABSOL_3)
    run_warren_tests if GameData::Species.exists?(:GARDEVOIR_2)
    run_gacha_tests if defined?(GachaScene)
    run_world_tests if ENV["POKE_SMOKE_WORLD"] == "1"
    $game_temp.in_menu = false
    if ENV["POKE_SMOKE_BATTLE"] == "1"
      @phase = :battle
      opponent = ENV["POKE_SMOKE_EXPANDED"] == "1" ? :LECHONK : :RATTATA
      @results["wild_battle_species"] = opponent
      result = WildBattle.start(opponent, 2)
      finish("Basic wild battle did not end in victory") unless result && @results["battle_started"]
      @results["basic_wild_battle_win"] = true
    end
    run_vs_style_tests if ENV["POKE_SMOKE_VS_STYLES"] == "1"
    run_mega_scene_tests if ENV["POKE_SMOKE_MEGA_SCENES"] == "1"
    if ENV["POKE_SMOKE_MEGA"] == "1"
      start_mega_test(1)
    elsif ENV["POKE_SMOKE_TRAINER"] == "1"
      start_trainer_test
    else
      finish
    end
  end

  def self.run_load_ui_tests
    @phase = :load_ui_test
    scene = PokemonLoad_Scene.new
    scene.pbStartScene(["Continue", "New Game", "Options", "Quit Game"], true, $player, $stats, $game_map.map_id)
    scene.pbSetParty($player)
    # pbChoose normally fills this invisible input window before its loop.
    scene.instance_variable_get(:@sprites)["cmdwindow"].commands = ["Continue", "New Game", "Options", "Quit Game"]
    scene.pbUpdate
    Graphics.update
    Graphics.screenshot("smoke-menu-continue.png")
    @load_nav_steps = 3
    8.times { Graphics.update; Input.update; scene.pbUpdate }
    sprites = scene.instance_variable_get(:@sprites)
    finish("Load menu DOWN navigation failed") unless sprites["cmdwindow"].index == 3 && sprites["panel3"].selected
    finish("Load menu did not scroll Quit on screen") unless sprites["panel3"].y <= Graphics.height - 80
    Graphics.update
    Graphics.screenshot("smoke-menu-scrolled.png")
    scene.pbCloseScene
    @load_nav_steps = nil
    @results["load_menu_continue_and_scroll"] = true
    @phase = :ui_test
  end

  def self.observe_pixel_scale_refresh(value)
    @pixel_scale_refreshed = true if value && [Graphics.width, Graphics.height] == [512, 384]
  end

  def self.capture_title(screen)
    return if @results["modular_title"]
    finish("Game canvas is not the intended 4:3 size") unless [Graphics.width, Graphics.height] == [512, 384]
    if Graphics.respond_to?(:integer_scaling)
      finish("Runtime did not enable strict integer pixel scaling") unless Graphics.integer_scaling && !Graphics.last_mile_scaling
      finish("Startup did not refresh the initial runtime scaling rectangle") unless @pixel_scale_refreshed
      @results["pixel_scaling"] = {"canvas" => [Graphics.width, Graphics.height],
        "integer_scaling" => Graphics.integer_scaling, "last_mile_scaling" => Graphics.last_mile_scaling,
        "startup_rectangle_refreshed" => @pixel_scale_refreshed}
    else
      @results["pixel_scaling"] = {"canvas" => [Graphics.width, Graphics.height], "integer_scaling" => "unsupported"}
    end
    @results["window_scale"] = Graphics.scale if Graphics.respond_to?(:scale)
    Graphics.screenshot("smoke-title.png")
    expected_logo = case ENV["POKE_EXPECTED_SLUG"]
                    when "pokemon-normanhurst", "pokemon-hornsby" then ENV["POKE_EXPECTED_SLUG"]
                    when "my-pokemon-game" then "pokemon-demo"
                    else "cli_demo_logo"
                    end
    finish("Wrong edition title logo") unless ModularTitle::LOGO_FILE == expected_logo && pbResolveBitmap("Graphics/MODTS/" + expected_logo)
    if expected_logo != "cli_demo_logo"
      finish("Edition did not use the classic title preset") unless ModularTitle::PRESET == :cli_classic && ModularTitle::PARTICLE_EFFECT == 0 && ModularTitle::START_FILE == "classic-start"
      bg = screen.instance_variable_get(:@sprites)["bg"].instance_variable_get(:@sprite).bitmap
      pixel = bg.get_pixel(0, 0)
      expected_rgb = expected_logo == "pokemon-hornsby" ? [40, 96, 64] : [168, 64, 40]
      finish("Title background silently fell back to the default") unless [pixel.red.to_i, pixel.green.to_i, pixel.blue.to_i] == expected_rgb
    end
    @results["modular_title"] = {"preset" => ModularTitle::PRESET, "logo" => ModularTitle::LOGO_FILE,
      "background" => ModularTitle::BACKGROUND_FILE, "prompt" => ModularTitle::START_FILE}
  end

  def self.run_world_tests
    @phase = :ui_test
    spriteset = $scene.spriteset
    [1, 3, 5, 6].each do |id|
      indicator = spriteset.event_indicator_sprites[id]
      finish("Event indicator #{id} missing") unless indicator && !indicator.disposed? && indicator.indicator.visible
    end
    Graphics.screenshot("smoke-indicators.png")
    @results["event_indicators"] = true

    @phase = :world_news
    @world_board = LWN_BulletinBoard_Scene.new
    @world_board.pbStartScene
    Graphics.screenshot("smoke-news-list.png")
    @world_board.pbBulletinBoard
    @world_board.pbEndScene
    finish("News detail was not read") unless @world_news_read
    @world_board = nil
    LivingWorldNews.post_dynamic_news(id: :cli_smoke_news, category: :breaking,
      headline: "Test posting", body: "This posting exists only in the disposable smoke test.", priority: 10, one_time: true)
    finish("Dynamic news posting failed") unless LivingWorldNews.active_news.first[:id] == :cli_smoke_news
    LivingWorldNews.mark_read(:cli_smoke_news)
    finish("One-time news was not hidden") if LivingWorldNews.active_news.any? { |i| i[:id] == :cli_smoke_news }
    news_copy = Marshal.load(Marshal.dump(LivingWorldNews.lwn_data))
    finish("News state did not marshal") unless news_copy.read_ids[:cli_smoke_news]
    @world_messages = []
    @phase = :ui_confirm
    pbShowNewsOnTV
    pbNewsGossip(:wildlife)
    finish("News TV/gossip did not show starter headline") unless @world_messages.any? { |m| m.include?("Your partner is here") }
    @results["living_world_news"] = {"list_and_detail" => true, "tv_and_gossip" => true,
      "dynamic_and_one_time" => true, "marshal_roundtrip" => true}
    @world_messages = nil

    @phase = :world_market
    finish("Demo market lot setup failed") unless pbAddFreeMarketLot(:CLI_POTIONS, index: 0)
    lot = $PokemonGlobal.free_market.lots[0]
    money, quantity = $player.money, $bag.quantity(:POTION)
    @world_market_scene = FreeMarket_Scene.new
    @world_market_scene.pbStartScene
    Graphics.screenshot("smoke-market.png")
    @world_market_scene.pbScene
    @world_market_scene.pbEndScene
    @world_market_scene = nil
    finish("Market purchase did not update money/Bag/sold state") unless @world_market_bought && lot.sold && $player.money == money - 500 && $bag.quantity(:POTION) == quantity + 3
    finish("Market did not record purchase") unless pbFreeMarketLotPurchased?(:CLI_POTIONS)
    market_copy = Marshal.load(Marshal.dump($PokemonGlobal.free_market))
    finish("Market state did not marshal") unless market_copy.purchased_lots[:CLI_POTIONS] == 1
    @results["free_market"] = {"ui_purchase" => true, "money_and_bag" => true, "marshal_roundtrip" => true}

    @phase = :world_puddles
    @world_puddle_steps = []
    @world_puddle_animations = 0
    $game_player.moveto(1, 7)
    follower = FollowingPkmn.get_event
    follower.moveto(0, 7)
    3.times do
      $game_player.move_generic(6)
      18.times { Graphics.update; Input.update; $scene.update }
    end
    45.times { Graphics.update; Input.update; $scene.update }
    finish("Player/follower puddle steps not detected") unless @world_puddle_steps.include?("Game_Player") && @world_puddle_steps.include?(follower.class.name)
    finish("Puddle animations were not created") unless @world_puddle_animations >= 2
    FollowingPkmn.toggle_off(false)
    before = @world_puddle_steps.length
    FootStepEffects.on_step_puddle(follower)
    finish("Hidden follower triggered puddle") unless @world_puddle_steps.length == before
    FollowingPkmn.toggle_on(false)
    @results["water_puddles"] = {"player_and_follower" => true, "animations_created" => @world_puddle_animations, "hidden_follower_suppressed" => true}
    $game_player.moveto(*@origin)
    follower.moveto(@origin[0] + 1, @origin[1])
    @phase = :ui_test
  end

  def self.start_trainer_test
    @phase = :trainer_npc
    @trainer_returned = false
    @trainer_original_party, @trainer_original_bag = $player.party, $bag
    @trainer_party_snapshot, @trainer_bag_snapshot = Marshal.dump($player.party), Marshal.dump($bag)
    @trainer_rules_snapshot = $game_temp.battle_rules.dup
    @trainer_outcome_snapshot = $game_variables[1]
    finish("Trainer PBS shadow metrics were not applied") unless GameData::TrainerType.get(:SCIENTIST).shadow_xy == [0, -1]
    GameData::TrainerType.get(:POKEMONTRAINER_Hilbert)
    $game_map.events[3].start
  end

  def self.begin_trainer
    @phase = :trainer_battle if @phase == :trainer_npc
  end

  def self.begin_trainer_intro(battle, sprite)
    return unless @phase == :trainer_battle
    finish("Wrong practice opponent") unless battle.opponent.first.trainer_type == :LEADER_Brock
    finish("Animated trainer sprite missing") unless sprite.is_a?(Battle::Scene::TrainerSprite) && sprite.iconBitmap.length > 1
    @trainer_sprite = sprite
    @trainer_frames = [sprite.iconBitmap.frame_idx]
    @results["animated_trainer_intros"] = {"trainer_type" => sprite.tr_type, "frames" => sprite.iconBitmap.length, "scale" => sprite.iconBitmap.scale}
  end

  def self.end_trainer_intro
    return unless @phase == :trainer_battle && @trainer_sprite
    sprite = @trainer_sprite
    @trainer_frames << sprite.iconBitmap.frame_idx
    finish("Trainer intro did not advance and finish") unless sprite.finished? && @trainer_frames.uniq.length > 1
    shadow = sprite.instance_variable_get(:@shadowSprite)
    finish("Trainer shadow missing") unless shadow.visible && shadow.bitmap == sprite.bitmap && shadow.z < sprite.z
    @results["animated_trainer_intros"]["observed_frames"] = @trainer_frames.uniq
    @results["animated_trainer_intros"]["shadow"] = true
    @trainer_sprite = nil
  end

  def self.end_trainer(result)
    return unless @phase == :trainer_battle
    finish("Trainer practice did not end in victory") unless result == 1
    @trainer_returned = true
  end

  def self.start_mega_test(choice)
    @phase = :mega_npc
    @mega_choice = choice
    @mega_returned = false
    @mega_action_sent = false
    @mega_original_party = $player.party
    @mega_original_bag = $bag
    @mega_party_snapshot = Marshal.dump($player.party)
    @mega_bag_snapshot = Marshal.dump($bag)
    @mega_rules_snapshot = $game_temp.battle_rules.dup
    @mega_outcome_snapshot = $game_variables[1]
    $game_map.events[3].start
  end

  def self.begin_choice(message, arguments)
    return false unless [:mega_npc, :trainer_npc].include?(@phase) && arguments[0].is_a?(Array) && arguments[0].include?("Mega Raichu X battle")
    @choice_active = true
    @choice_expected = @phase == :trainer_npc ? 3 : @mega_choice
    @choice_steps = @choice_expected
    return true
  end

  def self.end_choice(active, result)
    return unless active
    @choice_active = false
    finish("NPC selected wrong practice option #{result}") unless result == @choice_expected
  end

  def self.choice_repeat?(key)
    if @phase == :load_ui_test && key == Input::DOWN && @load_nav_steps.to_i > 0
      return false if @load_nav_tick == @ticks
      @load_nav_tick = @ticks
      @load_nav_steps -= 1
      return true
    end
    return false unless @choice_active && key == Input::DOWN && @choice_steps > 0
    return false if @choice_tick == @ticks
    @choice_tick = @ticks
    @choice_steps -= 1
    return true
  end

  def self.begin_mega(stone)
    return unless @phase == :mega_npc
    expected = @mega_choice == 1 ? :RAICHUNITEX : :RAICHUNITEY
    finish("NPC called wrong Mega Stone #{stone}") unless stone == expected
    @phase = :mega_battle
  end

  def self.mega_menu(battle, index, special)
    return unless @phase == :mega_battle && index == 0
    finish("Mega Evolution unavailable through the fight menu") unless special == :mega && battle.pbCanMegaEvolve?(index)
    @mega_menu_active = true
  end

  def self.leave_mega_menu
    @mega_menu_active = false
  end

  def self.observe_mega(battle, index)
    return unless @phase == :mega_battle && index == 0
    battler = battle.battlers[index]
    expected_form = @mega_choice + 1
    finish("Raichu did not Mega Evolve into expected form #{expected_form}") unless @mega_action_sent && battler.mega? && battler.form == expected_form
    expected_ability = @mega_choice == 1 ? :ELECTRICSURGE : :NOGUARD
    finish("Mega ability mismatch") unless battler.ability_id == expected_ability
    finish("Mega Raichu X did not create Electric Terrain") if @mega_choice == 1 && battle.field.terrain != :Electric
    key = @mega_choice == 1 ? "mega_raichu_x" : "mega_raichu_y"
    pokemon = battler.pokemon
    front = GameData::Species.front_sprite_filename(:RAICHU, pokemon.form, pokemon.gender, pokemon.shiny?)
    back = GameData::Species.back_sprite_filename(:RAICHU, pokemon.form, pokemon.gender, pokemon.shiny?)
    finish("Mega sprites missing") unless front&.include?("RAICHU_#{expected_form}") && back&.include?("RAICHU_#{expected_form}")
    @results[key] = {"form" => pokemon.form, "ability" => battler.ability_id,
                     "stone" => pokemon.item_id, "front_sprite" => front, "back_sprite" => back,
                     "fight_menu_action" => true}
    Graphics.screenshot("smoke-#{key.tr('_', '-')}.png")
  end

  def self.end_mega(result)
    return unless @phase == :mega_battle
    finish("Mega practice battle did not end in victory") unless result == 1
    @mega_returned = true
  end

  def self.capture_battle
    return unless @phase == :battle && !@results["battle_started"]
    Graphics.screenshot("smoke-battle.png")
    @results["battle_started"] = true
  end

  def self.capture_menu(bitmap)
    config = JSON.parse(File.read("mkxp.json"))
    expected_title = ENV.fetch("POKE_EXPECTED_TITLE").dup.force_encoding("UTF-8")
    finish("Wrong project window title: #{config['windowTitle'].inspect}") unless config["windowTitle"] == expected_title
    finish("Wrong game/save identity") unless config["dataPathApp"] == ENV["POKE_EXPECTED_SLUG"] && System.game_title == ENV["POKE_EXPECTED_SLUG"] && System.data_directory.include?(ENV["POKE_EXPECTED_SLUG"])
    @results["project"] = {"title" => config["windowTitle"], "slug" => System.game_title, "save_directory" => System.data_directory}
    @results["plugins"] = PluginManager.plugins.each_with_object({}) do |name, loaded|
      loaded[name] = PluginManager.version(name)
    end
    JSON.parse(ENV.fetch("POKE_EXPECTED_PLUGINS", "{}")).each do |name, version|
      finish("Expected plugin #{name} #{version} was not loaded") unless PluginManager.installed?(name, version, true)
    end
    @results["menu_font"] = {
      "name" => bitmap.font.name, "size" => bitmap.font.size,
      "available" => Font.exist?(MessageConfig::FONT_NAME),
      "text_height" => bitmap.text_size("New Game").height
    }
    Graphics.screenshot("smoke-menu.png")
    finish("Bundled Power Green font is unavailable") unless @results["menu_font"]["available"]
    # The bundled font at size 27 needs a 22-pixel rendered line box. Nominal
    # reporting returns 17 in this runtime, clipping the menu's lower strokes.
    if bitmap.font.name.to_s.downcase == "power green" && bitmap.font.size == 27 && @results["menu_font"]["text_height"] < 22
      finish("Menu font height is too small; enable fontHeightReporting: 1")
    end
  end

  def self.tick
    if @logged_phase != @phase
      puts "POKE_SMOKE phase #{@phase}"
      @logged_phase = @phase
    end
    if defined?(ModularTitleScreen) && !@title_hooked
      ModularTitleScreen.prepend(Module.new do
        def intro
          result = super
          PokeSmoke.capture_title(self)
          result
        end
      end)
      @title_hooked = true
    end
    if defined?(FootStepEffects) && !@world_hooked
      FootStepEffects.singleton_class.prepend(Module.new do
        def spawn_puddle(x, y)
          PokeSmoke.puddle_spawn
          super
        end
        def on_step_puddle(character)
          PokeSmoke.puddle_character(character)
          super
        end
      end)
      Spriteset_Map.prepend(Module.new do
        def addUserAnimation(id, *args)
          sprite = super
          PokeSmoke.puddle_animation(id, sprite)
          sprite
        end
      end)
      FreeMarketLot.prepend(Module.new do
        def purchase(*args)
          result = super
          PokeSmoke.market_bought(self)
          result
        end
      end)
      @world_hooked = true
    end
    if defined?(PokemonLoad_Scene) && !@menu_hooked
      PokemonLoad_Scene.prepend(Module.new do
        def pbChoose(commands)
          PokeSmoke.capture_menu(@sprites["panel0"].bitmap)
          super
        end
      end)
      @menu_hooked = true
    end
    if defined?(Battle::Scene) && !@battle_hooked
      Battle::Scene.prepend(Module.new do
        def pbCommandMenu(*arguments)
          result = super
          PokeSmoke.capture_battle
          result
        end

        def pbAnimateTrainerIntros
          PokeSmoke.begin_trainer_intro(@battle, @sprites["trainer_1"])
          result = super
          PokeSmoke.end_trainer_intro
          result
        end

        def pbFightMenu(index, special = nil, &block)
          PokeSmoke.mega_menu(@battle, index, special)
          begin
            super
          ensure
            PokeSmoke.leave_mega_menu
          end
        end
      end)
      Battle.prepend(Module.new do
        def pbMegaEvolve(index)
          result = super
          PokeSmoke.observe_mega(self, index)
          result
        end
      end)
      @battle_hooked = true
    end
    if defined?(CLIDemo) && !@demo_hooked
      CLIDemo.singleton_class.prepend(Module.new do
        def trainer_battle
          PokeSmoke.begin_trainer
          result = super
          PokeSmoke.end_trainer(result)
          result
        end

        def mega_battle(stone)
          PokeSmoke.begin_mega(stone)
          result = super
          PokeSmoke.end_mega(result)
          result
        end
      end)
      @demo_hooked = true
    end
    if @trainer_sprite
      frame = @trainer_sprite.iconBitmap.frame_idx
      unless @trainer_frames.include?(frame)
        @trainer_frames << frame
        Graphics.screenshot("smoke-trainer-intro.png") if frame > 0 && frame < @trainer_sprite.iconBitmap.length - 1
      end
    end
    @ticks += 1
    capture_vs_style if ENV["POKE_SMOKE_VS_STYLES"] == "1"
    capture_mega_scene if ENV["POKE_SMOKE_MEGA_SCENES"] == "1"
    orb_sample = [:LAPSEBLUE, :REVERSALRED].include?(@animation_sample_move)
    if orb_sample && System.uptime - @animation_sample_started > (@animation_sample_capture_count + 1) * 0.2
      @animation_sample_capture_count += 1
      Graphics.screenshot("smoke-move-#{@animation_sample_move.to_s.downcase}-#{@animation_sample_capture_count}.png")
    elsif @animation_sample_move && !orb_sample && !@animation_sample_captured && System.uptime - @animation_sample_started > 0.6
      Graphics.screenshot("smoke-move-#{@animation_sample_move.to_s.downcase}.png")
      @animation_sample_captured = true
    end
    @pulse = [:menu, :close_dialogue, :tester, :ui_confirm, :battle, :mega_npc, :mega_battle, :trainer_npc, :trainer_battle, :world_news, :world_market].include?(@phase) && @ticks % 90 == 0
    finish("Timed out in phase #{@phase}") if @ticks > (ENV["POKE_SMOKE_VS_STYLES"] == "1" ? 24000 : ENV["POKE_SMOKE_TRAINER"] == "1" ? 13800 : ENV["POKE_SMOKE_WORLD"] == "1" ? 11400 : ENV["POKE_SMOKE_MEGA"] == "1" ? 7800 : ENV["POKE_SMOKE_PLUGIN_UI"] == "1" || ENV["POKE_SMOKE_GYMS"] == "1" ? 21000 : 4200)
    return unless defined?(Scene_Map) && $scene.is_a?(Scene_Map)
    case @phase
    when :menu
      return unless $player && $player.character_ID > 0
      @results["bootstrap"] = {
        "map" => $game_map.map_id, "character_id" => $player.character_ID,
        "graphic" => $game_player.character_name, "opacity" => $game_player.opacity,
        "position" => [$game_player.x, $game_player.y]
      }
      return if $game_player.moving?
      @origin = [$game_player.x, $game_player.y]
      @phase = :left
      $game_player.move_generic(4)
    when :left
      return if $game_player.moving?
      finish("Player failed to move left") if $game_player.x != @origin[0] - 1
      @results["movement"] = true
      @phase = :return
      $game_player.move_generic(6)
    when :return
      return if $game_player.moving?
      finish("Player failed to return") if [$game_player.x, $game_player.y] != @origin
      @phase = :dialogue
      $game_player.turn_generic(8)
      $game_map.events[1].start
    when :dialogue
      return unless @message
      @dialogue_tick ||= @ticks
      return if @ticks - @dialogue_tick < 180
      finish("Unexpected Guide dialogue: #{@message.inspect}") unless @message.include?("This room was generated from JSON.")
      @results["guide_dialogue"] = @message
      Graphics.screenshot("smoke-guide.png")
      if ENV["POKE_SMOKE_PLUGIN_UI"] == "1" || ENV["POKE_SMOKE_GYMS"] == "1"
        @phase = :close_dialogue
      else
        finish
      end
    when :close_dialogue
      return if @message_depth.to_i > 0 || $game_temp.message_window_showing || pbMapInterpreterRunning?
      if ENV["POKE_SMOKE_GYMS"] == "1"
        @phase = :ui_test
        CLINormanhurstGymsSmoke.run
        run_gacha_tests if defined?(GachaScene) && CLINormanhurstGymTests.available?
        finish
      elsif ENV["POKE_SMOKE_EXPANDED"] == "1"
        @phase = :tester
        $game_map.events[3].start
      else
        run_plugin_ui_tests
      end
    when :tester
      return if @message_depth.to_i > 0 || $game_temp.message_window_showing || pbMapInterpreterRunning?
      @expanded_pokemon = $player.party.first
      finish("Tester NPC did not give Sprigatito") unless @expanded_pokemon&.species == :SPRIGATITO
      finish("Tester NPC did not enable National Pokedex") unless $player.has_pokedex && $player.pokedex.unlocked?(-1)
      finish("Starter not accessible in National Pokedex") unless $player.pokedex.accessible_dexes.include?(-1) && $player.pokedex.owned?(:SPRIGATITO)
      finish("Tester NPC did not give Potions") unless $bag.quantity(:POTION) == 3
      [:SPRIGATITO, :ANNIHILAPE, :TERAPAGOS].each do |species|
        finish("Missing Gen 9 species #{species}") unless GameData::Species.get(species).generation == 9
      end
      GameData::Move.get(:FLOWERTRICK)
      GameData::Ability.get(:GOODASGOLD)
      GameData::Item.get(:MIRRORHERB)
      finish("Champions rules unexpectedly enabled") if Settings::CHAMPIONS_MECHANICS
      @results["gen9_data"] = true
      @results["tester_starter"] = @expanded_pokemon.species
      follower = FollowingPkmn.get_event
      finish("Follower did not activate") unless FollowingPkmn.active? && follower&.character_name&.include?("SPRIGATITO")
      finish("Follower sprite missing") unless pbResolveBitmap("Graphics/Characters/" + follower.character_name)
      @follower_origin = [follower.x, follower.y]
      @follower_steps = 0
      @phase = :follower_walk
      $game_player.move_generic(4)
    when :follower_walk
      follower = FollowingPkmn.get_event
      return if $game_player.moving? || follower.moving?
      @follower_steps += 1
      if @follower_steps < 2
        $game_player.move_generic(4)
      else
        finish("Follower did not move behind player") unless [follower.x, follower.y] == [$game_player.x + 1, $game_player.y] && [follower.x, follower.y] != @follower_origin
        @results["follower_movement"] = true
        @follower_steps = 0
        @phase = :follower_return
        $game_player.move_generic(6)
      end
    when :follower_return
      follower = FollowingPkmn.get_event
      return if $game_player.moving? || follower.moving?
      @follower_steps += 1
      if @follower_steps < 2
        $game_player.move_generic(6)
      else
        FollowingPkmn.toggle_off(true)
        finish("Follower did not toggle off") if FollowingPkmn.active? || follower.character_name != ""
        FollowingPkmn.toggle_on(true)
        finish("Follower did not toggle on") unless FollowingPkmn.active? && follower.character_name.include?("SPRIGATITO")
        @results["follower_toggle"] = true
        FollowingPkmn.animation(FollowingPkmn::ANIMATION_EMOTE_HEART)
        @follower_render_tick = @ticks
        @phase = :follower_render
      end
    when :follower_render
      return if @ticks - @follower_render_tick < 30
      Graphics.screenshot("smoke-follower.png")
      @results["follower_graphic"] = FollowingPkmn.get_event.character_name
      run_plugin_ui_tests
    when :mega_npc, :mega_battle
      return unless @mega_returned
      return if @message_depth.to_i > 0 || $game_temp.in_battle || pbMapInterpreterRunning?
      finish("Practice battle changed original team") unless $player.party.equal?(@mega_original_party) && Marshal.dump($player.party) == @mega_party_snapshot
      finish("Practice battle changed original Bag") unless $bag.equal?(@mega_original_bag) && Marshal.dump($bag) == @mega_bag_snapshot
      finish("Practice battle changed original battle rules") unless $game_temp.battle_rules == @mega_rules_snapshot
      finish("Practice battle overwrote the normal outcome variable") unless $game_variables[1] == @mega_outcome_snapshot
      key = @mega_choice == 1 ? "mega_raichu_x" : "mega_raichu_y"
      finish("Mega Evolution was not observed") unless @results[key]
      @results[key]["victory"] = true
      @results[key]["original_party_and_bag_restored"] = true
      @results[key]["original_party_empty"] = @mega_original_party.empty?
      if @mega_choice == 1
        # Mega practice must also work before taking the starter.
        $player.party = []
        FollowingPkmn.refresh_internal
        FollowingPkmn.refresh(false)
        start_mega_test(2)
      elsif ENV["POKE_SMOKE_TRAINER"] == "1"
        start_trainer_test
      else
        finish
      end
    when :trainer_npc, :trainer_battle
      return unless @trainer_returned
      return if @message_depth.to_i > 0 || $game_temp.in_battle || pbMapInterpreterRunning?
      finish("Trainer practice changed team/Bag") unless $player.party.equal?(@trainer_original_party) && $bag.equal?(@trainer_original_bag) && Marshal.dump($player.party) == @trainer_party_snapshot && Marshal.dump($bag) == @trainer_bag_snapshot
      finish("Trainer practice changed rules/outcome") unless $game_temp.battle_rules == @trainer_rules_snapshot && $game_variables[1] == @trainer_outcome_snapshot
      finish("Trainer intro not observed") unless @results["animated_trainer_intros"] && @results["animated_trainer_intros"]["shadow"]
      @results["animated_trainer_intros"].merge!({"npc_choice" => true, "victory" => true, "original_party_and_bag_restored" => true, "original_party_empty" => @trainer_original_party.empty?})
      finish
    end
  rescue StandardError => error
    finish("#{error.class}: #{error.message}\n#{error.backtrace.first(5).join("\n")}")
  end

  def self.puddle_character(character)
    @puddle_character = character.class.name
  end

  def self.puddle_spawn
    @world_puddle_steps << @puddle_character if @phase == :world_puddles
  end

  def self.puddle_animation(id, sprite)
    return unless @phase == :world_puddles && id == FootStepEffects::PUDDLE_ANIM_ID
    @world_puddle_animations += 1
    Graphics.screenshot("smoke-puddles.png")
  end

  def self.market_bought(lot)
    @world_market_bought = true if @phase == :world_market && lot.lot_id == :CLI_POTIONS && lot.sold
  end

  def self.confirm?(key)
    if @phase == :world_news && @pulse
      if @world_board.instance_variable_get(:@state) == :detail
        Graphics.screenshot("smoke-news-detail.png")
        @world_news_read = true
      end
      wanted = @world_news_read ? Input::BACK : Input::USE
      if key == wanted
        @pulse = false
        return true
      end
      return false
    end
    if @phase == :world_market && @pulse
      wanted = @world_market_bought ? Input::BACK : Input::USE
      if key == wanted
        @pulse = false
        return true
      end
      return false
    end
    if @mega_menu_active && !@mega_action_sent
      return false if key == Input::C
      if key == Input::ACTION
        @mega_action_sent = true
        return true
      end
    end
    return false if @choice_active && @choice_steps > 0
    return false unless key == Input::C && @pulse
    return false unless [:menu, :close_dialogue, :tester, :ui_confirm, :battle, :mega_npc, :mega_battle, :trainer_npc, :trainer_battle].include?(@phase)
    # Do not reuse a dialogue-closing press to trigger another map event.
    @pulse = false
    return true
  end

  def self.observe_message(message)
    @message = message if @phase == :dialogue && message.is_a?(String)
    @world_messages << message if @world_messages && message.is_a?(String)
  end

  def self.message_enter
    @message_depth = @message_depth.to_i + 1
  end

  def self.message_leave
    @message_depth -= 1
  end
end

Object.prepend(Module.new do
  def pbMessage(message, *arguments, &block)
    PokeSmoke.observe_message(message)
    PokeSmoke.message_enter
    choice_active = PokeSmoke.begin_choice(message, arguments)
    begin
      result = super
      PokeSmoke.end_choice(choice_active, result)
      result
    ensure
      PokeSmoke.message_leave
    end
  end
end)

module Graphics
  class << self
    # Older runtimes, such as Essentials' bundled Windows build, lack this API.
    if method_defined?(:integer_scaling=)
      alias_method :poke_smoke_original_integer_scaling, :integer_scaling=
      def integer_scaling=(value)
        PokeSmoke.observe_pixel_scale_refresh(value)
        poke_smoke_original_integer_scaling(value)
      end
    end

    alias_method :poke_smoke_original_update, :update
    def update
      poke_smoke_original_update
      PokeSmoke.tick
    end
  end
end

module Input
  class << self
    alias_method :poke_smoke_original_trigger, :trigger?
    def trigger?(key)
      PokeSmoke.confirm?(key) || poke_smoke_original_trigger(key)
    end

    alias_method :poke_smoke_original_repeat, :repeat?
    def repeat?(key)
      PokeSmoke.choice_repeat?(key) || poke_smoke_original_repeat(key)
    end
  end
end
