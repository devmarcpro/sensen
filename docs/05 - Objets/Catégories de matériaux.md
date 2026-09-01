---
aliases: ["B.2", "Annexe B.2", "Catégories de matériaux", "material_categories"]
tags: [objets, matériaux, données, schéma, décidé]
domaine: objets
statut: décidé
etape: 6
---

Les catégories de matériaux, chacune liée à un outil, une compétence de récolte et une station de transformation.

**Décision (4.2) — Catégories figées (11, alignées sur le catalogue [[Catalogue matériaux — Bois]] et suivants) :** bois, métal (minerai), roche, terre, végétal/fibre, liquide, minéral, fossile, gemme/cristal, météorologique, synthétique.

**Table outils/compétences par catégorie** — `data/material_categories.json` :

```json
{
  "bois":        { "tool": "hache",   "harvest_skill": "bucheronnage", "station_transform": "scierie" },
  "minerai":     { "tool": "pioche",  "harvest_skill": "minage",       "station_transform": "forge" },
  "roche":       { "tool": "pioche",  "harvest_skill": "minage",       "station_transform": "tailleur_pierre" },
  "terre":       { "tool": "pelle",   "harvest_skill": "terrassement", "station_transform": null },
  "vegetal":     { "tool": "faucille","harvest_skill": "herboristerie","station_transform": "atelier_tissage" },
  "liquide":     { "tool": "seau",    "harvest_skill": "collecte",     "station_transform": "alambic" },
  "cristal":     { "tool": "pioche",  "harvest_skill": "minage",       "station_transform": "table_enchantement" },
  "synthetique": { "tool": null,      "harvest_skill": null,           "station_transform": "atelier" }
}
```

> *Note : la table B.2 énumère 8 entrées ; la décision de la section 4.2 fige **11** catégories (ajoutant minéral, fossile, météorologique). Les catégories supplémentaires suivent la même structure — outil pioche / compétence Minage pour minéral et fossile, cf. les en-têtes du catalogue [[Catalogue matériaux — Minéraux]] et [[Catalogue matériaux — Fossiles]] ; les matériaux météorologiques ([[Catalogue matériaux — Météorologiques]]) apparaissent/disparaissent selon la météo et sont récoltables.*

**Vecteur Wu Xing dérivé de la catégorie ([[Wu Xing hors combat]]) :** métal→Métal, bois/fibre→Bois, roche/terre→Terre, liquide/glace→Eau, forte flammabilité→Feu — avec un champ `wuxing` optionnel pour les exceptions.

**Recettes par catégorie ([[Fabrication d'outils]]) :** un outil peut être fabriqué avec n'importe quel matériau, tant que les matériaux utilisés correspondent aux **catégories** requises par la recette.

**Familles de matériaux dans le craft compositionnel :** le champ `material_family` de [[Composants]] reprend cette logique de catégorie acceptée.

**Tarifs douaniers par catégorie :** [[Gouvernance, lois et diplomatie]] (`tariffs` de [[Schéma royaume]]).

> [!success] Codé le 2026-08-28 — `data/material_categories.json`, les 11 catégories
> Complété pour les trois catégories que la table ne donnait pas : `mineral` et `fossile` → pioche / Minage (comme leurs en-têtes de catalogue) ; **`meteorologique` → pelle / Terrassement** (décidé ici : on pellette la neige et la glace). Ids des stations en snake_case (`tailleur_de_pierre`, `atelier_tissage`, `table_enchantement`, `etabli`).

> [!success] Codé le 2026-09-01 — le cuir dit de quelle bête il vient (designer, point 69)
> « un casque en cuir ne devrait pas être juste ça, en cuir de quoi ? ». Il n'existait qu'un seul matériau `cuir`, et tanner deux peaux — de loup, d'ours polaire ou de basilic — donnait la même matière.
> **Première version, refusée par le designer le jour même** : j'avais écrit **vingt-deux fichiers de matériau**, un par espèce à peau. « Les cuirs ne doivent pas être codés en dur, l'espèce est un modificateur sur l'item. » Il a raison, et c'est la règle du coffre : un matériau par espèce, c'est du contenu figé à maintenir, et il aurait fallu recommencer pour l'os, la fourrure, la corne, puis pour chaque bête ajoutée.
> **La bonne forme** : **un seul** matériau `cuir`, et l'**espèce voyage sur l'objet**. La peau porte son espèce depuis la dépouille, la pile de cuir tannée en hérite, le composant façonné aussi, et l'objet assemblé la porte jusqu'à son nom. Les stats du matériau sont **modulées à l'instanciation** par les stats de la bête, selon une formule qui vit dans `combat_rules.craft.materiau_espece` — quelles stats bougent, et de combien par point. Un ours polaire durcit et alourdit son cuir, un serpent venimeux l'assouplit et l'allège. Zéro fichier par espèce, zéro clé de traduction par espèce : le nom se compose (`material.avec_espece`), et **la mécanique vaudra pour l'os et la fourrure sans une ligne de plus**.


## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Schéma matériau]]
- **Alimente** : [[Récolte]], [[Stations de transformation]], [[Composants]], [[Wu Xing hors combat]]
- **Voir aussi** : [[Compétences — liste]], [[Schéma royaume]], [[Catalogue matériaux — Bois]], [[Fabrication d'outils]]
