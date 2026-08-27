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

## Liens
- **Dépend de** : [[Data-driven design]]
- **Alimente** : [[Unification macro-micro]], [[Biomes — schéma]], [[Niveau de danger]], [[Terrain spectaculaire]], [[Météo]], [[Wu Xing hors combat]]
- **Voir aussi** : [[Décision — Monde fini, continents et océan]], [[Catalogue des couches de bruit]], [[Grille continue]], [[Génération procédurale — performance]]
