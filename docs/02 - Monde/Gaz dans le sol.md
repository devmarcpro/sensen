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

> [!important] Décidé le 2026-09-07, 18 h 35 — « uniquement des gaz qui existent dans le monde réel, comme le reste des matériaux » (designer)
> La liste de 18 h 30 mêlait le réel et l'inventé (brume de mana, vapeurs curatives, gaz hilarant, fumée noire). La règle du designer est celle des matériaux : **le catalogue est le monde réel**. Neuf gaz, tous attestés dans les mines, les grottes ou les sols volcaniques, chacun avec son effet réel — le vocabulaire d'un gaz reste celui de 18 h 30 (`degats` + `element`, `statut`, `eteint_feux`, `inflammable` + `explosion` ; `soigne` et `mana` restent dans le vocabulaire mais aucun gaz réel ne les porte) :
> - **azote** (N₂, le « mauvais air » des galeries fermées) — épuisement, et il **étouffe les feux** ; partout, surtout en haut.
> - **dioxyde de carbone** (CO₂, la « mofette » des caves et des volcans) — épuisement, étouffe les feux ; en haut et au milieu.
> - **méthane** (CH₄, le **grisou** des houillères) — inerte jusqu'à la flamme, puis **explose** (25 / rayon 2 / 4d6) ; partout, de plus en plus bas.
> - **monoxyde de carbone** (CO, des feux de couche) — un dégât léger, affaibli, et il brûle faiblement ; au milieu et au fond.
> - **sulfure d'hydrogène** (H₂S, le gaz des eaux soufrées) — 1d4 et poison, et il brûle ; au milieu et au fond.
> - **dioxyde de soufre** (SO₂, volcanique) — 1d2 et **armure fendue** (avec l'humidité, il fait de l'acide) ; au milieu et au fond.
> - **vapeur d'eau** (les fumerolles près de la lave) — 1d6 de feu et brûlure ; au milieu et au fond.
> - **radon** (Rn, des roches granitiques) — rien sur le moment, **affaibli** longtemps : on ne le sent pas, on le paie ; en haut et au fond.
> - **hydrogène** (H₂, des roches profondes et des serpentinites) — **explose** plus fort que le méthane (30 / rayon 2 / 5d6), c'est tout ; au fond, rare.
> Les nombres sont à juger ; la règle tient : ce qu'on trouve en bas fait plus de mal.

