---
aliases: ["Sensen", "Index", "Index général", "森森", "Accueil", "GDD"]
tags: [index]
domaine: index
statut: décidé
etape: 0
---

# 森森 Sensen

*Conversion intégrale du Game Design Document — v2.0 (2026-08-09).*

Un **roguelike tactique** en **monde-planète** fini — continents, îles et océan — généré procéduralement et totalement continu, en vue isométrique sur grille, où le combat en **action-time à ticks** est structuré par les cinq éléments du **Wu Xing** et sa jauge de chaîne, avec une progression par l'usage à la Elona/Elin et un endgame de construction de royaume.

> **L'identité du jeu tient en une phrase :** un jeu de **décisions**, pas de dextérité.

---

## Par où commencer

Trois notes à lire avant toutes les autres :

1. **[[Décisions fondatrices]]** — la rupture du 2026-08-09, ce qui a été abandonné et pourquoi. *Décision irrévocable.*
2. **[[Ordre de construction]]** — les 11 étapes, du prototype de combat au multijoueur. *Le donjon avant le monde.*
3. **[[Contraintes permanentes]]** — les 4 règles d'architecture à respecter dès la première ligne de code.

**Héritage voxel :** nettoyé — le contenu voxel obsolète est retiré du coffre (archivé dans `archive/SENSEN_GDD.md` et l'historique git) ; les 8 **propositions à valider** vivent dans `99 - Ouvert/`. Détail : **[[Héritage voxel — audit]]**.

Puis, selon le besoin : **[[Vers la production]]** (ce qui reste avant de coder), **[[Carte des dépendances]]** (ce qui repose sur quoi) et **[[Carte — Ouvert]]** (ce qui n'est pas tranché).

**L'état de l'équilibrage, mesuré :** **[[Audit d'équilibrage — 2026-09-03]]** — quatre problèmes de fond, chacun chiffré, aucun tranché. Le technique est sain ; c'est le réglage qui demande des décisions.

---

## Les cartes de domaine

| Carte | Ce qu'elle couvre | Notes |
|---|---|---|
| **[[Carte — Vision]]** | pitch, identité, inspirations, simulation, direction artistique | 7 |
| **[[Carte — Monde]]** | grille, hauteur, biomes, donjons, météo, corruption | 28 |
| **[[Carte — Combat]]** | action-time, Wu Xing, chaîne, garde, modules | 32 |
| **[[Carte — Progression]]** | les trois axes, talents, potentiel, races, classes | 17 |
| **[[Carte — Objets]]** | matériaux, craft compositionnel, équipement, loot | 26 |
| **[[Carte — Êtres]]** | l'être unique, apparence, IA, compagnons, familles | 18 |
| **[[Carte — Société]]** | relations, guildes, économie, royaumes, lois | 36 |
| **[[Carte — Technique]]** | architecture Godot, données, performance, réseau | 22 |
| **[[Carte — Contenu]]** | les catalogues prêts à transcrire en JSON | 35 |
| **[[Carte — Ouvert]]** | décisions, défauts fixés, et ce qui reste ouvert | 44 |

---

## Les cinq notes qui portent le reste

Si une seule chose devait être comprise avant de coder :

- **[[Wu Xing — cycles et vecteurs]]** et sa **[[Jauge de chaîne Wu Xing]]** — l'identité mécanique du jeu.
- **[[Hauteur de terrain ±10]]** — 21 niveaux dont tout le combat dérive.
- **[[Action-time à ticks]]** — le temps n'avance qu'à l'action.
- **[[Potentiel]]** — ce qui régule seul toute la progression.
- **[[Data-driven design]]** — tout le contenu est de la donnée.
- **[[Blocs de l'être]]** — un roi et un mouton sont la même fiche ; la différence est un bloc vide.
- **[[Les trois axes — race, classe, fonction]]** — qui tu es, ce que tu sais, ce que tu fais. Tout être les porte.

---

## Comment naviguer ce coffre

**Les alias résolvent les références du GDD.** Chaque note porte en alias toutes les références courtes qui la désignent — `[[A.4.6]]` mène à [[Domination et multiplicateurs]], `[[E.3]]` à [[Pipeline de résolution du combat]], `[[B.13]]` à [[Composant et recette d'obtention]], `[[5.2]]` à [[Wu Xing — cycles et vecteurs]]. Aucune référence n'est du texte mort.

**Les métadonnées permettent de filtrer :**
- `statut` — `décidé` · `à-trancher` · `playtest` · `contenu-à-produire`
- `etape` — l'étape de [[Ordre de construction]] où la note devient nécessaire (0 à 11)
- `domaine` — vision, monde, combat, progression, objets, êtres, société, technique, contenu, index

Exemples de requêtes utiles : `statut: à-trancher` pour ce qui bloque · `etape: 0` pour tout ce qu'il faut avant le prototype de combat · `tag: #formule` pour les blocs de calcul.

**Chaque note se termine par une section `## Liens`** — Dépend de / Alimente / Voir aussi.

---

## Correspondance avec la structure du GDD

| Source GDD | Où c'est allé |
|---|---|
| En-tête (décision fondatrice, ordre, contraintes) | [[Décisions fondatrices]], [[Ordre de construction]], [[Contraintes permanentes]] |
| Sections 1-2 | [[Carte — Vision]] |
| Section 3 (monde) | [[Carte — Monde]] |
| Section 4 (construction, artisanat) | [[Carte — Objets]] |
| Section 5 (combat, Wu Xing) | [[Carte — Combat]] |
| Section 6 (progression) | [[Carte — Progression]] |
| Section 7 (vie simulée) | [[Carte — Société]] |
| Sections 8, 14 (multi, royaume) | [[Carte — Société]] |
| Sections 9-11 (art, technique, risques) | [[Carte — Vision]], [[Carte — Technique]] |
| Sections 12-13 (créatures, sculpture) | [[Carte — Êtres]], [[Carte — Objets]] |
| Sections 15-16 (MVP, état) | [[Ordre de construction]], [[Décisions fondatrices]] |
| Annexe A (formules) | réparties dans la note du système qu'elles chiffrent |
| Annexe B (schémas JSON) | réparties auprès du système qu'elles décrivent |
| Annexes C, F (contenu) | [[Carte — Contenu]] |
| Annexe D (architecture Godot) | [[Carte — Technique]] |
| Annexe E (intégrations) | réparties par domaine |
| Annexe G (performance) | [[Carte — Technique]] |

*Les annexes ne forment pas un dossier séparé : chaque formule vit auprès du système qu'elle chiffre, et porte son code en alias. C'est ce qui fait que `[[A.4.6]]` fonctionne tout en menant à une note nommée par son concept.*

## Liens
- **Alimente** : tout le coffre
- **Voir aussi** : [[Décisions fondatrices]], [[Ordre de construction]], [[Contraintes permanentes]], [[Carte des dépendances]]
