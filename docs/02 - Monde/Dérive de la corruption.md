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

## Liens
- **Dépend de** : [[Niveau de danger]], [[Catalogue des couches de bruit]], [[Sauvegarde]]
- **Alimente** : [[Raids et menaces]], [[Loot — affixes, gemmes et rareté]], [[Villages PNJ — repeuplement et décimation]], [[Génération de donjon]], [[Créatures]]
- **Voir aussi** : [[Claims et persistance]], [[Économie — sources et puits]], [[Simulation du monde — performance]], [[Cycle jour-nuit et sommeil]]
