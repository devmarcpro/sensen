---
aliases: ["E.30", "Annexe E.30", "Minimap", "Brouillard de guerre"]
tags: [monde, interface, technique, décidé]
domaine: monde
statut: décidé
etape: 8
---

> [!note] Adapté au pivot tactique
> La « coupe au niveau Y » et le bitmask par bande verticale sont retirés — archivés dans le GDD source. Version 2D détaillée : [[Décision — Minimap en 2D]].

Une minimap toujours visible, un brouillard de guerre par chunk — une carte en surface, une par étage en donjon.

```
AFFICHAGE — toujours visible à l'écran (coin, façon roguelike).
  SURFACE : une seule carte — le monde tactique est une grille unique
  + hauteur ; teinte par matériau dominant du chunk + ombrage dérivé
  de la hauteur (le relief est une information tactique, 9).
  DONJON : la minimap affiche l'étage courant ; changer d'étage change
  la carte — chaque étage est une grille séparée (3.5).

BROUILLARD DE GUERRE — seules les zones explorées sont visibles, le
  reste est noir. "Exploré" = traversé par le cône de détection/
  vision du joueur (E.16) au passage.

STOCKAGE (perf, cohérent avec G) — résolution CHUNK :
    surface : explored[cx, cz]                  → 1 bit par chunk 32×32
    donjon  : explored[dungeon_id, floor, chunk] → un bitmask par étage
  Bitmask compact, un set par joueur, sauvegardé dans le profil
  (E.10) — persiste entre sessions.

RENDU — échantillonnage des chunks explorés dans un rayon autour du
  joueur ; teinte simplifiée par matériau dominant (pas de rendu
  plein, juste une couleur) ; PNJ/monstres détectés affichés en
  surcouche (icônes), pas de mémoire dédiée (état live, pas de fog
  par entité).
  Coût : mise à jour incrémentale sur `chunk_explored` (événement
  EventBus, E.12) — jamais de recalcul de zone.
```

> [!success] Décidé le 2026-08-28 — le joueur découvre la carte avec sa vision (instruction du designer)
> « Le joueur doit découvrir la map avec sa vision, les PNJ hors de portée ne sont pas affichés. » Codé dans le prototype, côté simulation (le serveur sait ce que chaque être voit) : à chaque pas, le **champ de vue** d'un être contrôlé par un joueur = les tuiles à portée de **Perception × `engagement.detection_par_perception`** (la même portée que la détection des créatures — [[IA des créatures]]) et en **ligne de vue** (relief et murs, `Grille.ligne_de_vue`). Les tuiles vues sont **mémorisées** sur la grille de l'étage (`decouvert`, résolution tuile dans le prototype ; le bitmask par chunk de cette note reste la cible pour la sauvegarde). Le client ne dessine que les tuiles découvertes, en **grisé** hors du champ de vue actuel ; **les êtres ne sont affichés que dans le champ de vue** (barres, prévisualisation, liste des prochaines actions comprises) — état live, pas de mémoire par entité, comme dit plus haut. La mémoire suit l'étage quand on le quitte et y revient. Même règle en arène.

> [!success] Précisé le 2026-08-28
> La minimap est codée ([[Décision — Minimap en 2D]]) ; l'exploration à **résolution chunk** (`explored[cx, cy]`, sauvegardée) coexiste avec la mémoire par tuile du rendu grisé : le chunk devient exploré dès qu'une de ses tuiles est vue.

> [!success] Corrigé le 2026-08-30 — les murs mémorisés sont des blocs pleins
> **Retour du designer** : « les blocs du donjon sont transparents et incomplets ». Le brouillard peignait un hexagone **translucide** sur chaque mur mémorisé (on voyait le bloc au travers), et effaçait un mur **jamais vu** en couleur de fond alors que son voisin visible avait sauté la face qu'il « cachait » : des blocs creux. Désormais la passe du terrain ne dessine que les tuiles **découvertes** et se redessine à chaque découverte (coût mesuré : 4,3 ms par image en donjon, 6 ms au camp) ; un mur mémorisé hors de vue est **redessiné en bloc sombre et opaque** ; une face n'est sautée que si le mur devant est découvert. Le sol mémorisé garde son voile translucide.

> [!success] Décidé et codé le 2026-08-30 — la minimap est la cellule
> **Instruction du designer** : « la minimap représente uniquement la cellule dans laquelle le joueur est ; deux fois plus petite ; en haut à droite ; compas et Wu Xing en dessous ». Plus de chunks ni de zooms : `Minimap` dessine la **cellule courante** (64 × 64 tuiles) en 128 × 128 px, 2 px par tuile — tuiles **découvertes** seulement (eau, mur/roche, végétation, porte, sol du matériau éclairci par la hauteur), le reste noir ; le joueur et les êtres en vue en points. Elle marche aussi **en donjon** (un étage = une cellule) et en arène. Le bit d'exploration par chunk (`Monde.explores`) reste pour la carte du monde. Le HUD descend : compas puis pentagramme sous la minimap.

## Liens
- **Dépend de** : [[Grille continue]], [[IA des créatures]], [[Sauvegarde]]
- **Alimente** : [[Écrans d'interface]], [[Donjons — structure et intégration]]
- **Voir aussi** : [[Décision — Minimap en 2D]], [[Carte du monde]], [[EventBus]], [[Ordre de construction]]
