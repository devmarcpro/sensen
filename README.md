# 森森 Sensen

Game Design Document de **Sensen** — un roguelike tactique en monde infini généré procéduralement et totalement continu, en vue isométrique sur grille, dont le combat en action-time à ticks est structuré par les cinq éléments du **Wu Xing**.

> **L'identité du jeu tient en une phrase :** un jeu de **décisions**, pas de dextérité.

## Contenu du dépôt

| Chemin | Ce que c'est |
|---|---|
| [`SENSEN_GDD.md`](SENSEN_GDD.md) | Le GDD source, d'un seul tenant (v2.0, 2026-08-09) |
| [`docs/`](docs/) | Le même contenu converti en **coffre Obsidian** — 229 notes atomiques, reliées et navigables |

Les deux sont équivalents en contenu : la conversion est sans perte. Le coffre ajoute le découpage, les liens et les métadonnées.

## Le coffre Obsidian

Ouvrir le dossier [`docs/`](docs/) comme coffre dans Obsidian. Point d'entrée : **`00 - Index/Sensen — Index général.md`**.

```
00 - Index/       index général, cartes de domaine, décisions fondatrices,
                  ordre de construction, contraintes, carte des dépendances
01 - Vision/      pitch, identité, inspirations, direction artistique
02 - Monde/       grille, hauteur, biomes, donjons, météo, corruption
03 - Combat/      action-time, Wu Xing, jauge de chaîne, garde, modules
04 - Progression/ usage, potentiel, races, classes, astrologie
05 - Objets/      matériaux, craft compositionnel, équipement, loot
06 - Êtres/       schéma unifié, IA, compagnons, familles, noms
07 - Société/     relations, guildes, économie, royaumes, lois
08 - Technique/   architecture Godot, données, performance, réseau
09 - Contenu/     catalogues prêts à transcrire en JSON
99 - Ouvert/      une note par question non tranchée
```

### Navigation

**Les alias résolvent les références du GDD.** Chaque note porte en alias toutes les références qui la désignent : `[[A.4.6]]` mène à la jauge de chaîne, `[[E.3]]` au pipeline de combat, `[[B.13]]` au schéma des composants. Les **154 sections numérotées** du GDD sont toutes adressables.

**Les métadonnées permettent de filtrer :**

- `statut` — `décidé` (200) · `à-trancher` (16) · `contenu-à-produire` (7) · `playtest` (6)
- `etape` — l'étape de l'ordre de construction où la note devient nécessaire (0 à 11)
- `domaine` — vision, monde, combat, progression, objets, êtres, société, technique, contenu, index

Requêtes utiles : `statut: à-trancher` pour ce qui bloque · `etape: 0` pour tout ce qu'il faut avant le prototype de combat.

Chaque note se termine par une section `## Liens` — Dépend de / Alimente / Voir aussi.

## Par où commencer

1. **Décisions fondatrices** — la rupture du 2026-08-09, ce qui a été abandonné et pourquoi
2. **Ordre de construction** — les 11 étapes, du prototype de combat au multijoueur
3. **Contraintes permanentes** — les 4 règles d'architecture à respecter dès la première ligne de code

## État

Toutes les décisions de design sont tranchées. Ce qui reste ouvert est isolé dans `99 - Ouvert/` : 26 questions, dont 7 trous connus du combat à traiter avant ou pendant le prototype.
