---
aliases: ["E.20", "Annexe E.20", "Dérive de la corruption", "Corruption dérive"]
tags: [monde, simulation, décidé]
domaine: monde
statut: décidé
etape: 8
---

La couche de danger n'est pas figée : elle dérive selon les actes du joueur. C'est ce qui fait que la région autour de la base se pacifie et que le défi s'éloigne.

**Principe ([[Carte du monde]]) :** la couche de danger **dérive lentement selon les actes** (mise à jour hebdomadaire in-game) : les foyers hostiles non nettoyés (donjons, camps) **infectent** progressivement leurs cases voisines ; **nettoyer** un foyer fait durablement baisser le danger local. Conséquence de design voulue : la région autour de la base du joueur se pacifie naturellement (il nettoie ce qui est proche), le défi et le meilleur loot s'éloignent — l'exploration est encouragée par la structure du monde, pas par une règle artificielle. La richesse suit toujours le danger (loot ∝ corruption locale), jamais l'inverse.

**Spécification :**

```
La couche danger/corruption = bruit de base (3.0) + DELTA persistant par
cellule (sauvegardé, E.10), borné [-40, +40] autour de la base.
Mise à jour HEBDOMADAIRE in-game (même horloge que la régénération 3.3) :

INFECTION — chaque foyer hostile ACTIF (donjon non nettoyé, camp, repaire)
  ajoute +2 de delta à sa cellule et +1 aux 8 voisines, par semaine,
  jusqu'à son plafond d'influence (foyer mineur +10, majeur +25).
NETTOYAGE — vider un foyer (boss/chef tué, occupants éliminés) :
  - le foyer devient INACTIF (plus d'infection) pendant sa période de
    répit : 4 semaines (mineur) à 12 semaines (majeur), puis il peut
    se repeupler (jet hebdomadaire, proba ∝ corruption locale restante)
  - delta local : -8 immédiat sur la cellule, -3 sur les voisines
DÉCROISSANCE NATURELLE — sans foyer actif à proximité, le delta tend
  vers 0 à raison de -1/semaine (le monde revient à son état de bruit).
ZONES CIVILISÉES — les cellules claim du joueur et les villages PNJ
  exercent une pression -1/semaine sur leurs voisines (la civilisation
  repousse la corruption — les gardes patrouillent).

EFFETS de la corruption effective (bruit + delta) : niveau des créatures
  qui spawnent, densité des foyers, qualité/rareté du loot (richesse ∝
  danger), proba de raids (E.7), teinte visuelle du biome (feedback).
UI : la heat-map de la carte du monde (6.3) affiche la valeur effective —
  le joueur VOIT sa région se pacifier et les frontières sombres au loin.
Coût : un passage hebdomadaire sur les cellules à delta non nul ou à
  foyer — négligeable (pas de simulation continue).
```

**Effet nuit ([[Cycle jour-nuit et sommeil]]) :** niveau effectif +10 % de corruption locale la nuit.

**Effet sur le repeuplement des villages ([[Villages PNJ — repeuplement et décimation]]) :** un village dans une zone pacifiée par le joueur repeuple vite ; un village menacé stagne ou décline.

