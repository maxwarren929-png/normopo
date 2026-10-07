import unittest
import zlib

from essentials_cli import marshal as rm
from tools.build_web_test import buffered_animation_scripts, deferred_battle_animation_scripts, gpu_gacha_text_scripts


START_GAME = b'''module Game
  def self.initialize
    $game_temp          = Game_Temp.new
    $game_system        = Game_System.new
    $data_animations    = load_data("Data/Animations.rxdata")
    $data_tilesets      = load_data("Data/Tilesets.rxdata")
    $data_common_events = load_data("Data/CommonEvents.rxdata")
    $data_system        = load_data("Data/System.rxdata")
    pbLoadBattleAnimations
    GameData.load_all
  end
  def self.other
    pbLoadBattleAnimations
    GameData.load_all
  end
end
'''
LAZY_LOADER = b'''def pbLoadBattleAnimations
  $game_temp = Game_Temp.new if !$game_temp
  if !$game_temp.battle_animations_data && pbRgssExists?("Data/PkmnAnimations.rxdata")
    $game_temp.battle_animations_data = load_data("Data/PkmnAnimations.rxdata")
  end
  return $game_temp.battle_animations_data
end
'''
BATTLE_CALLS = b'''animations = pbLoadBattleAnimations
common = pbLoadBattleAnimations
'''
GOJO_CLONING = b'''def pbLoadMoveToAnim
  mapping = super
  animations = pbLoadBattleAnimations
  copy = Marshal.load(Marshal.dump(animations[source_id]))
end
'''


