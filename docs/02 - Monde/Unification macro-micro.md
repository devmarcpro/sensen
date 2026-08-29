---
aliases: ["E.2", "Annexe E.2", "Unification macro/micro", "Génération du monde"]
tags: [monde, génération, technique, décidé]
domaine: monde
statut: décidé
etape: 8
---

> [!note] Adapté au pivot tactique
> Les chiffres d'altitude voxel (« pics à 200-400 blocs », « falaises de 30-80 blocs ») et le bruit 3D de cavernes sont retirés — archivés dans le GDD source. La quantification sur les 21 niveaux de [[Hauteur de terrain ±10]] : [[Décision — Altitude sur 21 niveaux]].

Il n'existe qu'une seule génération : la carte du monde et la cellule sont deux fenêtres sur le même champ de bruit continu. Résout la question ouverte de [[Génération par couches de bruit]] (cohérence carte ↔ cellules ↔ transitions).

```
Il n'existe qu'UNE génération : les couches de bruit sont des fonctions
continues f(x, z) sur les coordonnées MONDE (en tuiles).
- Le biome en un point = résolution des conditions (B.6) sur les valeurs
  de bruit À CE POINT. Les transitions entre biomes sont donc naturellement
  continues (aucun raccord à gérer entre cellules : la cellule n'est qu'une
  fenêtre administrative de 128×128 sur ce champ continu).
- La "case" de la carte du monde affiche le biome échantillonné AU CENTRE
  de la cellule + icônes des POI qu'elle contient. La carte est un
  résumé, jamais une source de vérité.
- Terrain SPECTACULAIRE — l'altitude n'est pas un simple bruit
  lissé ("plat avec un peu de relief" est explicitement un anti-but) :
    altitude(x,z) = continentalité (issue des PLAQUES TECTONIQUES,
      pas d'un bruit libre : voir Décision — Monde fini, continents
      et océan. Donne continents, îles et arcs insulaires ; les
      chaînes de montagnes naissent sur les sutures convergentes)
      + relief modulé par une couche d'ÉROSION/PIC :
        * ridged noise (crêtes) → CHAÎNES DE MONTAGNES, arêtes vives
        * domain warping (le bruit déforme ses propres coordonnées)
          → côtes découpées, vallées sinueuses, formes organiques
        * terrasses conditionnelles (quantification locale de
          l'altitude là où la couche sismique est forte) → FALAISES
          infranchissables (Δ >= 3), mesas, canyons
      + bassins : les minima locaux larges sous le niveau d'eau
        régional → GRANDS LACS (remplis à la génération, sources
        E.22) ; les fleuves suivent le gradient entre lacs et mer.
    La hauteur de tuile (0-20) dérive de ce champ par quantification
    relative au voisinage — Proposition — Altitude sur 21 niveaux.
    Formations rares (hash déterministe, façon POI) : gorges, pitons,
    cratères, arches — modificateurs de relief 2D paramétriques,
    pas de prefabs.
- STRATIFICATION PAR DIFFICULTÉ (verrou de progression naturel) :
  les meilleures ressources vivent dans les zones à haute corruption
  et les étages profonds des donjons — voir Proposition — Minerais
  et strates après le pivot. Combiné à la règle d'irrécoltabilité
  (A.2 : outil trop faible = rebond), atteindre les meilleurs
  matériaux exige de meilleurs outils, trouvés... là où c'est
  dangereux : boucle de progression.
- POI : placement déterministe par hash(seed, cell_x, cell_z) → chaque
  cellule a 0-2 POI tirés selon poi_weights du biome (B.6). Densités par
  défaut : village 4 %, donjon 6 %, camp 8 %, sanctuaire 3 %, filon
  majeur 6 % par cellule. Les donjons sont assemblés procéduralement à
  partir de salles préfabriquées (palettes remapables, 9.2).
- Villes : un village démarre par un centre + N bâtiments préfab posés le
  long de routes générées (bruit + A* sur la carte des pentes), palette
  par biome (9.2).
```

*Détail du terrain : [[Terrain spectaculaire]]. Ressources : [[Décision — Minerais et strates après le pivot]]. Règle d'irrécoltabilité : [[Récolte]].*

