# 森森 Sensen

Un **roguelike tactique** en monde infini, généré procéduralement et totalement continu, en vue isométrique sur grille — combat en **action-time à ticks** structuré par les cinq éléments du **Wu Xing** et sa jauge de chaîne, progression par l'usage à la Elona/Elin, endgame de construction de royaume.

> **L'identité du jeu tient en une phrase :** un jeu de **décisions**, pas de dextérité.

**Moteur : Godot 4.x** · GDScript (GDExtension/Rust au profilage uniquement) · PC (Steam), solo et coop 4-8 en host-and-join.

## Structure du dépôt

| Chemin | Ce que c'est |
|---|---|
| [`godot/`](godot/) | Le projet Godot — squelette pour l'instant, arborescence conforme au design (D.1) |
| [`docs/`](docs/) | Le design complet : un **coffre Obsidian** de 271 notes atomiques, reliées et navigables |
| [`archive/`](archive/) | Le GDD source monolithique (v2.0) — archive de référence, les notes de `docs/` font foi |
| [`tools/`](tools/) | Outillage du dépôt — `check_vault.py` valide liens, frontmatter et comptages du coffre |

## État du projet — pré-production

Le design est complet et nettoyé : le pivot **voxel → tactique isométrique** (2026-08-09, irrévocable) est intégralement répercuté dans les notes. **Aucune question de design ne reste bloquante** : tout ce qui était ouvert a reçu une décision ou un défaut chiffré implémentable — le code n'a rien à inventer. Ce qui reste avant de coder est listé dans **`docs/00 - Index/Vers la production.md`** — en tête : l'interface, les contrôles et la caméra, puis la transcription des catalogues en JSON.

### Ordre de construction (le donjon avant le monde)

Chaque étape produit quelque chose de **jouable et jugeable**, jamais une brique invisible.

| # | Étape | Ce qu'on obtient |
|---|---|---|
| 0 | **Prototype de combat isolé** | *Le combat est-il bon ?* Rien ne démarre avant un oui. |
| 1 | Combat rapatrié + pipeline paperdoll minimal | un combat propre dans le vrai projet |
| 2 | Génération de donjon | un espace clos à explorer |
| 3 | Loot (affixes, gemmes, rareté par profondeur) | une raison de descendre |
| 4 | Progression (usage, potentiel) | une raison de recommencer |
| 5 | ⭐ **Jalon — roguelike jouable de bout en bout** | entrer, combattre, looter, progresser, ressortir |
| 6 | Matériaux + craft compositionnel | fabriquer ce qu'on n'a pas looté |
| 7 | Camp de base | un point d'ancrage entre deux expéditions |
| 8 | Génération du monde | un monde à parcourir entre les donjons |
| 9 | PNJ et villages | un monde habité |
| 10 | Royaumes, lois, économie, claims | l'endgame de territoire |
| 11 | Coop | dernier chantier, jamais avant un solo bon |

### Contraintes permanentes (dès la première ligne de code)

1. **Une partie solo EST une partie multijoueur hébergée** dont la porte est fermée — serveur autoritaire même en solo, intentions côté client, déterminisme par ticks.
2. **Une brique à la fois**, avec un critère de sortie formulé avant de commencer.
3. **`tr()` dès le premier écran** — aucune string affichable en dur, jamais (fr/en/ja/zh au lancement).
4. **Tout le contenu est de la donnée** — JSON validé au boot, hot-reload, zéro valeur de gameplay en dur.

## Lire le design

Ouvrir [`docs/`](docs/) comme coffre dans **Obsidian**. Point d'entrée : `00 - Index/Sensen — Index général.md`.

- Chaque note porte en **alias** les références du GDD (`A.4.6`, `E.3`, `B.13`…) — tous les renvois résolvent.
- Frontmatter filtrable : `statut` (décidé / à-trancher / playtest / contenu-à-produire), `etape` (0-11), `domaine`.
- `docs/99 - Ouvert/` archive les questions *tranchées depuis* : chaque note y porte sa décision et sa date.
- **Vérifier le coffre :** `python tools/check_vault.py` — liens morts, frontmatter incomplet, comptages périmés. Sortie non nulle si erreur.

## Développement

Le projet `godot/` s'ouvre avec Godot 4.x. L'arborescence (autoload, data, systems, scenes, locale) suit la note *Arborescence du projet* du design ; les dossiers sont vides en attendant l'étape 0. Prochaine étape concrète : le **prototype de combat isolé** — voir `docs/00 - Index/Vers la production.md`.
