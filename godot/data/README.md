# godot/data — les catalogues du jeu

**Tout le contenu du jeu vit ici, en JSON.** Règles complètes : `docs/08 - Technique/Décision — Pipeline de contenu.md`.

## Les cinq règles

1. **Un fichier par entrée** — l'id est le nom du fichier (`materials/bois/chene.json` → id `chene`). Ajouter du contenu = ajouter un fichier, zéro code. Depuis le 2026-08-29 un catalogue peut être **rangé en sous-dossiers** (chargement récursif) : le dossier n'est qu'un classement pour l'humain, **l'id reste le nom du fichier** et doit rester unique dans le catalogue (le loader le vérifie). Rangements en place : `modules/<module_type>/`, `items/<type>/`, `affixes/<famille>/`, `materials/<category>/`, `plants/<catégorie>/`, `status_effects/<potion|controle|negatif|positif>/`.
2. **Copier le `_template.json`** du dossier, le renommer, le remplir. Le champ `_doc` est ignoré par le loader.
3. **Validation au boot** (schémas dans `schemas/`, erreurs `fichier → champ` en console, bloquantes en debug) ; **F5 recharge tout** sans relancer. Les fichiers `_*` sont ignorés.
4. **Les systèmes lisent des tags et des champs, jamais des ids** — `GameData.entree(catalogue, id)` / `GameData.par_tag(catalogue, tag)` (`get` est réservé par `Object` en GDScript) ; configurations : `GameData.config(nom)` / `GameData.regle("combat_rules/endurance/max")`.
5. Nouvelle **entrée** = 1 fichier. Nouveau **champ** = schéma + système consommateur. Nouveau **catalogue** = 1 schéma + 1 ligne dans GameData.

## Registre

