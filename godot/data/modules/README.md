# data/modules — vide, exprès

Les 236 contenus de sorts ont été supprimés le 2026-09-13 (ordre de travail, palier 6, ligne 27). La **grammaire**
reste : l'assembleur (`systems/combat/capacites.gd`), la grille, les liaisons, les déclencheurs, le schéma
(`data/schemas/modules.schema.json`).

Les contenus seront **réécrits sur les champs** (ligne 28) : un module ne produira plus d'effet, il tournera un
bouton d'une règle du monde.

Les tests de grammaire assemblent 70 pièces figées dans `scenes/tests/fixtures/modules/`, chargées par la suite
seule (`GameData.charger_banc_d_essai`). Le jeu, lui, n'en voit aucune.
