---
aliases: ["E.29", "Annexe E.29", "Génération de donjon", "Génération procédurale des donjons"]
tags: [monde, donjon, technique, décidé]
domaine: monde
statut: décidé
etape: 2
---

> [!note] Adapté au pivot tactique
> Tailles exprimées en tuiles par étage et escaliers en liens inter-étages (valeurs décidées : [[Décision — Prefabs de donjon en tuiles]]). Les cubes voxel d'origine sont archivés dans le GDD source.

L'algorithme de génération par graphe, étage par étage, et la formule de difficulté par profondeur.

```
BIBLIOTHÈQUE — deux familles de prefabs 2D (schéma B.10) :
  SALLES : catégories de taille en tuiles par étage (petite
    8×8, moyenne 16×16, grande 24×24, immense 32×32), forme libre,
    sol NON obligatoirement plat (fosses, marches, plateformes — la
    hauteur de tuile 0-20 est encodée dans le plan du prefab).
    Points d'attache = tuiles-marqueurs typées (même technique
    que 12.1) : porte_nord/sud/est/ouest, cage_escalier.
  CONNECTEURS : corridor_droit, corridor_coude, corridor_T,
    escalier (lie (étage n, tuile a) → (étage n+1, tuile b)),
    porte_simple, rampe.

GÉNÉRATION PAR ÉTAGE (graphe, façon Daggerfall) :
  1. Placer la salle d'entrée à la position fixe (sous le point
     d'entrée de surface, 3.5).
  2. Boucle : choisir un point d'attache libre au hasard parmi les
     salles déjà placées → tirer un connecteur compatible avec son
     type → tirer une salle compatible avec l'autre bout du
     connecteur → tester la collision AABB contre tout le déjà-placé
     → si collision, retirer (max 8 essais) sinon placer.
     Répéter jusqu'au nombre cible de salles de l'étage (3.5) ou
     échec de placement répété (accepter l'étage tel quel — pas de
     boucle infinie).
  3. Connexité garantie par construction (chaque salle n'est ajoutée
     que reliée à l'existant) — pas de vérification a posteriori.
  4. Si un étage suivant existe : convertir 1 point d'attache libre
     d'une salle profonde (distance de graphe maximale à l'entrée)
     en cage d'escalier vers le bas.
  5. Étage le plus profond : la salle la plus distante de l'entrée
     (BFS sur le graphe) est taguée `boss_room` (tirage de la
     créature la plus dangereuse du profil du donjon + artefact
     garanti si donjon majeur, 3.1).
  6. Peuplement : chaque salle reçoit 0-N créatures (poids par
     `special_tags`, profil du donjon) et 0-N contenants de loot,
     depuis les tables standards (bestiaire F.3, profils de PNJ, effets F.7)
     modulées par la formule
     de profondeur ci-dessous.
  Coût : génération en thread au premier accès à l'étage (paresseuse,
  comme le reste du monde, E.2) — un étage jamais atteint ne coûte
  rien. Déterministe par seed(monde, id_donjon, étage).

DIFFICULTÉ/LOOT PAR PROFONDEUR :
  corruption_effective_etage = corruption_locale (E.20) + etage * 8
    (plafonnée à 100) — utilisée pour le niveau des spawns (F.3) et
    la qualité/rareté du loot (A.3/A.8), indépendamment de la
    corruption de surface.

THÈME ET PALETTE — un donjon tire un thème à sa génération (ruine,
  crypte, mine effondrée, repaire) qui sélectionne : la palette de
  remapping (9.1/9.2), le pool de créatures (F.3), et les tags
  `floor_theme` filtrant les salles/connecteurs éligibles.

TERRAIN DE SURFACE (3.5) — au moment de la génération du POI (E.2),
  la colonne de terrain normale de la cellule est remplacée par une
  structure d'entrée scellée (petite bibliothèque de prefabs de
  surface dédiée, même système de palette) + terrain environnant
  rendu impraticable (falaises/éboulis générés, pas de mur infini
  artificiel — cohérent avec un monde entièrement destructible).

NETTOYAGE ET DISPARITION (3.5) : à la mort du boss (`creature_killed`
  sur l'entité `boss_room`), le donjon passe en état "nettoyé" —
  timer de 1,5 jour in-game (timer wheel, G.6) puis : le volume de
  chunks du donjon est marqué à régénérer, la cellule redevient
  éligible à la génération de terrain normale + au claim (3.3).
```

**Signal :** `dungeon_cleared` sur l'EventBus, écouté par le timer de disparition et les quêtes de guilde ([[EventBus]]).

