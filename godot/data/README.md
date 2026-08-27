# godot/data — les catalogues du jeu

**Tout le contenu du jeu vit ici, en JSON.** Règles complètes : `docs/08 - Technique/Décision — Pipeline de contenu.md`.

## Les cinq règles

1. **Un fichier par entrée** — l'id est le nom du fichier (`materials/chene.json` → id `chene`). Ajouter du contenu = ajouter un fichier, zéro code.
2. **Copier le `_template.json`** du dossier, le renommer, le remplir. Le champ `_doc` est ignoré par le loader.
3. **Validation au boot** (schémas dans `schemas/`, erreurs `fichier → champ` en console, bloquantes en debug) ; **F5 recharge tout** sans relancer. Les fichiers `_*` sont ignorés.
4. **Les systèmes lisent des tags et des champs, jamais des ids** — `GameData.entree(catalogue, id)` / `GameData.par_tag(catalogue, tag)` (`get` est réservé par `Object` en GDScript) ; configurations : `GameData.config(nom)` / `GameData.regle("combat_rules/endurance/max")`.
5. Nouvelle **entrée** = 1 fichier. Nouveau **champ** = schéma + système consommateur. Nouveau **catalogue** = 1 schéma + 1 ligne dans GameData.

## Registre

| Dossier | Contenu | Spécification (docs/) |
|---|---|---|
| materials/ | 153 matériaux | Schéma matériau (B.1), catalogues 09 - Contenu |
| items/ | objets et recettes ; `proto_*` = objets du prototype (dureté, qualité et élément fixés à la main en attendant le craft) | Schéma objet et recette (B.3), Stats d'armes |
| functionalities/ | profils d'armes/armures/véhicules | Fonctionnalité (B.3.1) |
| modules/ | les 176 composants ; `effet` = forme structurée des descriptions (`tools/structure_modules.py`) | Vocabulaire des modules (B.4), Modules (F.2) |
| creatures/ | tout être (joueur compris) : `corps.stats`, `equipement`, `ratelier`, `actions`, `capacites` (séquences de modules) | Schéma créature (B.5), Blocs de l'être, Créatures (F.3) |
| creature_actions/ | les 24 actions des créatures (`tools/gen_creature_actions.py` les transcrit) | Décision — Vocabulaire d'attaque des créatures, Actions des créatures |
| ai_profiles/ | profils Utility AI (`hostile`, `bete_sauvage`, `compagnon`, `elite`) | IA des créatures (E.16) |
| biomes/ | biomes | Biomes — schéma (B.6), C.7 |
| quest_templates/ | gabarits de quêtes | Gabarit de quête (B.7) |
| kingdoms/ | royaumes scriptés/test | Schéma royaume (B.9) |
| name_cultures/ | cultures de nommage | Culture de nommage (B.11), C.9 |
| components/, component_recipes/ | craft compositionnel | B.13, Composants (F.11) |
| status_effects/ | les 14 statuts du prototype (`tools/gen_status_effects.py`) : période, durée, contrôle, modifiers par cible générique | Statuts (F.4), Statuts de contrôle et anti-stunlock |
| dungeon_rooms/, dungeon_connectors/, dungeon_themes/ | 12 salles + 8 connecteurs en grilles de caractères (`tools/gen_dungeon_prefabs.py`), thèmes (pool, boss, densité, étages) | B.10, Décision — Prefabs de donjon en tuiles, Génération de donjon |
| plants/ | plantes | Plantes (F.8) |
| recipes/ | transformations de matériaux | Stations de transformation (C.8) |
| tutorials/ | tooltips contextuels (signal EventBus + conditions → text_key) | Tooltips contextuels (E.19) |
| dialogue/ | répliques d'ambiance | Dialogue PNJ (E.23) |
| races/, classes/ | races et classes, **avec leur talent** | C.2, C.3, Talents de race, Talents de classe |
| functions/ | fonctions (ex-postes de travail) | Fonctions |
| rigs/ | les 4 rigs (`tools/gen_rigs.py`) : segments, ancrages, facings, slots peints | Squelette modulaire et points d'attache |
| weather_states/ | états météo | Météo (E.28) |
| species/ | espèces d'élevage (loci, moteur, conditions, coûts) | Élevage — intention et familles (Annexe H) |
| prototype_arenas/ | arènes de l'étape 0 (3 arènes, posées par `tools/gen_arenas.py`) | Prototype de combat — spécification |
| affixes/ | les 36 gabarits d'affixes (`tools/gen_affixes.py`) : fourchettes, effet, budget, slots | Loot — affixes, gemmes et rareté |
| schemas/ | JSON Schema (sous-ensemble : type, required, properties, items, enum, min/max) de chaque catalogue | Décision — Pipeline de contenu |

**Configurations (fichier unique, à la racine de data/) :** `combat_rules.json` (toutes les constantes chiffrées du combat, chacune citant sa note — Boucle de tick, Endurance, Zones de coup, Armure par zone…) · `tile_contents.json` (contenus de tuile par tags) · `wuxing.json` (cycles, multiplicateurs, jauge de chaîne, teintes) · `palette_materiaux.json` (155 teintes, `tools/gen_palette.py`) · `loot_rules.json` (grille de rareté par étage, budgets, contenants, monstres rares) · `noise_layers.json` (B.8) · `material_categories.json` (B.2) · `reserved_colors.json` (12.1) · `strata.json` + `ore_bands.json` (Décision — Minerais et strates) · `reading_failures.json` (A.7) · `rare_epithets.json` (12.4) · `absurd_laws_pool.json` (E.26).

**Élevage (Annexe H) :** `species/` déclare tout — les **types de loci** (10), les **conditions** (15) et les **coûts** (6) sont du code générique, jamais du code par espèce. Ajouter une espèce = **un fichier**, et les tests de conformité vérifient qu'elle est jouable (atteignabilité, faisabilité).

**Textes :** aucun texte affichable ici — uniquement des `name_key`/`text_key`, résolues dans `godot/locale/*.csv` (fr, en, ja, zh).

**Catalogues chargés par GameData (étape 0) :** `modules`, `creatures`, `creature_actions`, `ai_profiles`, `functionalities`, `items`, `status_effects`, `prototype_arenas`, plus les configurations `combat_rules`, `tile_contents` et `wuxing`. Ajouter un catalogue = son schéma dans `schemas/` + une ligne dans `autoload/game_data.gd`. Les dossiers `exemples_*` sont des exemples générés, pas des catalogues.