> [!important] Décidé le 2026-09-07, 18 h 40 — « rajoutes-en encore, rajoute d'autres choses du monde réel si t'as de bonnes idées » (designer)
> **Six gaz réels de plus, quinze en tout** : l'**ammoniac** (NH₃, des dépôts de guano des grottes — 1d2 et **aveugle** : il brûle les yeux), l'**éthane** (C₂H₆, le second gaz des gisements, **explose** 20 / rayon 2 / 3d6), l'**hélium** (He, des gisements de gaz — inerte, il ne fait qu'ôter l'air : épuisement ; en haut, rare), l'**argon** (Ar, du même genre, au fond), la **vapeur de mercure** (Hg, des mines de cinabre — rien sur le moment, **poison** long : 100 ticks), l'**arsine** (AsH₃, des filons arsénifères — 1d6 et poison : le plus meurtrier des quinze ; au fond, rare).
> **Et trois autres poches du sous-sol**, parce que le monde réel ne scelle pas que du gaz dans la roche — le même bruit, la même règle « la pioche ouvre, le sol répond », dans `sous_sol.json` :
> - **la nappe d'eau** : percée, la brèche devient une **source** et l'automate d'eau ([[Eau et liquides]]) fait le reste — l'eau descend la galerie, remplit les creux, et une mine mal creusée s'inonde. Dès le deuxième étage d'une mine.
> - **la géode** : une cavité tapissée de cristaux — percée, elle rend **une à trois gemmes brutes** au sol (`quantite`), tirées dans la bande de profondeur (quartz, agate et onyx en haut ; améthyste, grenat, jade, opale, aigue-marine au milieu ; émeraude, rubis, diamant au fond). La récompense du mineur, à côté des veines.
> - **la poche de magma** : au fond seulement — percée, la brèche est de la **lave** (la règle de la lave existe : elle brûle, enflamme, se fige à l'eau). Le vrai danger des grandes profondeurs.
> Une tuile ne porte qu'une poche : le gaz d'abord, puis le reste. Tout cela se sème à la charge de l'étage, se vide avec la grille, et le test le joue (`test_gaz_dans_le_sol`). **À juger** : les densités — une mine où chaque coup de pioche ouvre quelque chose n'est plus une mine.


> [!decision] Conçu le 2026-09-08 — **la forme du champ d'air**, avant la première ligne de code (ligne 24 ter de l'[[Ordre de travail]])
> **Ce qu'il remplace, entièrement** : la liste `sim.zones` de type `gaz`. Aujourd'hui `_liberer_gaz` inonde N tuiles **une fois**, pose N entrées avec une date de fin, et `_tiquer_zones` ne fait qu'enlever celles qui ont expiré. Un nuage ne diffuse jamais, ne monte jamais, ne coule jamais, ne se dilue jamais. Le champ le rend **mobile**, et la date de fin disparaît : un nuage s'éteint parce qu'il s'est dilué, pas parce qu'un compteur est arrivé au bout.
> **La forme, sur le patron de la chaleur et du danger** — deux tableaux plats de la taille de la grille, jamais un dictionnaire :
> - `gaz_a : PackedByteArray` — l'**indice** du gaz dominant d'une tuile (0 = de l'air, sinon l'index dans le catalogue trié) ;
> - `gaz_c : PackedByteArray` — sa **charge**, 0 à 255, où 255 est une tuile pleine.
> **Un seul gaz par tuile, le dominant.** C'est le choix qui rend le champ tenable : quinze charges par tuile seraient quinze tableaux, et aucune règle de jeu ne lit un mélange. Deux nuages qui se rencontrent : le plus chargé garde la tuile, l'autre y perd la différence — le mélange est un **arbitrage**, pas une moyenne.
> **Le tick, toutes les `periode_ticks`** (comme la chaleur), et seulement sur les tuiles chargées (une file, jamais un balayage) :
> 1. **Diffusion** vers les voisins franchissables, proportionnelle à l'écart de charge ;
> 2. **Poussée verticale** par la `masse_relative` déjà en donnée : au-dessus de 1 la charge descend d'un niveau Z quand il y en a un (la mofette au fond du puits), en dessous elle monte (le grisou au toit de la galerie) ;
> 3. **Dilution** : une tuile à ciel ouvert perd une part fixe par tick, une tuile close n'en perd aucune — c'est ce qui fait qu'un gaz **s'accumule** dans une galerie et se dissipe dehors, sans qu'aucune date de fin ne soit écrite nulle part.
> **Ce qui le lit** : le champ de **danger** (aujourd'hui `_danger_du_gaz` parcourt les zones — il lira le tableau), l'**ignition** du champ de chaleur (un gaz inflammable au-dessus d'un seuil et une flamme : l'explosion), la **vue** (la fumée aveugle) et demain le champ sonore.
> **Ce qui reste à trancher, et que je ne tranche pas seul** : l'**air** lui-même. Ce champ transporte des gaz étrangers ; il ne dit pas encore combien il reste d'oxygène. La suffocation restera donc une étiquette tant qu'un `air_c` (la respirabilité d'une tuile) n'existe pas — c'est la deuxième moitié, et elle demande de décider si un être **consomme** l'air qu'il respire.

