#!/usr/bin/env python3
"""Fabrique les icônes d'application UniFlow à partir des logos de marque.

    python3 tools/generer-icones-uniflow.py

Sources (dans assets/brand/) :
    uniflow_marque.png           logo court, l'écusson carré, fond transparent
    uniflow_logo_horizontal.png  logo long, l'écusson + le mot « UniFlow »

Écrit les icônes de toutes les plateformes présentes dans le dépôt :
    android/  mipmap-*/ic_launcher.png, mipmap-*/ic_launcher_foreground.png,
              mipmap-anydpi-v26/ic_launcher.xml, values/ic_launcher_background.xml
    macos/    Assets.xcassets/AppIcon.appiconset/app_icon_*.png
    windows/  runner/resources/app_icon.ico
    web/      favicon.png, icons/Icon-*.png

Deux points qui ont coûté du temps et qu'il ne faut pas défaire
--------------------------------------------------------------
1. L'écusson est posé sur un aplat bleu marine, jamais sur fond blanc. Le logo
   court d'origine était livré sur fond blanc opaque ; sur un lanceur sombre,
   un carré blanc plein fait une tuile blanche.

2. L'alpha est rongé d'un pixel avant composition. Le fond blanc d'origine a
   laissé, sur le contour, des pixels semi-transparents blanchâtres : composés
   tels quels sur le marine, ils dessinaient un liseré clair autour de
   l'écusson. Le rongement les retire — invisible à l'œil, ~9 000 pixels sur
   196 000 concernés.

Les icônes adaptatives Android (mipmap-anydpi-v26) ont une couche de fond
unie et une couche avant qui doit tenir dans la zone sûre de 66dp sur 108dp,
soit 61 %. Au-delà, le lanceur rogne l'écusson.
"""

import sys
from pathlib import Path

from PIL import Image, ImageFilter

RACINE = Path(__file__).resolve().parent.parent
BRAND = RACINE / "assets" / "brand"

MARQUE = BRAND / "uniflow_marque.png"
LOGO_LONG = BRAND / "uniflow_logo_horizontal.png"

NAVY_HEX = "#1e3a8a"
NAVY = (30, 58, 138, 255)

# Zone sûre d'une icône adaptative : 66dp utiles sur 108dp.
PART_ADAPTATIF = 0.60
# Une icône non adaptative n'est pas rognée par le lanceur.
PART_ICONE = 0.74
# Une icône « maskable » du web peut être rognée en cercle : on rentre l'écusson.
PART_MASKABLE = 0.58

DENSITES_ANDROID = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}

# Côté en pixels des fichiers de AppIcon.appiconset, tel que Flutter les nomme.
TAILLES_MACOS = [16, 32, 64, 128, 256, 512, 1024]
# Windows accepte plusieurs résolutions dans un seul .ico.
TAILLES_ICO = [16, 32, 48, 64, 128, 256]

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- Icône adaptative : un fond uni et une couche avant que le lanceur
     redimensionne et masque (cercle, goutte, carré arrondi...). La couche
     avant est générée avec l'écusson à 60 %, dans la zone sûre de 66dp/108dp :
     au-delà, le lanceur le rogne. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""

COULEUR_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Couleur de marque UniFlow, relevée dans uniflow-we. -->
    <color name="ic_launcher_background">{couleur}</color>
