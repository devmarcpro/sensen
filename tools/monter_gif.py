#!/usr/bin/env python3
"""Monte une suite d'images de capture en GIF animé.

Godot ne sait pas écrire de GIF : `capture.tscn -- --gif N` rend N PNG espacés, et ce script les
assemble. Usage : python tools/monter_gif.py <prefixe> <sortie.gif> [largeur] [ms par image]
"""
import glob, os, sys
from PIL import Image

prefixe = sys.argv[1]
sortie = sys.argv[2]
largeur = int(sys.argv[3]) if len(sys.argv) > 3 else 900
duree = int(sys.argv[4]) if len(sys.argv) > 4 else 400

fichiers = sorted(glob.glob(prefixe + "_*.png"))
if not fichiers:
    print("aucune image pour %s_*.png" % prefixe)
    sys.exit(1)
images = []
for f in fichiers:
    im = Image.open(f).convert("RGB")
    h = int(im.height * largeur / im.width)
    images.append(im.resize((largeur, h), Image.LANCZOS).quantize(colors=192, method=Image.MEDIANCUT))
images[0].save(sortie, save_all=True, append_images=images[1:], duration=duree, loop=0, optimize=True)
print("%s : %d images, %.1f Mo" % (sortie, len(images), os.path.getsize(sortie) / 1048576.0))