> [!success] Codé le 2026-08-28 — étape 8.3b, `Monde.semaine()` (`planete.corruption`)
> Les formules telles quelles : `corruption effective = danger (bruit, 0-100) + delta`, delta borné **[−40, +40]** par cellule et sauvegardé ; **passage hebdomadaire** (1 semaine = 7 × 24 000 ticks, sur l'horloge du monde) : chaque foyer **actif** (donjon non nettoyé) +2 à sa cellule et +1 aux 8 voisines jusqu'à son plafond (**mineur +10, majeur +25**) ; **nettoyage** (boss vaincu, constaté à la sortie) → foyer inactif, répit **4 semaines (mineur) / 12 (majeur)**, −8 immédiat sur la cellule, −3 sur les voisines ; puis jet hebdomadaire de **repeuplement, probabilité = corruption locale restante / 100**, réussi → un nouveau donjon dans la même cellule (nouvelle génération, donc nouvelle seed : `id = hash(seed, cellule, génération)`) ; **décroissance** −1/semaine vers 0 sans foyer actif à moins de 2 cellules ; **zones civilisées** (le camp) −1/semaine sur leurs voisines. **Décision (LOD)** : le passage ne court que sur les cellules **explorées et leurs voisines** — le reste du monde n'a que son bruit. La corruption pilote le niveau de danger de la carte et, en donjon, `corruption_étage = locale + étage × 8` (plafond 100) qui relève la profondeur de loot (`profondeur = étage + corruption/25`) et la densité de créatures (`× (1 + corruption/100)`). Un donjon est **majeur** quand sa cellule est « mortelle » (5 à 8 étages), **mineur** sinon (2 à 3).

> [!success] Décidé le 2026-09-01 — les donjons naissent de la corruption (designer, point 51)
> Les donjons ne sont plus des POI tirés à la génération : ils **poussent**. Un **bruit de corruption couvre le monde et se déplace chaque jour** — calculé **à la demande** pour une cellule et un jour donnés (`corruption_jour`), jamais en parcourant les 500 000 cellules : le monde entier « bouge » sans qu'aucune boucle ne tourne. Là où la concentration passe le **seuil**, la cellule **cristallise en donjon**.
>
> **Cinq types, un par élément** : le thème vient de l'élément dominant du lieu (Wu Xing hors combat) — bois, feu, terre, métal, eau. Un donjon **monte de niveau tant que personne ne le nettoie** : son niveau est le nombre de périodes écoulées depuis sa cristallisation, si bien qu'un donjon lointain, jamais visité, devient redoutable **sans qu'on ait eu à le décider**. Nettoyer une cellule remet son compteur à zéro et la rend au monde.
>
> **Trois garde-fous**, demandés par la prudence plus que par le designer, et consignés comme tels. **Les lieux habités sont épargnés** : ni un village, ni une cellule revendiquée, ni le camp de départ ne cristallisent — la corruption y monte, elle ne s'y fige pas. **Un plafond de densité** (`densite_max_pct` dans un rayon de `rayon_region` cellules) empêche qu'un continent neuf ne soit qu'un champ de donjons. Et **la fusion plafonne à quatre cellules** contiguës : deux donjons voisins font un grand donjon, pas une mer de donjons.
>
> Enfin, **entrer sur la cellule d'un donjon y fait entrer d'office**, et la surface reste fermée tant qu'il n'est pas vaincu — c'est ce qui donne son poids à la carte : une cellule corrompue n'est plus un lieu qu'on traverse.

> [!success] Décidé et codé le 2026-09-01 — la corruption croît avec l'éloignement (designer, point 62)
> Deux règles s'ajoutent, et elles répondent à un défaut réel de la première version : un donjon **nettoyé repartait de zéro**, si bien qu'un joueur avancé qui s'installait au bout du monde ne trouvait plus, après un nettoyage, que des donjons de niveau 3.
>
> **La corruption s'intensifie avec la distance au centre du monde** : `gradient_bord` points s'ajoutent en proportion de l'éloignement, jusqu'au bord de la carte. Le centre est le pays des débuts, les marges celui des fins de partie — sans qu'aucune zone ne soit écrite à la main.
>
> Et **le niveau des donjons n'est plus plafonné**. Il vaut désormais le **plus grand** de deux nombres : son **âge** (une période non nettoyée = un niveau) et son **plancher géographique** (`niveau_par_cellule_distance` × distance au centre). Nettoyer un donjon lointain le ramène donc à son plancher, jamais à 1 : la région reste dangereuse parce qu'elle est loin, et le joueur avancé y trouve un adversaire à sa taille. Seule la profondeur de recherche de l'âge reste bornée, pour que le calcul demeure instantané.

> [!success] Complété le 2026-09-01 — fusion et cellule fermée (designer, point 51)
> Les deux dernières pièces du système sont posées. **La fusion** : les cellules corrompues **contiguës forment un seul donjon**, plafonné à `fusion_max` (quatre) — un groupe de quatre est un gouffre, pas quatre donjons voisins. Chaque cellule du groupe mène à la **même tête**, le donjon gagne un étage et `niveau_par_fusion` niveaux par cellule fusionnée. Mesuré : des groupes de deux à quatre cellules, jamais davantage.
>
> **La cellule reste fermée tant que le donjon n'est pas vaincu.** Sortir en ayant tué le boss **nettoie** la cellule : elle retombe à son plancher géographique et rend le passage. Sortir sans l'avoir vaincu **repousse le joueur sur une cellule voisine saine** — il ressort à côté, pas dans la gueule du donjon, et la cellule corrompue reste infranchissable.

> [!success] Codé le 2026-09-01 — un donjon garanti près du camp (designer)
> « fais en sorte qu'il y ait un donjon pas trop loin du camp au début d'une nouvelle partie ». Depuis le retrait des entrées posées, le premier donjon dépendait du hasard du bruit : une partie pouvait commencer sans rien de corrompu à vingt cellules. Une **cellule d'amorce** est désormais choisie de façon déterministe à la création du monde — un tirage sur la graine parmi les cellules de terre situées entre `garantie_depart.rayon` cases du camp, en écartant villages et claims — et `donjon_corrompu` la tient pour corrompue tant qu'elle n'a pas été nettoyée. Une fois nettoyée, elle redevient une cellule comme les autres, soumise au seul bruit. Elle ne change ni son niveau ni son thème : ce sont les règles ordinaires (âge, plancher d'éloignement, fusion) qui s'appliquent.