> [!success] Codé le 2026-08-28 — les POI par cellule (`Surface.poi_de`)
> Tirage déterministe `hash(seed, cx, cy)` sur les cellules terrestres, aux **densités par défaut** de la note pondérées par `poi_weights` du biome : **donjon 6 %**, **filon majeur 6 %** (un amas de 20 à 40 tuiles de filon) — codés ; villages, camps de monstres et sanctuaires attendent les PNJ (étape 9) et sont notés dans `planete.poi` avec leur densité. La cellule de départ porte toujours un donjon (décision : la boucle d'expédition doit être à portée dès la première heure).

> [!success] Codé le 2026-08-28 — les routes
> Décision (la note ne disait que « routes générées, bruit + A* sur les pentes ») : les routes sont **à l'échelle des cellules**, dans un royaume — chaque village du territoire est relié à la capitale par le **plus court chemin à coût** (danger et altitude renchérissent, même coût que la croissance du territoire), calculé avec le secteur (`Surface.routes_par_cellule`, `route_de(cell)` = cellules voisines reliées). **Dans la cellule**, `_poser_route` trace un **chemin de sol** (le sol de la palette de village du biome, arbres et rochers dégagés, sans toucher au relief) de la place du village — ou du centre — vers le milieu du bord de chaque voisine reliée. La carte du monde dessine les routes en traits ocre. Les routes entre royaumes attendent (les frontières de secteur aussi).

> [!success] Codé le 2026-08-29 — les routes entre royaumes
> Après les routes intérieures (village → capitale), les **routes commerciales** : dans chaque secteur, deux royaumes **voisins** (leurs territoires se touchent) dont la diplomatie **n'est pas hostile** relient leurs capitales par le même Dijkstra à coût (danger et altitude), mais **à travers les deux territoires** au lieu d'un seul. Décisions : pas de route vers un voisin **hostile** (une route est un lien de confiance, et ça donne une lecture immédiate de la carte — les royaumes en froid sont isolés) ; pas de route qui traverse un **troisième** royaume (le chemin ne sort pas des deux territoires concernés, sinon il faudrait un droit de passage, qui n'existe pas) ; les routes maritimes attendent toujours les véhicules. Le voyage rapide ×0,6 s'applique à ces routes comme aux autres, et le trait ocre de la carte les montre.

> [!success] Mesuré et optimisé le 2026-08-29 — la génération d'une cellule passe de 390 à 157 ms
> Le budget de la note (2 ms par chunk, 32 ms par cellule) n'était pas tenu : **390 ms** mesurés en régime permanent (hors amorçage des bruits, qui coûte une seconde à la première cellule). Trois causes trouvées et corrigées, sans changer un seul résultat de génération (les tests de déterminisme le vérifient) : une **table `par_tuile` de 16 384 entrées** qui ne servait qu'à retrouver la clé de bloc — recalculée à la volée (−53 %) ; le **matériau de sol** relu par `biomes.get(...).get(...)` à chaque tuile — mis en cache dans le bloc ; les **constantes de la mer** (`planete.mer.altitude`, `.hauteur`) relues 16 384 fois — hoistées. Reste **157 ms**, dominés par les trois dictionnaires de 16 k entrées (`sol`, `sols`, `eau`) : descendre à 32 ms demanderait de passer à des `PackedByteArray`, ce qui touche `Grille`, `Monde` et le générateur de donjon — une refonte, pas un réglage. Le seuil du test passe de 600 à **250 ms** pour verrouiller le gain.

## Liens
- **Dépend de** : [[Génération par couches de bruit]], [[Catalogue des couches de bruit]], [[Grille continue]]
- **Alimente** : [[Décision — Monde fini, continents et océan]], [[Carte du monde]], [[Biomes — schéma]], [[Génération de donjon]], [[Génération des royaumes PNJ]], [[Eau et liquides]]
- **Voir aussi** : [[Décision — Altitude sur 21 niveaux]], [[Terrain spectaculaire]], [[Récolte]], [[Génération procédurale — performance]], [[Direction artistique]]
