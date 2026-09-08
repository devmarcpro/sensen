# Les planches de sprites

Un dossier = une planche (Direction artistique, 2026-09-06). Chaque PNG y est une case de 64 × 64, ou une planche de cases lues de haut en bas puis de gauche à droite ; les fichiers se lisent dans l'ordre de leurs noms (numérote-les). Le jeu assemble le dossier au premier usage.

- `membres/<segment>/` : la case fait la LONGUEUR du segment, centrée sur son axe, le dessin du bas (l'articulation) vers le haut (le bout) ; la gauche est le miroir de la droite ; une case par carrure (mince, moyenne, large, trapue, athletique) ; en blanc-gris, le jeu teinte.
- `visage/<trait>/` : la case est la TÊTE ENTIÈRE (un carré de 2,6 rayons de tête, centré), le trait à sa place ; une case par valeur du locus, dans l'ordre de `data/apparence.json` ; en blanc-gris, le jeu teinte (peau, cheveux, encre).
- `terrain/<materiau>.png` : la texture d'une matiere du decor, une case de 64 x 64, repetee par tuile. Une matiere qui a son fichier est **peinte** ; celles qui n'en ont pas gardent le grain **calcule** par `shaders/grain.gdshader`. Le soleil et la lumiere de la tuile s'appliquent aux deux.
- `objets/<id>/` : la case de l'icône ; la variante visuelle de l'objet choisit la case. `objets/<id>.png` (un seul fichier) reste valable.

`00_substitution.png` est un gabarit généré par `tools/gen_planches_substitution.py` : remplace-le par tes cases, ou supprime-le. Un fichier dont la taille n'est pas un multiple de 64 est ignoré (`tools/verif_sprites.py` le signale).