> [!success] Tranché le 2026-09-02 — le foyer **est** le donjon de corruption, et un donjon vaincu **disparaît** (designer)
> « Je vois pas pourquoi le cycle de foyer n'est pas en place : un donjon apparaît sur une cellule quand le niveau de corruption y devient élevé, puis son niveau augmente au fil du temps, un donjon vaincu disparaît. »
> Le cycle n'était pas en place pour une raison bête : `foyer()` ne créait un foyer que sur une cellule portant un donjon **posé** par la génération de surface — et il n'y en a plus aucun depuis que les donjons naissent de la corruption. Toute la machinerie (infection hebdomadaire, plafonds, répit, repeuplement par générations) tournait donc dans le vide. Le foyer d'une cellule est désormais **le donjon de corruption lui-même** : il naît quand la corruption franchit le seuil, il infecte ses voisines chaque semaine, son niveau monte d'une période tant que personne ne descend.
> Et **vaincre le boss efface le donjon** : l'entrée disparaît de la carte, la cellule ne peut plus se cristalliser pendant le répit (`repit_mineur` / `repit_majeur` semaines), la corruption recule autour. Passé le répit, si la corruption est remontée au-dessus du seuil, un **nouveau** donjon naît là — au niveau 1, pas à celui qu'on avait vaincu. C'est le remplacement de l'ancien « retour au plancher », qui laissait sur la carte un donjon qu'on venait de vider.

> [!success] Codé le 2026-09-02 — **beaucoup, beaucoup trop de donjons** (designer)
> « Les carrés noirs avec des chiffres blancs sont des donjons ? Il y en a beaucoup trop, vraiment beaucoup beaucoup trop. » Mesuré avec la nouvelle sonde (`scenes/tests/sonde_monde.tscn`, graine 4242, carré de 81 cellules) : **319 donjons, 18,8 par région, une cellule de terre sur 8**. Un donjon était devenu le décor.
> La cause : la densité se réglait par un tirage à plat — `densite_max_pct` % des cellules **au-dessus du seuil**. Deux défauts. Un pourcentage ne dit rien de ce qu'on voit à l'écran ; et le gradient d'éloignement (point 62) met presque toute une marge au-dessus du seuil, si bien que ces 18 % s'appliquaient à peu près au monde entier.
> Maintenant que les régions existent ([[Carte du monde]]), la densité s'exprime dans l'unité qui se lit sur la carte : **N grappes par région et par période**. Chaque grappe est tirée de (région, période) et couvre un petit carré ; une cellule cristallise si elle tombe dans une grappe **et** passe le seuil, la fusion continuant d'opérer à l'intérieur d'une grappe. Le nombre de donjons par région ne dépend donc plus du hasard : il est borné par les données. À `grappes_par_region: 2`, la même mesure donne **22 donjons, 1,3 par région, une cellule de terre sur 78**. Le chiffre reste au designer — c'est un réglage, il est en données.
>
> **Un défaut trouvé en mesurant** : le donjon garanti du début de partie était de **niveau 121**. Il est cristallisé « depuis toujours » puisqu'il ne dépend pas du bruit, donc la recherche en arrière qui calcule son âge remontait jusqu'à `recherche_max` — le tout premier donjon d'une partie était le plus dur du jeu, et une trentaine d'étages. Il a désormais l'âge du monde : zéro, donc niveau 1.

> [!success] Tranché le 2026-09-02 — la **pente géographique** décide du niveau des donjons (designer, choix 2)
> Le designer a vu la conséquence de la baisse de densité avant moi : « il y a un problème si on n'a pas de donjons à proximité ». Mesure faite (`sonde_monde`) : depuis n'importe quelle cellule de terre, le donjon de corruption le plus proche est à **9 cellules** de médiane, le gouffre à **8** — jamais aucun introuvable. La densité n'était donc pas le problème. Le vrai manque était ailleurs : **pas de donjon à SON niveau**. Autour du camp, les niveaux allaient de 1 à 16, médiane 13 — et depuis que le butin suit le niveau du donjon, un débutant entouré de niveau 13 n'a plus rien qui lui corresponde.
> Sur trois façons de traiter ça — un plancher qui suit le joueur, une pente géographique, ou ne rien garantir — le designer a choisi la **pente**. Elle ne triche pas avec le monde et donne un sens à la carte : le centre est calme, les marges sont mortelles.
> **Deux essais.** Une pente **droite** donnait 13 · 31 · 53 · 69 · 87 par bande d'éloignement : la pente existait, mais le pied du camp était déjà à 13 — aucun berceau où apprendre. Une pente **courbe** (`niveau_courbe_distance`) tient la promesse : **4 · 11 · 30 · 51 · 79**, et autour du camp médiane 4, de 1 à 5.
> **Ce qui écrasait la géographie** : le bonus de fusion valait **3 niveaux par cellule fusionnée**, jusqu'à +9. Il vaut 1 — un donjon large est un peu plus fort, pas trois fois plus.

## Liens
- **Dépend de** : [[Niveau de danger]], [[Catalogue des couches de bruit]], [[Sauvegarde]]
- **Alimente** : [[Raids et menaces]], [[Loot — affixes, gemmes et rareté]], [[Villages PNJ — repeuplement et décimation]], [[Génération de donjon]], [[Créatures]]
- **Voir aussi** : [[Claims et persistance]], [[Économie — sources et puits]], [[Simulation du monde — performance]], [[Cycle jour-nuit et sommeil]]
