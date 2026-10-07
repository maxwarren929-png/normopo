#!/usr/bin/env python3
"""Draw an original stationary RPG Maker XP PC character sheet."""
from pathlib import Path
from PIL import Image, ImageDraw


def render(output: Path) -> None:
    tile = Image.new("RGBA", (32, 48))
    d = ImageDraw.Draw(tile)
    d.ellipse((2, 40, 29, 46), fill=(0, 0, 0, 75))
    d.rectangle((3, 7, 28, 28), fill="#303845")
    d.rectangle((4, 8, 27, 27), fill="#b0bdc8")
    d.rectangle((7, 11, 24, 23), fill="#182b38")
    d.rectangle((8, 12, 23, 22), fill="#236b76")
    for x, glyph in [(10, ["111", "101", "111", "100", "100"]),
                     (17, ["111", "100", "100", "100", "111"])]:
        for y, row in enumerate(glyph):
            for dx, pixel in enumerate(row):
                if pixel == "1":
                    d.point((x + dx, 15 + y), fill="#c0f7dd")
    d.rectangle((13, 29, 18, 31), fill="#768597")
    d.rectangle((2, 32, 29, 43), fill="#303845")
    d.rectangle((3, 33, 28, 42), fill="#8798aa")
    d.rectangle((6, 34, 25, 38), fill="#d1d7de")
    for x in range(7, 25, 3):
        d.line((x, 35, x, 37), fill="#65768b")
    d.point((25, 40), fill="#82f6ab")
    sheet = Image.new("RGBA", (128, 192))
    for row in range(4):
        for column in range(4):
            sheet.paste(tile, (32 * column, 48 * row))
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)


if __name__ == "__main__":
    render(Path(__file__).resolve().parents[1] / "demo/game/Graphics/Characters/CLI_PC.png")
