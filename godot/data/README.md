# godot/data — les catalogues du jeu

**Tout le contenu du jeu vit ici, en JSON.** Règles complètes : `docs/08 - Technique/Décision — Pipeline de contenu.md`.

## Les cinq règles

1. **Un fichier par entrée** — l'id est le nom du fichier (`materials/chene.json` → id `chene`). Ajouter du contenu = ajouter un fichier, zéro code.
2. **Copier le `_template.json`** du dossier, le renommer, le remplir. Le champ `_doc` est ignoré par le loader.
3. **Validation au boot** (schémas dans `schemas/`, erreurs `fichier → champ` en console, bloquantes en debug) ; **F5 recharge tout** sans relancer. Les fichiers `_*` sont ignorés.
4. **Les systèmes lisent des tags et des champs, jamais des ids** — `GameData.get(catalogue, id)` / `GameData.by_tag(catalogue, tag)`.
5. Nouvelle **entrée** = 1 fichier. Nouveau **champ** = schéma + système consommateur. Nouveau **catalogue** = 1 schéma + 1 ligne dans GameData.

## Registre

| Dossier | Contenu | Spécification (docs/) |
|---|---|---|
| materials/ | 153 matériaux | Schéma matériau (B.1), catalogues 09 - Contenu |
| items/ | objets et recettes | Schéma objet et recette (B.3) |
| functionalities/ | profils d'armes/armures/véhicules | Fonctionnalité (B.3.1) |
| modules/ | modules de capacités | Vocabulaire des modules (B.4), Modules (F.2) |
| creatures/ | créatures et PNJ | Schéma créature (B.5), Créatures (F.3) |
| creature_actions/ | actions des créatures | Décision — Vocabulaire d'attaque des créatures |
| ai_profiles/ | profils Utility AI | IA des créatures (E.16) |
| biomes/ | biomes | Biomes — schéma (B.6), C.7 |
| quest_templates/ | gabarits de quêtes | Gabarit de quête (B.7) |
| kingdoms/ | royaumes scriptés/test | Schéma royaume (B.9) |
| name_cultures/ | cultures de nommage | Culture de nommage (B.11), C.9 |
| components/, component_recipes/ | craft compositionnel | B.13, Composants (F.11) |
| status_effects/ | statuts | Statuts (F.4) |
| dungeon_rooms/, dungeon_connectors/ | prefabs de donjon | B.10, Décision — Prefabs de donjon en tuiles |
| plants/ | plantes | Plantes (F.8) |
| recipes/ | transformations de matériaux | Stations de transformation (C.8) |
| tutorials/ | tooltips contextuels | Tooltips contextuels (E.19) |
| dialogue/ | répliques d'ambiance | Dialogue PNJ (E.23) |
| races/, classes/ | races et classes, **avec leur talent** | C.2, C.3, Talents de race, Talents de classe |
| functions/ | fonctions (ex-postes de travail) | Fonctions |
| rigs/ | rigs de squelette (segments, ancrages, ordre de calque par direction) | Squelette modulaire et points d'attache |
| weather_states/ | états météo | Météo (E.28) |
| species/ | espèces d'élevage (loci, moteur, conditions, coûts) | Élevage — intention et familles (Annexe H) |
| prototype_arenas/ | arènes de l'étape 0 | Prototype de combat — spécification |
| schemas/ | JSON Schema de chaque catalogue | Décision — Pipeline de contenu |

**Configurations (fichier unique, à la racine de data/) :** `noise_layers.json` (B.8) · `material_categories.json` (B.2) · `reserved_colors.json` (12.1) · `strata.json` + `ore_bands.json` (Décision — Minerais et strates) · `reading_failures.json` (A.7) · `rare_epithets.json` (12.4) · `absurd_laws_pool.json` (E.26).

**Élevage (Annexe H) :** `species/` déclare tout — les **types de loci** (10), les **conditions** (15) et les **coûts** (6) sont du code générique, jamais du code par espèce. Ajouter une espèce = **un fichier**, et les tests de conformité vérifient qu'elle est jouable (atteignabilité, faisabilité).

**Textes :** aucun texte affichable ici — uniquement des `name_key`/`text_key`, résolues dans `godot/locale/*.csv` (fr, en, ja, zh).