| Dossier | Contenu | Spécification (docs/) |
|---|---|---|
| materials/ | les 157 matériaux des 11 catalogues (`tools/gen_materials.py`, + os et os massif des dépouilles, + verre trempé, brique réfractaire, béton du palier industriel), 13 stats, couleur, Wu Xing | Schéma matériau (B.1), catalogues 09 - Contenu |
| items/ | objets et recettes ; `proto_*` = objets du prototype (dureté, qualité et élément fixés à la main en attendant le craft) | Schéma objet et recette (B.3), Stats d'armes |
| functionalities/ | profils d'armes/armures/véhicules | Fonctionnalité (B.3.1) |
| modules/ | les 176 composants ; `effet` = forme structurée des descriptions (`tools/structure_modules.py`) | Vocabulaire des modules (B.4), Modules (F.2) |
| creatures/ | tout être (joueur compris) : `corps.stats`, `equipement`, `ratelier`, `actions`, `capacites` (séquences de modules) | Schéma créature (B.5), Blocs de l'être, Créatures (F.3) |
| creature_actions/ | les 24 actions des créatures (`tools/gen_creature_actions.py` les transcrit) | Décision — Vocabulaire d'attaque des créatures, Actions des créatures |
| ai_profiles/ | profils Utility AI (`hostile`, `bete_sauvage`, `compagnon`, `elite`) | IA des créatures (E.16) |
| vegetaux/ | silhouettes des arbres et plantes récoltables (billboards par code) | Direction artistique (callout du 2026-08-28) |
| functions/, dialogue/, name_cultures/, village_buildings/ | fonctions (portefeuille, classes possibles), répliques d'ambiance, 7 cultures de nommage (`tools/gen_name_cultures.py`), bâtiments de hameau | Fonctions, Dialogue PNJ, Génération de noms, Villages PNJ |
| biomes/ | les biomes (4 sur 12 en 8.1) : conditions sur les couches, priorité, matériau de sol, végétation, rochers | Biomes — schéma (B.6), C.7 |
| quest_templates/ | gabarits de quêtes | Gabarit de quête (B.7) |
| kingdoms/ | royaumes scriptés/test | Schéma royaume (B.9) |
| name_cultures/ | cultures de nommage | Culture de nommage (B.11), C.9 |
| components/, component_recipes/ | craft compositionnel | B.13, Composants (F.11) |
| status_effects/ | les 14 statuts du prototype (`tools/gen_status_effects.py`) : période, durée, contrôle, modifiers par cible générique | Statuts (F.4), Statuts de contrôle et anti-stunlock |
| dungeon_rooms/, dungeon_connectors/, dungeon_themes/ | 12 salles + 8 connecteurs en grilles de caractères (`tools/gen_dungeon_prefabs.py`), thèmes (pool, boss, densité, étages) | B.10, Décision — Prefabs de donjon en tuiles, Génération de donjon |
| plants/ | plantes | Plantes (F.8) |
| recipes/ | les 9 transformations plates (fondre, scier, tailler, tisser…) | Stations de transformation (C.8) |
| components/, component_recipes/ | les 14 composants et la matrice de leurs recettes par famille (`material_families.json`) ; objets assemblés `items/craft_*` | Composants, Recettes de composants, Craft compositionnel |
| meubles/ | les 16 meubles + la statue (contenus de tuile) ; objets `items/meuble_*`, recettes `recipes/meuble_*` | Meubles (F.6) |
| stations/ | les 9 stations (poids, compétence) ; portatives = objets `station_<id>` | Stations de transformation (C.8) |
| tutorials/ | tooltips contextuels (signal EventBus + conditions → text_key) | Tooltips contextuels (E.19) |
| dialogue/ | répliques d'ambiance | Dialogue PNJ (E.23) |
| races/, classes/ | les 3 races et 8 classes visibles : bonus, kit, potentiels de base, talent (`tools/gen_progression_data.py`) | C.2, C.3, Talents de race, Talents de classe |
| functions/ | fonctions (ex-postes de travail) | Fonctions |
| rigs/ | les 4 rigs (`tools/gen_rigs.py`) : segments, ancrages, facings, slots peints | Squelette modulaire et points d'attache |
| weather_states/ | les 10 états météo (temp_mod, visibility_mult, effects) ; la météo est une fonction pure `Simulation.meteo` | Météo (E.28) |
| species/ | espèces d'élevage (loci, moteur, conditions, coûts) | Élevage — intention et familles (Annexe H) |
| prototype_arenas/ | arènes de l'étape 0 (3 arènes, posées par `tools/gen_arenas.py`) | Prototype de combat — spécification |
| affixes/ | les 36 gabarits d'affixes (`tools/gen_affixes.py`) : fourchettes, effet, budget, slots | Loot — affixes, gemmes et rareté |
| competences/ | les 58 compétences : catégorie combat/général, stat associée, famille | Compétences — liste, Double niveau |
| schemas/ | JSON Schema (sous-ensemble : type, required, properties, items, enum, min/max) de chaque catalogue | Décision — Pipeline de contenu |

**Configurations (fichier unique, à la racine de data/) :** `combat_rules.json` (toutes les constantes chiffrées du combat, chacune citant sa note — Boucle de tick, Endurance, Zones de coup, Armure par zone…) · `tile_contents.json` (contenus de tuile par tags) · `wuxing.json` (cycles, multiplicateurs, jauge de chaîne, teintes) · `palette_materiaux.json` (155 teintes, `tools/gen_palette.py`) · `loot_rules.json` (grille de rareté par étage, budgets, contenants, monstres rares, gemmes, livres) · `rare_epithets.json` · `reading_failures.json` · `astrologie.json` · `material_categories.json` · `camp.json` · `noise_layers.json` (les 8 couches) · `planete.json` (taille, cellule de départ, accidents de relief, filons de surface) · `noise_layers.json` (B.8) · `material_categories.json` (B.2) · `reserved_colors.json` (12.1) · `strata.json` + `ore_bands.json` (Décision — Minerais et strates) · `reading_failures.json` (A.7) · `rare_epithets.json` (12.4) · `absurd_laws_pool.json` (E.26).