class WebPackageTests(unittest.TestCase):
    def archive(self, source, name=b'MiscPBSData'):
        return rm.dumps([[1, rm.RubyString(name), rm.RubyString(zlib.compress(source))],
                         [2, rm.RubyString(b'Other'), rm.RubyString(zlib.compress(b'puts "unchanged"'))]])

    def test_web_gacha_text_uses_cached_white_glyphs_and_gpu_tone(self):
        original = self.archive(b'module CLINormanhurstGacha\n  module SceneMenu\n  end\nend\n', b'CLI_Normanhurst_Gacha')
        result = rm.loads(gpu_gacha_text_scripts(original))
        source = zlib.decompress(result[0][2].data)
        self.assertIn(b'Color.new(248, 248, 248)', source)
        self.assertIn(b'.tone = Tone.new(r - 248, g - 248, b - 248)', source)
        self.assertIn(b'return super unless CLINormanhurstGacha.available?', source)
        self.assertEqual(zlib.decompress(result[1][2].data), b'puts "unchanged"')
        self.assertNotIn(b'Tone.new', zlib.decompress(rm.loads(original)[0][2].data))

    def test_web_gacha_patch_rejects_unknown_layout(self):
        with self.assertRaisesRegex(ValueError, 'one Normanhurst'):
            gpu_gacha_text_scripts(self.archive(b'  module SceneMenu\n'))
        with self.assertRaisesRegex(ValueError, 'one gacha SceneMenu'):
            gpu_gacha_text_scripts(self.archive(b'no matching module', b'CLI_Normanhurst_Gacha'))

    def test_buffers_only_battle_animation_loader(self):
        source = b'a = load_data("Data/PkmnAnimations.rxdata")\nb = load_data("Data/other.dat")'
        original = self.archive(source)
        result = rm.loads(buffered_animation_scripts(original))
        self.assertEqual(zlib.decompress(result[0][2].data),
                         b'a = Marshal.load(File.binread("Data/PkmnAnimations.rxdata"))\nb = load_data("Data/other.dat")')
        self.assertEqual(zlib.decompress(result[1][2].data), b'puts "unchanged"')
        self.assertEqual(zlib.decompress(rm.loads(original)[0][2].data), source)

    def test_requires_exactly_one_expected_loader(self):
        for source, name in ((b'puts "missing"', b'MiscPBSData'),
                             (b'load_data("Data/PkmnAnimations.rxdata")', b'Unexpected'),
                             (b'load_data("Data/PkmnAnimations.rxdata")\n' * 2, b'MiscPBSData')):
            with self.subTest(source=source, name=name), self.assertRaises(ValueError):
                buffered_animation_scripts(self.archive(source, name))

    def deferred_archive(self, start=START_GAME, loader=LAZY_LOADER):
        sources = [(b'StartGame', start), (b'MiscPBSData', loader),
                   (b'Scene_PlayAnimations', BATTLE_CALLS),
                   (b'CLI_Move_Animations', GOJO_CLONING)]
        return rm.dumps([[i, rm.RubyString(name), rm.RubyString(zlib.compress(source))]
                         for i, (name, source) in enumerate(sources)])

    def sources(self, data):
        return [zlib.decompress(row[2].data) for row in rm.loads(data)]

    def test_defers_exactly_one_initialize_call_and_preserves_lazy_loading(self):
        original = self.deferred_archive()
        result = self.sources(deferred_battle_animation_scripts(original))
        expected = START_GAME.replace(
            b'    pbLoadBattleAnimations\n    GameData.load_all\n',
            b'    GameData.load_all\n', 1)
        self.assertEqual(result, [expected, LAZY_LOADER, BATTLE_CALLS, GOJO_CLONING])
        self.assertEqual(START_GAME.count(b'pbLoadBattleAnimations')
                         - result[0].count(b'pbLoadBattleAnimations'), 1)
        self.assertEqual(self.sources(original)[0], START_GAME)

    def test_deferral_preserves_crlf_and_accepts_crlf_loader(self):
        start = START_GAME.replace(b'\n', b'\r\n')
        loader = LAZY_LOADER.replace(b'\n', b'\r\n')
        result = self.sources(deferred_battle_animation_scripts(
            self.deferred_archive(start=start, loader=loader)))
        self.assertEqual(result, [start.replace(
            b'    pbLoadBattleAnimations\r\n    GameData.load_all\r\n',
            b'    GameData.load_all\r\n', 1), loader, BATTLE_CALLS, GOJO_CLONING])

    def test_buffering_and_deferral_compose_in_either_order(self):
        original = self.deferred_archive()
        buffered = buffered_animation_scripts(original)
        result = deferred_battle_animation_scripts(buffered)
        reverse = buffered_animation_scripts(deferred_battle_animation_scripts(original))
        self.assertEqual(self.sources(result), self.sources(reverse))
        self.assertEqual(self.sources(result)[1], LAZY_LOADER.replace(
            b'load_data("Data/PkmnAnimations.rxdata")',
            b'Marshal.load(File.binread("Data/PkmnAnimations.rxdata"))'))
        self.assertEqual(self.sources(result)[2:], [BATTLE_CALLS, GOJO_CLONING])

    def test_deferral_fails_closed_on_changed_or_duplicate_initialize(self):
        for source in (START_GAME.replace(b'def self.initialize', b'def self.other_init'),
                       START_GAME.replace(b'    GameData.load_all\n', b'    other_call\n', 1),
                       START_GAME.replace(b'    pbLoadBattleAnimations\n', b'', 1),
                       START_GAME + START_GAME):
            with self.subTest(source=source), self.assertRaises(ValueError):
                deferred_battle_animation_scripts(self.deferred_archive(start=source))

    def test_deferral_requires_existing_lazy_loader(self):
        for loader in (b'', LAZY_LOADER + LAZY_LOADER,
                       LAZY_LOADER.replace(b'if !$game_temp.battle_animations_data',
                                           b'if true')):
            with self.subTest(loader=loader), self.assertRaises(ValueError):
                deferred_battle_animation_scripts(self.deferred_archive(loader=loader))

    def test_deferral_requires_unique_named_scripts(self):
        original = rm.loads(self.deferred_archive())
        for rows in (original[1:], [original[0]] + original[2:],
                     original + [original[0]], original + [original[1]]):
            with self.subTest(count=len(rows)), self.assertRaises(ValueError):
                deferred_battle_animation_scripts(rm.dumps(rows))

    def test_deferral_cannot_be_applied_twice(self):
        result = deferred_battle_animation_scripts(self.deferred_archive())
        with self.assertRaises(ValueError):
            deferred_battle_animation_scripts(result)
