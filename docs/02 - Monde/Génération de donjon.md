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

> [!success] Décidé le 2026-08-27 (nuit) — procédural façon Elin / Tales of Maj'Eyal, **remplace le labyrinthe**
> Précision du designer : « générer procéduralement aléatoire, pas des boîtes en séries, donc des couloirs, des petites et grandes salles, et que chaque étage soit différent ». Le labyrinthe sur trame et les salles alignées sont abandonnés. Un étage (cellule 64×64) : des **salles de trois tailles** (`tailles_salles` du thème : petites 3-5, moyennes 6-9, grandes 10-16, tirées selon `poids_salles`), posées au hasard sans chevauchement ; des **couloirs sinueux** de 2 à 3 tuiles (`couloirs` du thème : chance de virage, boucles, impasses) qui relient chaque salle à la précédente, puis quelques boucles et impasses ; connexité vérifiée par BFS. Le reste est du mur destructible. Deux escaliers par étage, seed(monde, id, étage) : chaque étage est différent, stable au retour.

> [!success] Décidé le 2026-08-28 — plus de salles, plus de couloirs, **beaucoup moins linéaire, plus labyrinthe**
> Instruction du designer. Cellule de **128×128** ([[Grille continue]]), **14 à 24 salles** par étage. Le réseau n'est plus une chaîne : chaque salle est reliée à ses **3 plus proches voisines** (`couloirs.voisins_relies`), puis 6 à 12 boucles entre salles au hasard, puis 10 à 20 impasses de 6 à 24 pas ; les couloirs virent plus souvent (`virage` 0.35) et font 1 à 3 tuiles. Le résultat est un réseau maillé où plusieurs chemins mènent à l'escalier — le sens du labyrinthe vient des boucles et des impasses, pas d'une trame.

> [!success] Décidé et codé le 2026-08-30 — les **décors de salles** : piliers cassables, estrades, fosses (arènes-puzzle, additif approuvé)
> Les salles procédurales étaient des rectangles nus. Chaque thème porte désormais une liste `decors` (données) que `Donjon._poser_decors` applique aux salles **moyennes et grandes**, au dé : des **piliers** (un mur du matériau du thème, donc **destructible** et **creusable**, jamais collé à un bord ni au centre — on se cache derrière, on le fait sauter à la bombe), une **estrade** (un sous-rectangle rehaussé de 1 ou 2 : la hauteur donne l'avantage aux coups et à la portée, et une projection depuis le bord fait chuter), une **fosse** (un sous-rectangle abaissé de `chute_delta` : y tomber coûte des PV, y pousser quelqu'un aussi — les dégâts de poussée du jour). Le centre de la salle reste libre (escaliers, boss, spawns le lisent). Les couloirs, la connexité et les escaliers ne changent pas : les décors se posent **après** la connexité et ne touchent qu'à l'intérieur des salles. **Chiffres** en données par thème (`chance`, `n`, `delta`, `taille`) — le repaire a plus de fosses, la ruine plus de piliers et d'estrades.

