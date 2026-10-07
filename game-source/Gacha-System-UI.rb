#===============================================================================
# * Gacha System UI Scene
#===============================================================================

class GachaScene
  def initialize(banner_id)
    @banner_id = banner_id
    @banner = GachaConfig::BANNERS[banner_id]
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @hue_timer = 0
    @hide_main_prize = false
  end

  def pbStartScene
    # Draw Background
    @sprites["background"] = Sprite.new(@viewport)
    @sprites["background"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
    @sprites["background"].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0)) # Fallback Black BG
    
    # Overlay for Text
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["overlay"].z = 100
    pbSetSystemFont(@sprites["overlay"].bitmap)

    pbChangeBanner(@banner_id)

    pbFadeInAndShow(@sprites)
  end

  def pbChangeBanner(banner_id)
    @banner_id = banner_id
    @banner = GachaConfig::BANNERS[banner_id]
    
    # Draw Banner Image (safely)
    if @sprites["banner"]
      @sprites["banner"].dispose
      @sprites.delete("banner")
    end
    
    if @banner && @banner[:banner_image] && pbResolveBitmap(@banner[:banner_image])
      @sprites["banner"] = IconSprite.new(0, 0, @viewport)
      @sprites["banner"].setBitmap(@banner[:banner_image])
      
      # Center the banner
      if @sprites["banner"].bitmap
        @sprites["banner"].x = (Graphics.width - @sprites["banner"].bitmap.width) / 2
        @sprites["banner"].y = (Graphics.height - @sprites["banner"].bitmap.height) / 2
      end
    end

    # Draw Main Prize
    if @sprites["main_prize"]
      @sprites["main_prize"].dispose
      @sprites.delete("main_prize")
    end
    
    main_prize = @banner[:pools].find { |p| p[:is_main_prize] }
    if main_prize
      if main_prize[:type] == :pokemon
        @sprites["main_prize"] = PokemonSprite.new(@viewport)
        pkmn = Pokemon.new(main_prize[:species], main_prize[:level])
        @sprites["main_prize"].setPokemonBitmap(pkmn)
        
        if @sprites["main_prize"].bitmap
          @sprites["main_prize"].ox = @sprites["main_prize"].bitmap.width / 2
          @sprites["main_prize"].oy = @sprites["main_prize"].bitmap.height / 2
        end
        @sprites["main_prize"].x = Graphics.width / 2
        @sprites["main_prize"].y = Graphics.height / 2 + 10 # Adjust Y to sit on the central platform
        @sprites["main_prize"].z = 10
      elsif main_prize[:type] == :item
        @sprites["main_prize"] = ItemIconSprite.new(Graphics.width / 2, Graphics.height / 2 - 20, main_prize[:item], @viewport)
        if @sprites["main_prize"].bitmap
          @sprites["main_prize"].ox = @sprites["main_prize"].bitmap.width / 2
          @sprites["main_prize"].oy = @sprites["main_prize"].bitmap.height / 2
        end
        @sprites["main_prize"].z = 10
      end
    end

    # Play BGM if set
    pbBGMPlay(@banner[:bgm]) if @banner && @banner[:bgm]
    
    pbDrawOverlay
  end
  
  def update_rainbow_color
    @hue_timer += 2
    @hue_timer = 0 if @hue_timer >= 360
    
    # Calculate a nice smooth rainbow color using HSV conversion
    r, g, b = hsv_to_rgb(@hue_timer, 100, 100)
    return Color.new(r, g, b)
  end
  
  # Basic HSV to RGB helper
  def hsv_to_rgb(h, s, v)
    h_i = (h / 60.0).to_i % 6
    f = (h / 60.0) - (h / 60.0).to_i
    p = v * (1.0 - (s / 100.0))
    q = v * (1.0 - (s / 100.0) * f)
    t = v * (1.0 - (s / 100.0) * (1.0 - f))
    
    r, g, b = 0, 0, 0
    v = (v * 2.55).to_i
    p = (p * 2.55).to_i
    q = (q * 2.55).to_i
    t = (t * 2.55).to_i
    
    case h_i
    when 0 then r, g, b = v, t, p
    when 1 then r, g, b = q, v, p
    when 2 then r, g, b = p, v, t
    when 3 then r, g, b = p, q, v
    when 4 then r, g, b = t, p, v
    when 5 then r, g, b = v, p, q
    end
    
    return [r, g, b]
  end
  
  def pbDrawImageButton(overlay, x, y, image_path, text)
    if pbResolveBitmap(image_path)
      bmp = Bitmap.new(image_path)
      # Scale down by less so they appear larger
      scale = 0.7
      dest_w = (bmp.width * scale).to_i
      dest_h = (bmp.height * scale).to_i
      
      # Draw image centered around the given y
      iy = y - dest_h / 2
      overlay.stretch_blt(Rect.new(x, iy, dest_w, dest_h), bmp, Rect.new(0, 0, bmp.width, bmp.height))
      
      # Adjusted Y padding significantly downwards so the text is vertically centered
      textPos = [
        [text, x + dest_w + 12, y - 8, 0, Color.new(248, 248, 248), Color.new(40, 40, 40)]
      ]
      pbDrawTextPositions(overlay, textPos)
      
      width_offset = x + dest_w + 12 + overlay.text_size(text).width + 24
      bmp.dispose
      return width_offset
    else
      btn_name = image_path.split("/").last
      label = btn_name.upcase
      label = "< >" if btn_name == "Esquerda Direita" || btn_name == "Esquerda Diereita"
      
      bg_w = overlay.text_size(label).width + 16
      bg_h = 24
      iy = y - bg_h / 2
      
      # Shadow
      overlay.fill_rect(x + 2, iy + 2, bg_w, bg_h, Color.new(0, 0, 0, 120))
      
      # Base Border
      overlay.fill_rect(x, iy, bg_w, bg_h, Color.new(40, 44, 52))
      
      # Inner gradient effect (Glass style)
      overlay.fill_rect(x + 1, iy + 1, bg_w - 2, bg_h - 2, Color.new(70, 75, 88))
      overlay.fill_rect(x + 1, iy + 1, bg_w - 2, (bg_h - 2) / 2, Color.new(100, 105, 120))
      
      # Label Text
      textPos = [
        [label, x + bg_w / 2, y - 9, 2, Color.new(255, 255, 255), Color.new(20, 20, 30)],
        [text, x + bg_w + 6, y - 9, 0, Color.new(248, 248, 248), Color.new(40, 40, 40)]
      ]
      pbDrawTextPositions(overlay, textPos)
      
      return x + bg_w + 6 + overlay.text_size(text).width + 16
    end
  end

  def pbDrawOverlay
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    return if !@banner
    
    pity_limit = @banner[:pity_limit] || 0
    if pity_limit > 0
      $player.gacha_pity[@banner_id] ||= 0
      current_pity = $player.gacha_pity[@banner_id]
      
      textPos = []
      textPos.push([_INTL("Pity: {1} / {2}", current_pity, pity_limit), Graphics.width - 16, 16, 1, Color.new(248, 248, 248), Color.new(40, 40, 40)])
      pbDrawTextPositions(overlay, textPos)
    end
    
    # Draw Input Instructions at the bottom
    by = Graphics.height - 18
    bx = 16
    pbDrawTextPositions(overlay, [
      ["Left/Right: banner   Use: roll", 16, Graphics.height - 48, 0, Color.new(248, 248, 248), Color.new(40, 40, 40)],
      ["Action: rates   Back: exit", 16, Graphics.height - 24, 0, Color.new(248, 248, 248), Color.new(40, 40, 40)]
    ])
    
    pbDrawRainbowPrizeText
  end
  
  def pbDrawRainbowPrizeText
    return if !@banner || @hide_main_prize
    main_prize = @banner[:pools].find { |p| p[:is_main_prize] }
    return if !main_prize
    
    if !@sprites["prize_name"]
      @sprites["prize_name"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      @sprites["prize_name"].z = 105
      pbSetSystemFont(@sprites["prize_name"].bitmap)
    end
    @sprites["prize_name"].bitmap.clear
    
    name = "(Unknown)"
    if main_prize[:type] == :pokemon
      name = GameData::Species.get(main_prize[:species]).name
    elsif main_prize[:type] == :item
      name = GameData::Item.get(main_prize[:item]).name
    end
    
    rainbow_color = update_rainbow_color
    
    textPos = [
      [name, Graphics.width / 2, 70, 2, rainbow_color, Color.new(40, 40, 40)]
    ]
    pbDrawTextPositions(@sprites["prize_name"].bitmap, textPos)
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites)
    @sprites["background"].bitmap.dispose if @sprites["background"] && @sprites["background"].bitmap && !@sprites["background"].bitmap.disposed?
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  def pbSetMainPrizeVisibility(visible)
    @hide_main_prize = !visible
    if @sprites["main_prize"]
      @sprites["main_prize"].visible = visible
    end
    if @sprites["prize_name"]
      @sprites["prize_name"].visible = visible
    end
  end

  def pbConfirmMultiRoll
    return 0 if !@banner
    cost_item = @banner[:cost_item] || GachaConfig::DEFAULT_COST_ITEM
    cost_amount = @banner[:cost_amount] || 1
    
    cost_1_name = (cost_item == :MONEY) ? "$#{cost_amount}" : "#{cost_amount} #{GameData::Item.get(cost_item).name}"
    cost_10_name = (cost_item == :MONEY) ? "$#{cost_amount * 10}" : "#{cost_amount * 10} #{GameData::Item.get(cost_item).name}"
    
    commands = [
      _INTL("1 Roll ({1})", cost_1_name),
      _INTL("10 Rolls ({1})", cost_10_name),
      _INTL("Cancel")
    ]
    
    choice = pbMessage(_INTL("How many times do you want to roll the {1}?", @banner[:name]), commands, -1)
    
    if choice == 0
      return 1
    elsif choice == 1
      return 10
    else
      return 0
    end
  end

  def pbConfirmRoll
    return false if !@banner
    cost_item = @banner[:cost_item] || GachaConfig::DEFAULT_COST_ITEM
    cost_amount = @banner[:cost_amount] || 1
    cost_name = (cost_item == :MONEY) ? "$#{cost_amount}" : "#{cost_amount} #{GameData::Item.get(cost_item).name}"
    
    return pbConfirmMessage(_INTL("Roll the {1} for {2}?", @banner[:name], cost_name))
  end

  def pbRollAnimation(prize)
    is_pokemon = (prize[:type] == :pokemon)
    is_main = prize[:is_main_prize]
    
    if is_main
      if is_pokemon
        closed_img = @banner[:main_anim_closed] || "Graphics/UI/Gacha/masterball_closed"
      else
        closed_img = @banner[:main_anim_closed] || "Graphics/UI/Gacha/diamondbox_closed"
      end
    else
      closed_img = @banner[:anim_closed] || (is_pokemon ? "Graphics/UI/Gacha/pokeball_closed" : "Graphics/UI/Gacha/itembox_closed")
    end
    anim_style = @banner[:anim_style] || (is_pokemon ? :shake : :jump)
    
    @sprites["anim"] = Sprite.new(@viewport)
    @sprites["anim"].z = 20
    
    is_icon = false
    if pbResolveBitmap(closed_img)
      @sprites["anim"].bitmap = Bitmap.new(closed_img)
      @sprites["anim"].ox = @sprites["anim"].bitmap.width / 2
      @sprites["anim"].oy = @sprites["anim"].bitmap.height / 2
    elsif is_main && pbResolveBitmap(GameData::Item.icon_filename(:MASTERBALL))
      @sprites["anim"].bitmap = Bitmap.new(GameData::Item.icon_filename(:MASTERBALL))
      @sprites["anim"].ox = @sprites["anim"].bitmap.width / 2
      @sprites["anim"].oy = @sprites["anim"].bitmap.height / 2
      is_icon = true
    elsif pbResolveBitmap(is_pokemon ? "Graphics/UI/Gacha/pokeball_closed" : "Graphics/UI/Gacha/itembox_closed")
      @sprites["anim"].bitmap = Bitmap.new(is_pokemon ? "Graphics/UI/Gacha/pokeball_closed" : "Graphics/UI/Gacha/itembox_closed")
      @sprites["anim"].ox = @sprites["anim"].bitmap.width / 2
      @sprites["anim"].oy = @sprites["anim"].bitmap.height / 2
    else
      @sprites["anim"].bitmap = Bitmap.new(64, 64)
      @sprites["anim"].bitmap.fill_rect(0, 0, 64, 64, Color.new(is_main ? 200 : (is_pokemon ? 255 : 0), 0, is_main ? 255 : 0))
      @sprites["anim"].ox = 32
      @sprites["anim"].oy = 32
    end
    
    if is_icon
      @sprites["anim"].zoom_x = 1.5
      @sprites["anim"].zoom_y = 1.5
    else
      @sprites["anim"].zoom_x = 0.25
      @sprites["anim"].zoom_y = 0.25
    end
    
    @sprites["anim"].x = Graphics.width / 2
    @sprites["anim"].y = Graphics.height / 2
    
    # Drop animation
    @sprites["anim"].y = -50
    pbSEPlay("Battle throw") rescue nil
    while @sprites["anim"].y < Graphics.height / 2
      @sprites["anim"].y += 15
      pbUpdate
      Graphics.update
      Input.update
    end
    @sprites["anim"].y = Graphics.height / 2
    pbSEPlay("Battle ball drop") rescue nil
    pbWait(10)
    
    # Shake animation
    if anim_style == :shake
      3.times do
        pbSEPlay("Battle ball shake") rescue nil
        5.times do
          @sprites["anim"].x += 4
          @sprites["anim"].angle -= 5
          pbUpdate; Graphics.update; Input.update
        end
        10.times do
          @sprites["anim"].x -= 4
          @sprites["anim"].angle += 5
          pbUpdate; Graphics.update; Input.update
        end
        5.times do
          @sprites["anim"].x += 4
          @sprites["anim"].angle -= 5
          pbUpdate; Graphics.update; Input.update
        end
        pbWait(15)
      end
    else
      # Jump animation for item box
      3.times do
        pbSEPlay("GUI party switch") rescue nil
        5.times do
          @sprites["anim"].y -= 6
          pbUpdate; Graphics.update; Input.update
        end
        5.times do
          @sprites["anim"].y += 6
          pbUpdate; Graphics.update; Input.update
        end
        pbWait(15)
      end
    end
    
    # Open animation
    pbSEPlay("Anim/Flash2") rescue nil
    
    # Flash screen
    @viewport.color = Color.new(255, 255, 255, 255)
    10.times do
      @viewport.color.alpha -= 25.5
      @sprites["anim"].zoom_x += (is_icon ? 0.2 : 0.1)
      @sprites["anim"].zoom_y += (is_icon ? 0.2 : 0.1)
      @sprites["anim"].opacity -= 25
      pbUpdate
      Graphics.update
      Input.update
    end
    
    if @sprites["anim"]
      @sprites["anim"].bitmap.dispose if @sprites["anim"].bitmap && !@sprites["anim"].bitmap.disposed?
      @sprites["anim"].dispose
      @sprites.delete("anim")
    end
    pbWait(10)
  end

  def pbShowPrize(prize, result_text, obtained_pkmn = nil)
    if prize[:type] == :pokemon
      # Support for Animated Pokemon System (DBK)
      if defined?(PokemonSprite)
        @sprites["prize"] = PokemonSprite.new(@viewport)
        pkmn_dummy = Pokemon.new(prize[:species], 1)
        pkmn_dummy.shiny = true if prize[:is_shiny]
        @sprites["prize"].setPokemonBitmap(pkmn_dummy)
      else
        @sprites["prize"] = Sprite.new(@viewport)
        pkmn_dummy = Pokemon.new(prize[:species], 1)
        pkmn_dummy.shiny = true if prize[:is_shiny]
        @prize_bitmap = GameData::Species.sprite_bitmap_from_pokemon(pkmn_dummy)
        @sprites["prize"].bitmap = @prize_bitmap ? @prize_bitmap.bitmap : nil
      end
    elsif prize[:type] == :item
      @sprites["prize"] = Sprite.new(@viewport)
      fname = GameData::Item.icon_filename(prize[:item])
      @prize_bitmap = AnimatedBitmap.new(fname) if pbResolveBitmap(fname)
      @sprites["prize"].bitmap = @prize_bitmap ? @prize_bitmap.bitmap : nil
    end
    
    @sprites["prize"].z = 10
    
    if @sprites["prize"].bitmap && !@sprites["prize"].bitmap.disposed?
      @sprites["prize"].ox = @sprites["prize"].bitmap.width / 2
      @sprites["prize"].oy = @sprites["prize"].bitmap.height / 2
      @sprites["prize"].x = Graphics.width / 2
      @sprites["prize"].y = Graphics.height / 2
      
      # Zoom in animation
      @sprites["prize"].zoom_x = 0.1
      @sprites["prize"].zoom_y = 0.1
      
      pbSEPlay("Pkmn recovery") rescue nil
      15.times do
        @sprites["prize"].zoom_x += 1.0 / 15.0
        @sprites["prize"].zoom_y += 1.0 / 15.0
        pbUpdate
        Graphics.update
        Input.update
      end
    end
    
    pbMessage(result_text) { pbUpdate }
    

    
    # Show Pokedex Data
    if obtained_pkmn
      pbFadeOutIn do
        scene = PokemonPokedexInfo_Scene.new
        screen = PokemonPokedexInfoScreen.new(scene)
        screen.pbDexEntry(obtained_pkmn.species)
      end
    end
    
    if @sprites["prize"]
      @sprites["prize"].dispose
      @sprites.delete("prize")
    end
    
    if @prize_bitmap
      @prize_bitmap.dispose
      @prize_bitmap = nil
    end
  end

  def pbShowMultiplePrizesGrid(prizes, obtained_pkmn_details)
    grid_sprites = []
    bitmaps = []
    
    spacing_x = 90
    spacing_y = 100
    start_x = (Graphics.width - (4 * spacing_x)) / 2
    start_y = (Graphics.height - spacing_y) / 2 - 20
    
    pbSEPlay("Pkmn recovery") rescue nil
    
    prizes.each_with_index do |prize, i|
      row = i / 5
      col = i % 5
      
      sprite = Sprite.new(@viewport)
      sprite.z = 10
      
      if prize[:type] == :pokemon
        if defined?(PokemonSprite)
          # DBK Animated sprites
          pkmn_sprite = PokemonSprite.new(@viewport)
          pkmn_dummy = Pokemon.new(prize[:species], 1)
          pkmn_dummy.shiny = true if prize[:is_shiny]
          pkmn_sprite.setPokemonBitmap(pkmn_dummy)
          pkmn_sprite.z = 10
          sprite.dispose
          sprite = pkmn_sprite
          grid_sprites.push(sprite)
          # Note: DBK PokemonSprite handles its own update through pbUpdateSpriteHash if we added it there,
          # but we need to ensure its update method is called explicitly here in our custom loop.
          bitmaps.push(sprite)
        else
          # Fallback to essentials standard animated bitmap
          pkmn_dummy = Pokemon.new(prize[:species], 1)
          pkmn_dummy.shiny = true if prize[:is_shiny]
          bmp = GameData::Species.sprite_bitmap_from_pokemon(pkmn_dummy)
          if bmp
            sprite.bitmap = bmp.bitmap
            bitmaps.push(bmp)
          end
          grid_sprites.push(sprite)
        end
      elsif prize[:type] == :item
        fname = GameData::Item.icon_filename(prize[:item])
        bmp = AnimatedBitmap.new(fname) if pbResolveBitmap(fname)
        if bmp
          sprite.bitmap = bmp.bitmap
          bitmaps.push(bmp)
        end
        grid_sprites.push(sprite)
      end
      
      if sprite.bitmap && !sprite.bitmap.disposed?
        sprite.ox = sprite.bitmap.width / 2
        sprite.oy = sprite.bitmap.height / 2
      else
        sprite.ox = 0
        sprite.oy = 0
      end
      
      sprite.x = start_x + col * spacing_x
      sprite.y = start_y + row * spacing_y
      
      sprite.zoom_x = 0.1
      sprite.zoom_y = 0.1
      
      # For standard sprites we already added them to grid_sprites above.
    end
    
    # Zoom in animation
    15.times do
      grid_sprites.each do |s|
        s.zoom_x += 0.5 / 15.0
        s.zoom_y += 0.5 / 15.0
      end
      pbUpdate
      Graphics.update
      Input.update
      bitmaps.each { |b| b.update if b.respond_to?(:update) }
    end
    
    # Wait for acknowledgment
    loop do
      Graphics.update
      Input.update
      pbUpdate
      bitmaps.each { |b| b.update if b.respond_to?(:update) }
      
      if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
        pbPlayDecisionSE rescue nil
        break
      end
    end
    
    # Cleanup
    grid_sprites.each { |s| s.dispose }
    bitmaps.each { |b| b.dispose unless b.respond_to?(:disposed?) && b.disposed? }
    
    # Sequence through obtained pokemon details
    obtained_pkmn_details.each do |detail|
      pkmn = detail[:pkmn]
      is_new = detail[:is_new]
      
      # Show Pokedex only if new
      if is_new
        pbFadeOutIn do
          scene = PokemonPokedexInfo_Scene.new
          screen = PokemonPokedexInfoScreen.new(scene)
          screen.pbDexEntry(pkmn.species)
        end
      end
      

    end
  end

  def pbWait(frames)
    frames.times do
      pbUpdate
      Graphics.update
      Input.update
    end
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
    if @prize_bitmap && @sprites["prize"]
      @prize_bitmap.update
      @sprites["prize"].bitmap = @prize_bitmap.bitmap
    end
    
    # Continuously redraw the rainbow text to animate its color
    pbDrawRainbowPrizeText
  end
