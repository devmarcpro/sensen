# Les planches de sprites

Un dossier = une planche (Direction artistique, 2026-09-06). Chaque PNG y est une case de 64 × 64, ou une planche de cases lues de haut en bas puis de gauche à droite ; les fichiers se lisent dans l'ordre de leurs noms (numérote-les). Le jeu assemble le dossier au premier usage.

- `membres/<segment>/` : la case fait la LONGUEUR du segment, centrée sur son axe, le dessin du bas (l'articulation) vers le haut (le bout) ; la gauche est le miroir de la droite ; une case par carrure (mince, moyenne, large, trapue, athletique) ; en blanc-gris, le jeu teinte.
- `visage/<trait>/` : la case est la TÊTE ENTIÈRE (un carré de 2,6 rayons de tête, centré), le trait à sa place ; une case par valeur du locus, dans l'ordre de `data/apparence.json` ; en blanc-gris, le jeu teinte (peau, cheveux, encre).
- `terrain/<materiau>.png` : la texture d'une matiere du decor, une case de 64 x 64, repetee par tuile. Une matiere qui a son fichier est **peinte** ; celles qui n'en ont pas gardent le grain **calcule** par `shaders/grain.gdshader`. Le soleil et la lumiere de la tuile s'appliquent aux deux.
- `objets/<id>/` : la case de l'icône ; la variante visuelle de l'objet choisit la case. `objets/<id>.png` (un seul fichier) reste valable.

`00_substitution.png` est un gabarit généré par `tools/gen_planches_substitution.py` : remplace-le par tes cases, ou supprime-le. Un fichier dont la taille n'est pas un multiple de 64 est ignoré (`tools/verif_sprites.py` le signale).

## Déposer un sprite : tu poses, l'outil range (2026-09-10)

Pose ton PNG **à la racine du dépôt** et lance :

```
python tools/entrer_sprites.py [--remplacer]
```

Il le met à sa place, lui donne sa valeur de locus, sa clé de traduction et son calque de points. **Il copie, il ne déplace jamais** : ta racine reste ta racine (elle est ignorée par git).

- **Nomme par `<trait> <jeu>.png`** — `tete poisson.png`, `yeux poisson.png`, `bouche poisson.png`. L'ordre des deux mots est libre (`insectoide tete.png` marche aussi).
- **Dépose le jeu entier quand tu peux** : les éléments disent où ils vont, et la tête du même jeu reçoit leurs positions comme ancres. C'est pour ça que tu n'as rien à déclarer. Tu peux aussi déposer par morceaux — une bouche aujourd'hui, des oreilles demain : la tête déjà en place apprend les nouvelles ancres.
- **Un équipement doit dire sa construction** : `casque plaque.png`, pas `casque.png`. La planche d'un slot est indexée par construction (matelasse, cuir, mailles, écailles, plaque, tissu, rituel), et deviner à ta place mettrait un heaume d'acier sur la ligne du matelassé sans que personne ne s'en aperçoive.
- **Un membre** se nomme par son segment : `torse.png`, `bras_haut.png`.
- **Ce qu'il ne sait pas placer, il le dit et n'y touche pas.** Une case qui existe déjà n'est jamais écrasée sans `--remplacer`.
- **Il refuse un dessin en couleur** : une planche se dessine en nuances de gris, le jeu la teinte. Il ne convertit pas tout seul — décider à ta place de ce qu'est ton dessin n'est pas son rôle.

Ensuite : `godot --headless --path godot --import`, et regarde le résultat avec `capture.tscn -- --galerie combinaisons --cadre-tete`.

## Les points d'attache (2026-09-09, refaits le 2026-09-10)

`06_museau.png` porte le dessin, **`06_museau.points.png` porte les points** : transparent partout, sauf un **bloc de 2 × 2** de couleur franche par chose à ancrer. Tu ne mets rien dans ton sprite.

**Pipette les couleurs dans `assets/marqueurs_legende.png`** : une ligne par élément, trois colonnes (base, annexe 1, annexe 2). Elles sont aussi écrites dans `data/styles.json → planches.marqueurs.couleurs`.

**Une seule règle, la même pour le visage et pour le corps :**

- un **CONTENANT** porte les ancres de ses enfants — une tête porte `yeux`, `nez`, `bouche`, `oreilles` ; un torse porte `bras`, `jambe`, `tete` ;
- une **PIÈCE** porte son propre point — un œil porte `yeux` ; un bras porte `attache` (son articulation) et `bout` (son extrémité).

**Ce qu'il faut savoir en dessinant :**

- **La taille est libre.** Le jeu réunit les pixels voisins de même couleur en UN point posé sur leur centre : 1 × 1, 2 × 2 ou une tache de trois pixels donnent tous un point. Dessine en 2 × 2, c'est ce que tu vois.
- **Deux blocs de la même couleur** (les deux yeux, les deux épaules) = deux ancres, triées de gauche à droite.
- **Les rangs.** La couleur de la colonne « base » est celle qui sert toujours. Les deux autres colonnes sont des attaches **annexes** : elles ne servent que si un être les réclame (un troisième œil, un bras de mutant). Tu peux en placer sans que rien ne change aujourd'hui — c'est fait pour.
- **Ne colle pas deux blocs.** S'ils se touchent, le jeu n'en verra qu'un ; le générateur, lui, refuse d'écraser et te le dit.
- **Un fichier de points n'est PAS une case** : il ne compte pas dans la numérotation, il ne se dessine jamais.
- **Sans calque, rien ne change** : une planche sans points se place comme elle l'a toujours fait.
- **Pour un membre**, la case est carrée et posée le **bas sur l'articulation**, le **haut sur le bout**. Un `attache` ailleurs qu'en bas au milieu décale ton dessin pour que ce point tombe pile sur le joint.
- **Un œil, une oreille : dessine-en UN SEUL**, au centre de la case, et mets son point au même endroit. Le jeu le pose sur chaque ancre de la tête et **retourne celui de droite** — c'est ce qui fait qu'un museau, un crâne d'insecte ou une tête difforme placent enfin leurs yeux là où *leur* forme les veut. (Les planches livrées ont été coupées en deux le 2026-09-10 ; elles contenaient la paire, et une paire ne peut être posée qu'à un seul endroit.)
- **Le générateur ne te pose des points que sur les têtes et les membres**, parce que ses marqueurs y valent exactement ce que le jeu faisait déjà — rien ne bouge. Sur un œil ou une oreille il s'abstient : y poser un point déclarerait ton dessin « pièce à répéter », et s'il contenait la paire on en dessinerait quatre. Ce choix-là est le tien.
- **Ton dessin reste en nuances de gris** (le jeu le teinte) : c'est ce qui permet à une couleur franche de ne jamais être ambiguë. Un sprite peint en couleur peut faire croire à un marqueur — c'est arrivé.