**Élevage (Annexe H) :** `species/` déclare tout — les **types de loci** (10), les **conditions** (15) et les **coûts** (6) sont du code générique, jamais du code par espèce. Ajouter une espèce = **un fichier**, et les tests de conformité vérifient qu'elle est jouable (atteignabilité, faisabilité).

**Textes :** aucun texte affichable ici — uniquement des `name_key`/`text_key`, résolues dans `godot/locale/*.csv` (fr, en, ja, zh).

**Catalogues chargés par GameData (étape 0) :** `modules`, `creatures`, `creature_actions`, `ai_profiles`, `functionalities`, `items`, `status_effects`, `prototype_arenas`, plus les configurations `combat_rules`, `tile_contents` et `wuxing`. Ajouter un catalogue = son schéma dans `schemas/` + une ligne dans `autoload/game_data.gd`. Les dossiers `exemples_*` sont des exemples générés, pas des catalogues.

## `modules/` — rangés par type, puis par famille

Le sous-dossier n'est qu'un classement pour l'humain (l'id reste le nom du fichier) ; la **famille** est aussi le champ `famille` de la fiche, et l'**origine** d'une forme (`cible` : projetée sur la tuile visée · `lanceur` : émise depuis soi) est son champ `origine`.

- `condition/`
  - `cible/` — achevement, affinite, entravee, escorte, isolement, prise
  - `monde/` — corruption, heure, intemperie, terroir
  - `porteur/` — chaine_pleine, dernier_souffle, ombre, pleine_garde, resonance
  - `position/` — angle_mort, champ_libre, contrebas, pied_ferme, surplomb
- `forme/`
  - `cible/` — anneau, carre, colonne, croix, diagonale, mur, nuee, point, sillage, tuile
  - `lanceur/` — chemin, cone, horizon, ligne, soi, vague
- `modificateur/`
  - `discretion/` — sans_trace, silencieux
  - `effet/` — detonation, emprise, gravite, ligature, perforant, persistance, remanence, repulsion, vampirique
  - `element/` — amorce, prisme, purete, transmutation
  - `forme/` — evasement, ricochet_mural, tracant
  - `portee/` — allonge, corps_a_corps, longue_vue, sans_angle_mort
  - `puissance/` — canalisation, concentration, surcharge
  - `taille/` — ampleur, focale, fragmentation
  - `tempo/` — enchainement, patience, precipitation, vivacite
- `noyau/`
  - `arme/` — botte, charge_d_epaule, estoc, etourdissement, fauchage, feinte, frappe, saignement
  - `controle/` — aveuglement, celerite, desarmement, effroi, empoigne, entrave, epuisement, rapt_de_tempo, rupture, silence, torpeur
  - `defense/` — absorption, ancrage, ecaille_elementaire, egide, reflet, voile
  - `degats_leger/` — aiguille, bruine, epine, etincelle, gravier
  - `degats_lourd/` — banquise, brasier, eboulement, fonte, foudroiement
  - `degats_moyen/` — eclat, flamme, gel, roche, ronce, trait_nu
  - `espace/` — ancre, attraction, convocation, elan, envol, levitation, permutation, portail, poussee, projection, retour, traversee
  - `ressource/` — estimation, fiole, meditation, offrande, pari, ponction, saignee, second_souffle, souffle_rendu, traque, trempe, vapeur
  - `soin/` — baume, communion, purge, rappel_a_la_vie, renaissance, reserve, seve, transfert
  - `terrain/` — balise, barriere, bombe, cataclysme, echo_de_chair, exhaussement, fosse, nappe, racine, releve, sol_vif, tourelle, voile_de_brume
- `declencheur/`, `liaison/` — sans famille : douze fiches chacun, à plat.