end

class GachaScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen(initial_banner_id)
    banner_keys = GachaConfig::BANNERS.keys
    current_index = banner_keys.index(initial_banner_id) || 0
    current_banner_id = banner_keys[current_index]

    @scene.pbStartScene
    normanhurst = defined?(CLINormanhurstGacha) && CLINormanhurstGacha.available?
    previous_direction = 0

    loop do
      Graphics.update
      Input.update
      # Capture input before sprite rendering or bitmap work can stall a frame.
      left = Input.trigger?(Input::LEFT)
      right = Input.trigger?(Input::RIGHT)
      back = Input.trigger?(Input::BACK)
      use = Input.trigger?(Input::USE)
      action = Input.trigger?(Input::ACTION)
      if normanhurst
        direction = Input.press?(Input::LEFT) ? -1 : (Input.press?(Input::RIGHT) ? 1 : 0)
        left = direction == -1 && previous_direction != -1
        right = direction == 1 && previous_direction != 1
        previous_direction = direction
      end
      @scene.pbUpdate

      if left
        pbPlayCursorSE rescue nil
        current_index -= 1
        current_index = banner_keys.length - 1 if current_index < 0
        current_banner_id = banner_keys[current_index]
        @scene.pbChangeBanner(current_banner_id)
      elsif right
        pbPlayCursorSE rescue nil
        current_index += 1
        current_index = 0 if current_index >= banner_keys.length
        current_banner_id = banner_keys[current_index]
        @scene.pbChangeBanner(current_banner_id)
      elsif back
        pbPlayCancelSE rescue nil
        break
      elsif use
        rolls = @scene.pbConfirmMultiRoll
        next if rolls <= 0
        
        if !GachaLogic.can_afford?(current_banner_id, rolls)
          pbPlayBuzzerSE rescue nil
          pbMessage(_INTL("You need enough tickets and reward space for {1} rolls.", rolls))
          next
        end
        
        if GachaLogic.pay_cost(current_banner_id, rolls)
          # Local demo adaptation: never overwrite a save during testing.
          # Rewards, payment and pity are saved only by the player's normal save.
          
          @scene.pbSetMainPrizeVisibility(false)
          
          if rolls == 1
            prize = GachaLogic.roll_prize(current_banner_id)
            if prize
              @scene.pbRollAnimation(prize)
              result_text, obtained_pkmn = GachaLogic.give_prize(prize)
              @scene.pbShowPrize(prize, result_text, obtained_pkmn)
              @scene.pbDrawOverlay # Update text after drawing
            else
              pbMessage(_INTL("Error: Could not determine prize."))
            end
          else
            prizes = GachaLogic.roll_multiple(current_banner_id, rolls)
            if !prizes.empty?
              # Only run animation once for the batch to save time
              top_prize = prizes.find { |p| p[:is_main_prize] } || prizes.first
              @scene.pbRollAnimation(top_prize)
              result_text, obtained_pkmn_details = GachaLogic.give_multiple_prizes(prizes)
              @scene.pbShowMultiplePrizesGrid(prizes, obtained_pkmn_details)
              @scene.pbDrawOverlay # Update text after drawing
              pbMessage(result_text) # Show text after the icons are gone
            else
              pbMessage(_INTL("Error: Could not determine prizes."))
            end
          end
          
          @scene.pbSetMainPrizeVisibility(true)
        end
      elsif action
        pbPlayDecisionSE rescue nil
        pbFadeOutIn do
          scene_det = GachaDetails_Scene.new
          screen_det = GachaDetails_Screen.new(scene_det)
          screen_det.pbStartScreen(current_banner_id)
        end
      end
    end
    @scene.pbEndScene
  end
end

def pbGacha(banner_id = nil)
  banner_keys = GachaConfig::BANNERS.keys
  return false if banner_keys.empty?
  
  banner_id = banner_keys[0] if !banner_id
  
  if !GachaConfig::BANNERS.has_key?(banner_id)
    pbMessage(_INTL("Banner {1} not found.", banner_id.to_s))
    return false
  end
  
  previous_bgm = $game_system.getPlayingBGM
  begin
    pbFadeOutIn do
      scene = GachaScene.new(banner_id)
      screen = GachaScreen.new(scene)
      screen.pbStartScreen(banner_id)
    end
    return true
  ensure
    previous_bgm ? pbBGMPlay(previous_bgm) : pbBGMStop
  end
end
