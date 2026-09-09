# Les planches de sprites

Un dossier = une planche (Direction artistique, 2026-09-06). Chaque PNG y est une case de 64 × 64, ou une planche de cases lues de haut en bas puis de gauche à droite ; les fichiers se lisent dans l'ordre de leurs noms (numérote-les). Le jeu assemble le dossier au premier usage.

- `membres/<segment>/` : la case fait la LONGUEUR du segment, centrée sur son axe, le dessin du bas (l'articulation) vers le haut (le bout) ; la gauche est le miroir de la droite ; une case par carrure (mince, moyenne, large, trapue, athletique) ; en blanc-gris, le jeu teinte.
- `visage/<trait>/` : la case est la TÊTE ENTIÈRE (un carré de 2,6 rayons de tête, centré), le trait à sa place ; une case par valeur du locus, dans l'ordre de `data/apparence.json` ; en blanc-gris, le jeu teinte (peau, cheveux, encre).
- `terrain/<materiau>.png` : la texture d'une matiere du decor, une case de 64 x 64, repetee par tuile. Une matiere qui a son fichier est **peinte** ; celles qui n'en ont pas gardent le grain **calcule** par `shaders/grain.gdshader`. Le soleil et la lumiere de la tuile s'appliquent aux deux.
- `objets/<id>/` : la case de l'icône ; la variante visuelle de l'objet choisit la case. `objets/<id>.png` (un seul fichier) reste valable.

`00_substitution.png` est un gabarit généré par `tools/gen_planches_substitution.py` : remplace-le par tes cases, ou supprime-le. Un fichier dont la taille n'est pas un multiple de 64 est ignoré (`tools/verif_sprites.py` le signale).

## Les points d'un visage (2026-09-09)

`06_museau.png` porte le dessin, **`06_museau.points.png` porte les points** : transparent partout, sauf un pixel de couleur franche par élément à ancrer. Le jeu s'en sert pour poser les yeux, le nez, la bouche et les oreilles **là où cette tête-là les veut** — tu ne mets rien dans ton sprite.

- **Une couleur par élément**, dans `data/styles.json → planches.marqueurs` : yeux `#ff0000`, nez `#00ff00`, bouche `#0000ff`, oreilles `#ffff00`, cheveux `#ff00ff`, pilosité `#00ffff`, sourcils `#ff8000`, barbe `#8000ff`, mâchoire `#00ff80`, menton `#ff0080`, pommettes `#80ff00`, implantation `#0080ff`.
- **Deux pixels de la même couleur** (les deux yeux, les deux oreilles) = deux ancres : l'élément est dessiné deux fois.
- **Un fichier de points n'est PAS une case** : il ne compte pas dans la numérotation, il ne se dessine jamais.
- **Sur un trait** (un œil, une oreille), un point dans son propre calque en fait une **pièce** : dessine-la au centre de la case, mets le point au même endroit, et le jeu la posera sur chaque ancre de la tête. Sans point, ta planche reste un visage entier, comme avant.
- Sans calque, **rien ne change** : une tête sans points place les traits comme elle l'a toujours fait.