> [!success] Codé le 2026-09-12 — **le champ d'air** : un nuage se déplace enfin, et la suffocation cesse d'être une étiquette (ordre de travail 24 ter, sur la question du designer du 2026-09-08 : « tu rajoutes le gaz dans le sol mais est-ce que tu fais pareil pour l'air ? »)
> **Ce qui n'allait pas, et cette note le disait déjà en toutes lettres.** Sous terre le gaz était une vraie chose ; **une fois sorti, il n'existait plus**. `_liberer_gaz` faisait UNE inondation et déposait quatorze tuiles dans `sim.zones` ; `_tiquer_zones` ne faisait qu'enlever celles qui avaient expiré. Un nuage ne diffusait jamais, ne montait jamais, ne se diluait jamais — et les quinze gaz se comportaient donc à l'identique : ils restaient où ils étaient nés.
> **Un nuage est désormais une CHARGE PAR TUILE** (`sim.nuages` : idx → {gaz → 0..1}), creuse comme les poches, et le pas suit le patron de la chaleur : on ne balaie jamais la fenêtre, on visite les tuiles chargées et leur bordure, dans un ordre de clés fixe. La brèche percée ne reçoit plus qu'**une** charge — le nuage prend la forme de la galerie au lieu d'un disque, met du temps à venir jusqu'à toi, et repart par où il est venu.
> **LA MASSE FAIT MONTER OU COULER, ET C'EST UNE SEULE FORMULE.** Le poids d'une voisine vaut `1 + pente_masse × (hauteur_voisine − hauteur_ici) × (1 − masse)` — et la grille portait déjà une hauteur par tuile. Léger : le facteur est positif, les voisines plus hautes pèsent plus, le nuage **remonte la pente** ; lourd : il **descend et s'accumule au fond** ; à 1,00, l'air lui-même, le biais s'annule exactement et la diffusion redevient isotrope. Une formule, les quinze comportements, **zéro table**. Mesuré par `test_champ_air` : l'hydrogène (0,07) met 0,128 en haut et **0,000** en bas, le radon (7,67) met 0,340 en bas et **0,000** en haut, l'azote (0,97) penche de 0,004 — trente fois moins.
> **Et la dilution sépare la fuite spectaculaire de la fuite mortelle** : à ciel ouvert un nuage se dissipe (et un gaz léger s'échappe **en plus** vers le haut : rien ne retient l'hydrogène, rien ne fait sortir le radon par là) ; **sous terre il n'y a pas de haut**, rien ne fuit, et il s'accumule. 0,992 restant en espace clos contre 0,894 à ciel ouvert au premier pas.
> **Les effets ne se déclenchent plus par présence mais par CONCENTRATION** (`seuil_effet`) : un nuage a enfin une **bordure** qu'on voit sans la subir, donc une fuite se repère avant de tuer. Et une trace de grisou ne saute pas — il faut `seuil_explosion`, ce qui rend la lampe dangereuse **au fond** d'une galerie et pas à son entrée. Le danger lu par l'IA se **gradue** de la même façon : elle peut traverser une frange en refusant un cœur.
> **Le champ se VOIT bouger**, et c'est le premier de ce jeu : l'opacité du losange suit la charge, la teinte est celle du gaz le plus concentré de la tuile (un mélange se lit par ce qui domine, pas par une moyenne qui ne serait la couleur de rien).
>
> **LA QUESTION QUE CETTE NOTE LAISSAIT OUVERTE — « est-ce qu'un être CONSOMME l'air qu'il respire ? » — est tranchée, et par la négative.** Il n'en a pas besoin : **l'air est le COMPLÉMENT du gaz**, `air = 1 − charge`. Rien ne le stocke, rien ne le diffuse, rien ne peut le désynchroniser de ce qui l'a chassé — *ce qui peut se déduire ne se balaie pas*. Un espace clos devient irrespirable **parce que le gaz y est**, et ça vaut pour les quinze sans qu'une seule fiche ait à le déclarer : un gaz inerte devient mortel en quantité.
> **Et la suffocation n'est pas une mécanique neuve** — c'est une deuxième raison de perdre le **souffle qui existait déjà** pour la noyade. Le compilateur me l'a appris en refusant mon `_tiquer_souffle` : le nom était pris. Une tuile viciée ne remplit plus le souffle, une tuile saturée le vide, et tout le reste est hérité sans une ligne (le maximum tiré de l'endurance, l'exemption des volants, `respiration_aquatique`, les dégâts périodiques à zéro). *Une seule jauge, deux façons de mourir* — et le journal dit laquelle : on se **noie** dans l'eau, on **étouffe** dans un nuage.
> **Ce que ce choix laisse dehors, et il faut le dire** : une pièce hermétique **sans gaz** n'étouffe personne. Si tu veux qu'un caveau scellé finisse par tuer, il faut la consommation — c'est un second mécanisme, et il demande un budget d'air par tuile que rien ne déduirait. Consigné dans [[Décisions en attente]].

## Liens
- **Dépend de** : [[Mine sous une cellule]], [[Minerais par profondeur]], [[Explosions]]
- **Alimente** : [[Génération de donjon]], [[Niveau de danger]], [[Trésors et artefacts]]
- **Voir aussi** : [[Eau et liquides]], [[Destruction du terrain]], [[Éclairage]]
