---
aliases: ["Gaz dans le sol", "Poches de gaz", "Grisou"]
tags: [monde, mine, danger, décidé]
domaine: monde
statut: décidé
etape: 9
---

> [!important] Décidé le 2026-09-07, 18 h 10 — les gaz dans le sol (designer : « rajouter les gaz dans le sol »)
> La demande tient en cinq mots ; je la lis avec [[Mine sous une cellule]] et [[Minerais par profondeur]], dans l'esprit de Dwarf Fortress où l'on creuse et où le sol répond : **des poches de gaz scellées dans le plein**, invisibles tant qu'on ne les ouvre pas, qui s'échappent quand la pioche les perce, se répandent dans les galeries, font ce que leur nature commande, et se dissipent.
> - **Une poche est une tuile pleine** (roche, mur, minerai) qui porte un gaz, semée par un bruit dédié à l'étage, comme les veines (`gaz.json → poches` : fréquence, seuil, étage minimal, la part de chaque gaz par bande de profondeur). Le tirage est déterministe : la même galerie retrouve ses poches, et une poche ouverte ne se referme pas — dans une mine, la tuile creusée est notée (`mines_creusees`), et la poche ne se ressème pas dessus.
> - **Percer la poche libère le gaz** : à l'ouverture (`SimTerrain._creuser`), le gaz remplit par inondation `volume` tuiles d'air à partir de la brèche — les galeries ouvertes, pas la roche — sous forme de **zones** au sol (le système des Modules : `sim.zones`, un liseré à leur teinte, `fin` pour la dissipation). Le journal le dit : « un souffle de gaz s'échappe ».
> - **Trois gaz**, en données, et chacun fait une chose :
>   - le **grisou** (méthane) est inerte tant que rien ne l'allume — mais **une flamme dans le nuage l'enflamme** : une torche en main (`lumiere_de`), un feu au sol (`sim.feux`), de la lave voisine. Il **explose** alors avec la formule des [[Explosions]] (`puissance`, `rayon`, `degats`), et tout le nuage part d'un coup. Le mineur prudent éteint sa torche ; le mineur pressé apprend.
>   - le **gaz toxique** (sulfure) : qui s'y tient prend `degats` par pas d'automate et le statut `poison`.
>   - le **gaz asphyxiant** (CO₂) : pas de dégâts, mais `epuisement` à chaque pas d'automate — on s'y traîne, on s'en sort ou on y reste.
> - **Il se dissipe** : chaque zone de gaz expire après `duree_ticks` ; tant qu'il dure, le pas d'automate (`_tiquer_gaz`, la cadence de la lave) applique l'effet à l'occupant et cherche l'allumage.
> - **Où** : dans la **mine** (l'ouvrage du joueur, [[Mine sous une cellule]]) et dans les **étages profonds du gouffre** (`etage_min`), les deux plein de roche à percer. Pas en surface.
> **Ce que je ne fais pas**, et pourquoi : pas de canari ni de détecteur (rien ne prévient — c'est la règle du risque, et un objet de détection est un contenu à part) ; pas de gaz qui monte d'étage en étage (un étage est une grille) ; pas de gaz plus lourd que l'air qui coule dans les creux (les hauteurs d'un étage de mine sont plates). **À juger**, les nombres : la densité des poches, le volume libéré, la durée, et surtout la puissance du grisou — un mineur qui meurt à son premier coup de pioche n'apprend rien.
