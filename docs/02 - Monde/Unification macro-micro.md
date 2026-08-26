---
aliases: ["E.2", "Annexe E.2", "Unification macro/micro", "Génération du monde"]
tags: [monde, génération, technique, décidé]
domaine: monde
statut: décidé
etape: 8
---

Il n'existe qu'une seule génération : la carte du monde et la cellule sont deux fenêtres sur le même champ de bruit continu. Résout la question ouverte de [[Génération par couches de bruit]] (cohérence carte ↔ cellules ↔ transitions).

```
Il n'existe qu'UNE génération : les couches de bruit sont des fonctions
continues f(x, z) sur les coordonnées MONDE (en blocs).
- Le biome en un point = résolution des conditions (B.6) sur les valeurs
  de bruit À CE POINT. Les transitions entre biomes sont donc naturellement
  continues (aucun raccord à gérer entre cellules : la cellule n'est qu'une
  fenêtre administrative de 128×128 sur ce champ continu).
- La "case" de la carte du monde affiche le biome échantillonné AU CENTRE
  de la cellule + icônes des POI qu'elle contient. La carte est un
  résumé, jamais une source de vérité.
- Terrain 3D SPECTACULAIRE — l'altitude n'est pas un simple bruit
  lissé ("plat avec un peu de relief" est explicitement un anti-but) :
    altitude(x,z) = continentalité (bruit très basse fréquence :
      grandes masses émergées / mers)
      + relief modulé par une couche d'ÉROSION/PIC :
        * ridged noise (crêtes) → CHAÎNES DE MONTAGNES massives,
          arêtes vives, pics à 200-400 blocs au-dessus des plaines
        * domain warping (le bruit déforme ses propres coordonnées)
          → côtes découpées, vallées sinueuses, formes organiques
        * terrasses conditionnelles (quantification locale de
          l'altitude là où la couche sismique est forte) → FALAISES
          verticales de 30-80 blocs, mesas, canyons
      + bassins : les minima locaux larges sous le niveau d'eau
        régional → GRANDS LACS (remplis à la génération, sources
        E.22) ; les fleuves suivent le gradient entre lacs et mer.
    Formations rares (hash déterministe, façon POI) : arches
    naturelles, pitons isolés, cratères, gorges — assemblées par
    modificateurs de terrain paramétriques, pas de prefabs.
  Un bruit 3D de cavernes (densité) creuse en dessous ; les strates
  de matériaux suivent la profondeur + le biome de surface + les
  couches dédiées (ressources) pour les filons.
- STRATIFICATION PAR DURETÉ (verrou de progression naturel) : plus on
  descend, plus la roche est dure — voir la table des strates en G.9/
  section 3.2. Combiné à la règle d'irrécoltabilité (A.2 : outil trop
  faible = rebond), creuser profond exige de meilleurs outils, de
  meilleurs matériaux (trouvés... en profondeur : boucle de progression)
  ou des PNJ mineurs de haut niveau. Les filons riches et les meilleurs
  minerais sont placés dans les strates profondes.
- POI : placement déterministe par hash(seed, cell_x, cell_z) → chaque
  cellule a 0-2 POI tirés selon poi_weights du biome (B.6). Densités par
  défaut : village 4 %, donjon 6 %, camp 8 %, sanctuaire 3 %, filon
  majeur 6 % par cellule. Les donjons sont assemblés procéduralement à
  partir de salles préfabriquées .vox (mêmes palettes remapables que 9.2).
- Villes : un village démarre par un centre + N bâtiments préfab posés le
  long de routes générées (bruit + A* sur la carte des pentes), palette
  par biome (9.2).
```

*Détail du terrain : [[Terrain spectaculaire]]. Détail des strates : [[Stratification verticale]] et [[Minerais par profondeur]]. Règle d'irrécoltabilité : [[Récolte]].*

## Liens
- **Dépend de** : [[Génération par couches de bruit]], [[Catalogue des couches de bruit]], [[Grille continue]]
- **Alimente** : [[Carte du monde]], [[Biomes — schéma]], [[Génération de donjon]], [[Génération des royaumes PNJ]], [[Eau et liquides]]
- **Voir aussi** : [[Terrain spectaculaire]], [[Stratification verticale]], [[Récolte]], [[Génération procédurale — performance]], [[Direction artistique]]