</resources>
"""


def ecusson_propre() -> Image.Image:
    """Logo court, recadré sur ses pixels opaques, contour déblanchi."""
    if not MARQUE.exists():
        sys.exit(f"Source absente : {MARQUE}")
    im = Image.open(MARQUE).convert("RGBA")
    boite = im.split()[3].getbbox()
    if boite is None:
        sys.exit(f"{MARQUE} est entierement transparent.")
    im = im.crop(boite)
    # Ronge l'alpha d'un pixel : retire les pixels de bord blanchâtres laissés
    # par le fond blanc d'origine, qui formaient un liseré clair sur le marine.
    alpha = (
        im.split()[3]
        .filter(ImageFilter.MinFilter(3))
        .filter(ImageFilter.GaussianBlur(0.6))
    )
    im.putalpha(alpha)
    return im


def pose(src: Image.Image, taille: int, part: float, fond=(0, 0, 0, 0)) -> Image.Image:
    """Centre la source dans une toile carrée, à la fraction demandée."""
    cible = taille * part
    echelle = min(cible / src.width, cible / src.height)
    nw = max(1, round(src.width * echelle))
    nh = max(1, round(src.height * echelle))
    reduit = src.resize((nw, nh), Image.LANCZOS)
    toile = Image.new("RGBA", (taille, taille), fond)
    toile.paste(reduit, ((taille - nw) // 2, (taille - nh) // 2), reduit)
    return toile


def ecrit_android(marque: Image.Image) -> list[str]:
    res = RACINE / "android" / "app" / "src" / "main" / "res"
    if not res.is_dir():
        return []
    ecrits = []
    for densite, facteur in DENSITES_ANDROID.items():
        dossier = res / f"mipmap-{densite}"
        dossier.mkdir(parents=True, exist_ok=True)

        # Icône héritée : Android < 8, et lanceurs qui ignorent l'adaptatif.
        icone = pose(marque, round(48 * facteur), PART_ICONE, NAVY).convert("RGB")
        icone.save(dossier / "ic_launcher.png")
        ecrits.append(f"mipmap-{densite}/ic_launcher.png")

        # Couche avant de l'icône adaptative : 108dp, écusson dans la zone sûre.
        avant = pose(marque, round(108 * facteur), PART_ADAPTATIF)
        avant.save(dossier / "ic_launcher_foreground.png")
        ecrits.append(f"mipmap-{densite}/ic_launcher_foreground.png")

    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(ADAPTIVE_XML, encoding="utf-8")
    ecrits.append("mipmap-anydpi-v26/ic_launcher.xml")

    values = res / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "ic_launcher_background.xml").write_text(
        COULEUR_XML.format(couleur=NAVY_HEX), encoding="utf-8"
    )
    ecrits.append("values/ic_launcher_background.xml")
    return ecrits


def ecrit_macos(marque: Image.Image) -> list[str]:
    dossier = RACINE / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    if not dossier.is_dir():
        return []
    ecrits = []
    for taille in TAILLES_MACOS:
        pose(marque, taille, PART_ICONE, NAVY).convert("RGB").save(
            dossier / f"app_icon_{taille}.png"
        )
        ecrits.append(f"AppIcon.appiconset/app_icon_{taille}.png")
    return ecrits


def ecrit_windows(marque: Image.Image) -> list[str]:
    dossier = RACINE / "windows" / "runner" / "resources"
    if not dossier.is_dir():
        return []
    # Le .ico porte plusieurs résolutions : Windows choisit selon le contexte
    # (barre des tâches, explorateur, alt-tab).
    images = [
        pose(marque, t, PART_ICONE, NAVY).convert("RGB") for t in TAILLES_ICO
    ]
    images[-1].save(
        dossier / "app_icon.ico", format="ICO", sizes=[(t, t) for t in TAILLES_ICO]
    )
    return ["runner/resources/app_icon.ico"]


def ecrit_web(marque: Image.Image) -> list[str]:
    dossier = RACINE / "web"
    if not dossier.is_dir():
        return []
    ecrits = []
    pose(marque, 32, PART_ICONE, NAVY).convert("RGB").save(dossier / "favicon.png")
    ecrits.append("web/favicon.png")

    icones = dossier / "icons"
    icones.mkdir(exist_ok=True)
    for taille in (192, 512):
        pose(marque, taille, PART_ICONE, NAVY).convert("RGB").save(
            icones / f"Icon-{taille}.png"
        )
        ecrits.append(f"web/icons/Icon-{taille}.png")
        # Variante « maskable » : le navigateur peut la rogner en cercle, donc
        # l'écusson se rentre davantage.
        pose(marque, taille, PART_MASKABLE, NAVY).convert("RGB").save(
            icones / f"Icon-maskable-{taille}.png"
        )
        ecrits.append(f"web/icons/Icon-maskable-{taille}.png")
    return ecrits


def main():
    marque = ecusson_propre()
    print(f"logo court : {marque.width}x{marque.height} apres recadrage")
    if not LOGO_LONG.exists():
        print(f"note       : {LOGO_LONG.name} absent, ignore")

    total = []
    for nom, fonction in (
        ("android", ecrit_android),
        ("macos", ecrit_macos),
        ("windows", ecrit_windows),
        ("web", ecrit_web),
    ):
        ecrits = fonction(marque)
        if ecrits:
            print(f"{nom:9}: {len(ecrits)} fichier(s)")
            total += ecrits
        else:
            print(f"{nom:9}: plateforme absente, ignoree")

    if not total:
        sys.exit("Aucune plateforme trouvee : lancer depuis la racine du depot.")
    print(f"\n{len(total)} fichier(s) ecrit(s).")


if __name__ == "__main__":
    main()
