---
aliases: ["3.0", "3.0 Génération procédurale", "Couches de bruit"]
tags: [monde, génération, décidé]
domaine: monde
statut: décidé
etape: 8
---

Le principe fondateur de la génération : des couches de bruit superposées qui définissent à la fois les biomes et le contenu matériel du monde.

Le monde est généré par superposition de multiples couches de bruit (type Perlin/Simplex), qui se combinent pour définir à la fois les biomes et le contenu matériel du monde.

**Couches de bruit :**
- Altitude — sa composante **continentalité** vient de la tectonique ([[Décision — Monde fini, continents et océan]]), pas d'un bruit libre
- Température
- Humidité
- Densité de mana/magie
- Densité de ressources/minerais
- Densité de végétation
- Activité sismique/volcanique — **dérivée**, non tirée : elle découle des frontières de plaque ([[Décision — Monde fini, continents et océan]])
- Niveau de danger/corruption

*(Paramètres chiffrés de chaque couche : [[Catalogue des couches de bruit]].)*

**Application à deux échelles :**
- **Carte du monde** : la combinaison des couches détermine le biome global de chaque case (ex : désert volcanique à forte magie, toundra pauvre en mana).
- **Intérieur d'une cellule (génération de la grille)** : les mêmes familles de couches (affinées/dérivées) génèrent la **hauteur de chaque tuile** ([[Hauteur de terrain ±10]]), le matériau de sol, les filons de surface et le contenu, en cohérence avec le biome déterminé à l'échelle macro.

**Placement des matériaux : approche mixte**
- Certains matériaux/minerais ont leur propre couche de bruit dédiée (poches rares/riches indépendantes du biome).
- D'autres matériaux découlent directement du biome déterminé par les couches principales (ex : sable en désert, glace en toundra).

**Décisions :**
- Cohérence macro/micro et transitions : **résolu ([[Unification macro-micro]])** — une seule génération continue, la cellule et la carte ne sont que des fenêtres/résumés sur le même champ de bruit.
- **Visibilité des couches :** la carte du monde affiche le biome et la heat-map de danger ([[Début de partie]]) ; les autres couches (mana, ressources...) sont **cachées par défaut** et se révèlent par le jeu — effets `detection_filons`/`detection_tresors` ([[Effets d'équipement types]]), informations vendues par la guilde des Prospecteurs ([[Minerais par profondeur]]), rumeurs de PNJ ([[Dialogue PNJ]]).

> [!success] Décidé le 2026-08-27 — terrain plat, reliefs en exception
> Tranché par le designer : pas de bruit de relief permanent. Le sol est **plat à la référence** (hauteur 10) et le relief est une **exception posée** — talus, gorge, colline, estrade, éboulis — comme les trois arènes du prototype le font à la main. À l'étape 8, la couche de hauteur produit donc des accidents localisés sur une plaine, pas une ondulation continue ; les couches de bruit servent aux biomes et aux matériaux, pas à faire onduler le sol.

> [!success] Codé le 2026-08-28 — étape 8.1 : une cellule de surface générée (`systems/worldgen/surface.gd`)
> Les 8 couches de [[Catalogue des couches de bruit]] en `data/noise_layers.json`, `FastNoiseLite` natif (simplex lisse / Perlin fBm), une seed monde + `seed_offset`, échantillonnées une fois par tuile et normalisées 0..1. **La décision du 2026-08-27 prime** : le sol est plat à 10, le relief est une **exception posée** — `planete.relief` tire par cellule 2 à 5 **accidents** paramétriques (talus +2, estrade +1, piton +8, cratère −4, gorge −6 en saignée sinueuse), hors de la zone d'arrivée du camp. Les couches servent aux **biomes** (conditions + priorité) et aux **matériaux** (sol, arbres × couche `vegetation`, rochers, filons × couche `ressources`, tiers par la couche `danger` aux seuils 0/20/45/70/90 de [[Décision — Minerais et strates après le pivot]]). La cellule est adressée (cx, cy) dans le monde de `data/planete.json` ; sans carte encore, le camp est la cellule de départ `cellule_depart` (le centre du monde). La tectonique, l'eau, le streaming et les autres biomes viennent en 8.2-8.3.

> [!success] Codé le 2026-09-02 — des côtes découpées, et deux biomes de fantaisie en moins (designer)
> « Il va falloir changer le bruit des côtes pour avoir quelque chose de plus réaliste et moins plat, retire les biomes fantaisistes. »
> **Les côtes.** La continentalité n'avait que des termes à très basse fréquence — la plaque et un bruit de 0,00012 — d'où des rivages lisses, en galets. Les vraies côtes doivent leur découpe à des accidents **bien plus fins** que le continent qui les porte : caps, baies, presqu'îles, chapelets d'îles. On ajoute donc un relief de rivage **crêté** à haute fréquence, dont l'effet est **concentré près du niveau de la mer** : plein sur le trait de côte, nul dès qu'on entre dans les terres ou au large. Le continent garde sa forme d'ensemble, seul son bord est ciselé — un bruit ajouté partout aurait troué les continents et semé des îles dans tout l'océan.
> **Le premier réglage était mauvais** : à fréquence 0,0022 et amplitude 0,55, la côte devenait une soupe de pixels — découpée, mais pas plus réaliste. À 0,0007 et 0,38, on obtient des baies et des caps à l'échelle de plusieurs cellules, avec quelques îlots au large.
> **Les biomes.** Forêt de mana et Montagne cristalline sont retirées, traductions comprises. **Deux cas limites gardés, et c'est un choix à confirmer** : le Désert de cendres est volcanique et sismique, donc géologiquement plausible ; le Marécage corrompu est l'expression visible du système de corruption, et son tag `corrompu` décide du thème des donjons qui y naissent.
> Le test qui comptait « 12 biomes » vérifie désormais la **règle** — au moins huit, chacun avec ses conditions et sa priorité — et non plus un nombre que le designer fait varier.

## Liens
- **Dépend de** : [[Data-driven design]]
- **Alimente** : [[Unification macro-micro]], [[Biomes — schéma]], [[Niveau de danger]], [[Terrain spectaculaire]], [[Météo]], [[Wu Xing hors combat]]
- **Voir aussi** : [[Décision — Monde fini, continents et océan]], [[Catalogue des couches de bruit]], [[Grille continue]], [[Génération procédurale — performance]]
