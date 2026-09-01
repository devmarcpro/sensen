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

## Liens
- **Dépend de** : [[Niveau de danger]], [[Catalogue des couches de bruit]], [[Sauvegarde]]
- **Alimente** : [[Raids et menaces]], [[Loot — affixes, gemmes et rareté]], [[Villages PNJ — repeuplement et décimation]], [[Génération de donjon]], [[Créatures]]
- **Voir aussi** : [[Claims et persistance]], [[Économie — sources et puits]], [[Simulation du monde — performance]], [[Cycle jour-nuit et sommeil]]
