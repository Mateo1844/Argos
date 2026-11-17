"""Make windows/fonts/DuxIcons.ttf: a tiny copy of Google's Material Symbols
Rounded font with only the icons DUX-AI uses (DMS has the full font; Windows
doesn't, and the full one is 15 MB).

Run again after adding a new icon name to a QML file:

    pip install fonttools
    git clone --depth 1 --filter=blob:none --sparse https://github.com/google/material-design-icons
    (cd material-design-icons && git sparse-checkout set variablefont)
    python windows/tools/make_icon_font.py material-design-icons/variablefont

The font is Apache 2.0 licensed (see windows/fonts/LICENSE-MaterialSymbols.txt).
"""

import json
import re
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "windows" / "fonts"
ALWAYS = {"auto_awesome", "progress_activity"}


def icon_names_in_qml():
    """Every "lowercase_word" string in the QML files; real icon names are kept later."""
    names = set(ALWAYS)
    for qml in list((REPO / "DuxAI").glob("*.qml")) + list((REPO / "windows" / "qml").rglob("*.qml")):
        names |= set(re.findall(r'"([a-z][a-z0-9_]*)"', qml.read_text(encoding="utf-8")))
    return names


def main(folder):
    folder = Path(folder)
    ttf = next(folder.glob("MaterialSymbolsRounded*.ttf"))
    codepoints = {}
    for line in next(folder.glob("MaterialSymbolsRounded*.codepoints")).read_text().splitlines():
        name, hexcode = line.split()
        codepoints[name] = int(hexcode, 16)

    wanted = {n: codepoints[n] for n in sorted(icon_names_in_qml()) if n in codepoints}
    font = TTFont(ttf, lazy=False)
    options = subset.Options()
    options.layout_features = []        # icons are looked up by code point, no ligatures needed
    options.name_IDs = ["*"]
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=list(wanted.values()))
    subsetter.subset(font)
    # Keep only the FILL axis (outline/filled icons); fix weight, grade and size.
    font = instancer.instantiateVariableFont(font, {"wght": 400, "GRAD": 0, "opsz": 24})

    OUT.mkdir(parents=True, exist_ok=True)
    font.save(OUT / "DuxIcons.ttf")
    (OUT / "icons.json").write_text(json.dumps(wanted, indent=1))
    size = (OUT / "DuxIcons.ttf").stat().st_size
    print(f"{len(wanted)} icons, {size // 1024} KB -> {OUT}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "material-design-icons/variablefont")