> [!success] Décidé et codé le 2026-08-30 — des **portes** (villes et salles de donjon)
> **Instruction du designer** : « rajouter des portes au jeu, pour les bâtiments dans les villes et certaines salles dans les donjons ». Deux contenus de tuile : `porte` (**ouverte** : on passe, on voit) et `porte_fermee` (**fermée** : bloque le passage et la vue, **destructible** — une bombe ou la pioche l'emportent). **S'ouvre au passage** : marcher vers une porte fermée l'ouvre (le pas est dépensé, `actions.objet` ticks) puis on passe au pas suivant — joueur comme PNJ, et le chemin de l'IA (`Grille.chemin`) traverse les portes fermées avec un surcoût au lieu de les tenir pour des murs. **Se ferme** par le clic droit / E (option *Ouvrir / fermer la porte*), jamais sur un être. **Villes** : le `P` des plans de bâtiments pose désormais une porte **fermée** — les PNJ l'ouvrent en rentrant chez eux. **Donjons** : `theme.portes` (0,5 en ruine, 0,3 en repaire) est la chance qu'une salle ait ses seuils fermés — un seuil est une tuile de sol du bord de la salle qui touche un couloir ; les portes sont posées par `Grille.depuis_etage` à partir de `etage.portes`. Une porte fermée coupe la vue : une salle fermée est une salle qu'on ouvre à l'aveugle.

> [!success] Corrigé le 2026-08-31 — les spawns restent au sol plat
> La sonde de parcours a trouvé un Rôdeur **visible mais sans chemin** (consigné dans [[À juger — parcours de jeu]]) : `_peupler` tirait ses tuiles sans lire les hauteurs des décors — une créature pouvait naître **dans une fosse** (−`chute_delta` : impossible d'en sortir, l'A* n'y entre jamais — une prison à ennemi) ou **sur une estrade**. La note voulait déjà l'inverse (« le centre reste libre : escaliers, boss, spawns le lisent ») : les spawns ne se posent désormais que sur des tuiles à la hauteur de base de l'étage. Pousser un ennemi dans une fosse reste bien sûr permis — c'est le décor qui joue, pas la naissance.

> [!success] Décidé et codé le 2026-08-31 — de vrais escaliers, pris en marchant (designer, point 36)
> Les losanges doré et vert deviennent de **vraies marches dessinées par code** (quatre degrés qui rétrécissent, doré = descente, vert = montée), et **marcher sur l'escalier change d'étage automatiquement** : le pas du joueur qui arrive sur la cage déclenche la descente (ou la remontée — sur l'étage 1, elle fait ressortir au camp). Les intentions `descendre`/`remonter`, la touche E et les options contextuelles restent valables (les tests et la triche s'en servent), mais ne sont plus nécessaires. Le spawn sur l'escalier d'arrivée ne re-déclenche rien : seul un **pas** sur la tuile compte. Les PNJ ne changent jamais d'étage. Le robot de parcours détecte le changement d'étage au lieu de l'ordonner.

> [!success] Décidé et codé le 2026-08-31 — des donjons carrés (designer, point 46)
> Le designer tranche contre l'organique : **salles carrées de toutes tailles** (4-6, 8-11, 13-17 et des **salles immenses** de 20 à 26 côtés), **couloirs droits** — un L franc, plus de marche au hasard — de deux à trois tuiles de large, et des **branchements** rectilignes plus nombreux (6 à 12 par étage). Deux drapeaux en données le pilotent, `salles_carrees` et `couloirs.droits` : un thème peut redevenir sinueux sans toucher au code. Les grands espaces ouverts viennent des salles immenses et des couloirs larges, pas d'un bruit de terrain.
>
> Au passage, deux règles du même jour : **tous les ennemis lâchent du loot** (`chance_tout_venant` passe de 0,25 à 1) et les **coffres doublent** (une tuile sur 18 au lieu de 40, un à trois objets). Un **meuble n'occupe plus toute sa case** : chaque fiche porte une `emprise` (0,58 pour un coffre, 0,78 pour un lit ou une station) et le bloc est dessiné d'autant plus petit et plus bas. Enfin, **E ne casse plus les blocs ni le sol** : creuser un mur, abaisser ou élever une tuile disparaissent du menu.

> [!success] Codé le 2026-09-01 — une porte est une porte, et il n'y en a qu'une par seuil (designer)
> **Instruction** : « fais en sorte que les portes ne soient pas des blocs complets mais vraiment des portes et qu'il y en ait qu'une de générée, pas deux côte à côte ». Deux défauts distincts. **Au dessin** : une porte fermée bloque le passage, et tout ce qui bloque le passage était rendu par `_dessine_bloc` — un cube plein, indiscernable d'un mur. Elle est désormais dessinée comme un **battant** : le sol de la tuile, deux montants, un panneau dressé en travers de l'ouverture (l'axe est déduit des murs voisins), une poignée ; ouverte, le battant se range contre son montant et laisse le seuil libre. **À la génération** : `_poser_portes` marquait *chaque* tuile de bord touchant un couloir — un couloir large de deux tuiles, ou un angle de salle, donnait deux portes côte à côte. Les seuils contigus sont maintenant **groupés en ouvertures** et une seule tuile par ouverture reçoit son battant (celle du milieu).


## Liens
- **Dépend de** : [[Donjons — structure et intégration]], [[Salles et connecteurs]], [[Unification macro-micro]], [[Dérive de la corruption]]
- **Alimente** : [[Loot — affixes, gemmes et rareté]], [[Trésors et artefacts]], [[Créatures]], [[Gabarit de quête]]
- **Voir aussi** : [[Squelette modulaire et points d'attache]], [[Simulation du monde — performance]], [[EventBus]], [[Minimap et brouillard de guerre]], [[Ouvert — Taille des salles de donjon]]
