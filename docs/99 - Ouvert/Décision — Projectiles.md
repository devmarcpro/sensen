---
aliases: ["Décision — Projectiles", "Ouvert — Projectiles", "Projectiles", "Friendly fire"]
tags: [combat, décidé]
domaine: combat
statut: décidé
etape: 0
---

> [!success] Décidé le 2026-08-26
> Tranché sur délégation du designer (« tout doit être rédigé et décidé avant production »). Le code s'appuie dessus ; révisable au playtest comme toute décision.

**La décision : trajectoire réelle, tir refusé si un allié masque, friendly fire des zones uniquement.**

**Trajectoire** — un tir d'arme à distance trace une **ligne de Bresenham** tireur→cible sur la grille :
- bloquée par le premier **relief plus haut que la ligne** ([[Hauteur de terrain ±10]]) et par tout **contenu bloquant** (mur, invocation) ;
- une **entité** sur la trajectoire masque la cible : le tir sur une cible masquée par un **allié est REFUSÉ** (l'UI grise la cible et montre la tuile bloquante) — **pas de friendly fire d'arme**, en solo comme en coop.

**Friendly fire — une seule règle :** les **formes de zone des modules** (ligne, cône, croix, carré, anneau — [[Vocabulaire des modules — six axes]]) touchent **tout ce qui est dans la forme, alliés compris**, en solo comme en coop. Le placement compte — c'est le prix des sorts de zone, et la prévisualisation de forme ([[Combat tactique sur grille]]) rend le risque toujours lisible avant validation.

**Portée minimale** — arc et arbalète : **min 2** ([[Stats d'armes]]) ; à portée 1 le tir est **impossible** — dégainer une lame coûte 4 ticks ([[Boucle de tick]]), c'est exactement l'arbitrage voulu.

**Munitions** ([[Équipement — 14 slots]] : carquois, munitions compositionnelles pointe + hampe) : consommées au tir ; **50 % récupérables au sol** à la fin du combat (arrondi bas).

**Météo ([[Météo]]) :** en tempête, **portée effective des projectiles ÷ 2** — règle simple, lisible sur la prévisualisation de portée.

> [!success] Complété le 2026-08-26 — dans le prototype
> - **Un ennemi sur la trajectoire prend la flèche** (la note ne tranchait que le cas de l'allié) : la trajectoire est réelle dans les deux sens. L'UI grise la cible masquée par un allié et peint la tuile bloquante en rouge.
> - **Munitions** : le carquois est un objet équipé (`items/proto_fleches.json`, `quantite`) ; l'être porte `munitions` et `munitions_tirees` ; la récupération de 50 % (arrondi bas) se fait à la sortie du combat, quand l'horloge de combat se dissout. La météo n'existe pas encore dans le prototype.

> [!success] Corrigé le 2026-08-31 — la lance n'est pas un projectile
> La sonde de parcours (profil 6 objets, graine 73) a tiré une lance au sort et n'a **jamais porté un coup** : le code prenait `portee_min > 1` pour « arme à distance » et exigeait des **munitions** (et une trajectoire à la Bresenham) pour la lance — une arme d'hast n'a pas de carquois. Le champ de données **`projectile`** (booléen, `functionalities/`) porte désormais la règle : munitions, trajectoire, allié qui masque et récupération de 50 % ne concernent que les fonctionnalités `projectile: true` (l'arc seul aujourd'hui, l'arbalète demain). La **zone morte au contact** (`portee_min` 2) reste commune à l'arc **et** à la lance — c'est l'arbitrage voulu de la note. Le robot de parcours apprend au passage à respecter la portée de son arme (reculer d'un pas dans la zone morte) et à ne plus « se reposer » d'une blessure : la santé ne revient jamais toute seule.

> [!note] Réglages — `combat_rules.projectiles.recuperation` : la part des munitions retrouvées en fin de combat. Pointeur ajouté le 2026-09-04.

## Liens
- **Dépend de** : [[Hauteur de terrain ±10]], [[Stats d'armes]], [[Vocabulaire des modules — six axes]], [[Trous connus du combat]]
- **Alimente** : [[Combat tactique sur grille]], [[Multijoueur]], [[Équipement — 14 slots]]
- **Voir aussi** : [[Boucle de tick]], [[Météo]], [[Eau et liquides]], [[Écrans d'interface]]

> [!bug] Constaté le 2026-09-04 — trois kits de tir partaient **sans carquois**, donc sans un seul tir possible
> Le robot, en jouant Le Creuset après la relecture des armes : un combat, **zéro coup porté**. Une arme à projectile refuse de tirer à `munitions <= 0`, et le compteur se lit dans le carquois équipé — que le kit ne donnait pas. Le Creuset (sarbacane), L'Engrenage et La Trace (arc) commençaient la partie avec une arme qu'ils ne pouvaient pas utiliser ; la matrice du 3 septembre les avait notés « ne tue rien » sans voir pourquoi. Et il n'existait **aucune munition pour la sarbacane**.
> **Corrigé** : des **fléchettes** (`items/munition/craft_flechettes.json`, 25 par carquois, pointe seule, à l'établi) ; les trois kits reçoivent leur carquois (flèches pour les arcs, fléchettes pour la sarbacane) ; et `verif_classes` refuse désormais toute classe dont l'arme de départ est un projectile sans carquois dans le kit — c'est le genre d'erreur qu'on ne revoit qu'en jouant, la sonde la voit à chaque passage.