> [!success] Codé le 2026-08-27 — `systems/worldgen/donjon.gd`
> L'algorithme par graphe tel quel : salle d'entrée au centre d'une grille de 96×96 (le « point fixe » — la surface n'existe pas encore), attache libre au hasard → connecteur (hors escalier) dont une porte fait face → salle dont une porte fait face à l'autre bout → collision AABB avec **1 tuile de marge** contre tout le déjà-placé (max 8 essais, 32 échecs consécutifs arrêtent l'étage), connexité par construction, escalier posé sur la salle de distance de graphe maximale, boss au plus loin de l'entrée au dernier étage, peuplement par le **thème** (`data/dungeon_themes/` : pool de créatures, boss, `tuiles_par_creature`, `croissance_par_etage` = +25 % par étage, nombre d'étages et de salles). Le plein de l'étage est un contenu de tuile `roche` (bloque passage et vue). Déterministe par `hash(graine, id_donjon, étage)`. Mesuré : un étage de 12 salles en **quelques ms** (critère É2 : < 100 ms). L'escalier est une intention `descendre` sur la cage : l'être **change de grille avec son état** (PV, mana, sac, XP, compétences) — instance ≠ définition. La formule de profondeur (`corruption + étage × 8`) attend le niveau des créatures (étape 4) ; en attendant, la profondeur augmente seulement la densité.

> [!success] Décidé le 2026-08-27 — le donjon est un labyrinthe dans une cellule (instruction du designer)
> « Plutôt que des salles, un labyrinthe avec des salles, tout ça contenu dans une cellule, murs destructibles et à étage, à chaque étage deux escaliers : un vers le haut et un vers le bas. » Codé dans `systems/worldgen/donjon.gd` : chaque étage occupe **une cellule de 128×128** ; les salles de la bibliothèque (8 à 14 par étage, `salles_par_etage` du thème) sont posées sans chevauchement, puis un **labyrinthe** (backtracker sur une trame de 4 tuiles : couloirs de 3, murs de 1) remplit tout le reste ; les portes des salles s'ouvrent sur le couloir voisin, la connexité est vérifiée par BFS et réparée par une tranchée. **L'escalier montant** (l'arrivée) est dans la première salle, **l'escalier descendant** dans la salle la plus lointaine (BFS) — le boss l'y remplace au dernier étage. Le plein est du **mur destructible** (`mur`, [[Destruction du terrain]]), le bord de la cellule est de la **roche** indestructible. Déterministe par seed(monde, id, étage). Les connecteurs de la bibliothèque restent en données mais ne servent plus : le labyrinthe est le connecteur.

> [!success] Décidé le 2026-08-27 (soir) — salles procédurales façon Elin, cellule de 64×64
> Instruction du designer : « donjons générés procéduralement à la Elin ». Les salles ne viennent plus de la bibliothèque de prefabs : ce sont des **rectangles tirés au hasard** (`taille_salles` du thème, 4 à 9 tuiles de côté), posés sans chevauchement sur la trame du labyrinthe, avec **1 à 3 portes** sur des côtés au hasard ; le labyrinthe remplit le reste et relie tout. Un étage = **une cellule de 64×64** ([[Grille continue]]), 4 à 8 salles. Chaque étage est différent (seed(monde, id, étage)) mais stable au retour. La bibliothèque `data/dungeon_rooms/` et `data/dungeon_connectors/` reste en données pour un usage futur (salles spéciales, vaults) ; elle n'est plus posée.
> **Densité** : les salles étant petites, `tuiles_par_creature` passe à 30 (ruine) / 24 (repaire) et `tuiles_par_coffre` à 40, avec **au moins un occupant par salle** hors arrivée.
> **Rendu** : les murs sont des **blocs pleins** (dessus + deux flancs) sur toute la fenêtre de vue, plus seulement les murs qui bordent un couloir — le designer avait remarqué des murs « incomplets ».

## Liens
- **Dépend de** : [[Donjons — structure et intégration]], [[Salles et connecteurs]], [[Unification macro-micro]], [[Dérive de la corruption]]
- **Alimente** : [[Loot — affixes, gemmes et rareté]], [[Trésors et artefacts]], [[Créatures]], [[Gabarit de quête]]
- **Voir aussi** : [[Squelette modulaire et points d'attache]], [[Simulation du monde — performance]], [[EventBus]], [[Minimap et brouillard de guerre]], [[Ouvert — Taille des salles de donjon]]
