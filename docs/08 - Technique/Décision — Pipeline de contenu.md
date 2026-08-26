---
aliases: ["Décision — Pipeline de contenu", "Pipeline de contenu", "Catalogues JSON", "Ajout de contenu"]
tags: [technique, architecture, données, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!success] Décidé le 2026-08-26
> Tranché sur délégation du designer : « l'architecture doit permettre des ajouts de contenu rapides et simples ». Cette note fixe le pipeline exact — le code s'appuie dessus.

Ajouter un matériau, un module, une créature = **créer un fichier JSON**. Jamais de code. Voici les règles exactes.

## Les cinq règles du pipeline

**1. Un fichier par entrée, l'id est le nom du fichier.**
`godot/data/materials/chene.json` définit le matériau `chene`. Ajouter du contenu = ajouter un fichier ; le supprimer = supprimer le fichier. Git-friendly (aucun conflit de merge sur un gros fichier partagé), lisible, diffable. Les rares catalogues **globaux** (couches de bruit, couleurs réservées, strates…) restent des fichiers uniques — ce sont des configurations, pas des collections.

**2. Un `_template.json` dans chaque dossier.**
Chaque dossier de catalogue contient un template commenté (champ `"_doc"` toléré et ignoré par le loader) avec tous les champs et leurs valeurs par défaut. **Créer une entrée = copier le template, le remplir.** C'est le tutoriel du catalogue, versionné avec lui.

**3. Validation de schéma au boot, hot-reload en debug.**
`godot/data/schemas/{catalogue}.schema.json` décrit chaque catalogue. Au boot, **GameData** ([[Décisions d'architecture]]) charge tout, valide chaque entrée et affiche `fichier → champ → erreur` en console (id dupliqué, champ manquant, type faux, `name_key` absente du locale, couleur dupliquée — erreurs **bloquantes en debug, warnings en release**). **F5 recharge tout `data/` sans relancer le jeu.** Les fichiers commençant par `_` sont ignorés.

**4. Les systèmes lisent des tags et des champs, jamais des ids.**
`GameData.get("materials", id)` et `GameData.by_tag("materials", "inflammable")` sont les deux seules portes d'entrée. Aucun système ne code en dur un id de contenu ([[Data-driven design]]) — le feu brûle tout ce qui a le tag `inflammable`, quel que soit le fichier qui l'a déclaré.

**5. Ce que chaque type d'ajout coûte — le contrat :**

| Ajout | Coût |
|---|---|
| Une **entrée** (matériau, module, créature, loi, biome…) | **1 fichier JSON. Zéro code.** |
| Un **champ** sur un catalogue existant | schéma + le système qui le consomme |
| Un **catalogue** entier | 1 schéma + 1 ligne d'enregistrement dans GameData |
| Un **comportement** (IA, tutoriel, dialogue, météo) | 1 fichier JSON — les profils sont des données ([[IA des créatures]], [[Tooltips contextuels]], [[Dialogue PNJ]], [[Météo]]) |

## Registre des catalogues

Le registre complet vit dans `godot/data/README.md` (versionné avec les données). Résumé — **collections** (un fichier/entrée) : `materials` ([[Schéma matériau]]) · `items` ([[Schéma objet et recette]]) · `functionalities` ([[Fonctionnalité]]) · `modules` ([[Vocabulaire des modules — six axes]]) · `creatures` ([[Schéma créature]]) · `creature_actions` ([[Décision — Vocabulaire d'attaque des créatures]]) · `ai_profiles` · `biomes` ([[Biomes — schéma]]) · `quest_templates` ([[Gabarit de quête]]) · `kingdoms` ([[Schéma royaume]]) · `name_cultures` ([[Culture de nommage — schéma]]) · `components` + `component_recipes` ([[Composant et recette d'obtention]]) · `status_effects` ([[Statuts]]) · `dungeon_rooms` + `dungeon_connectors` ([[Salles et connecteurs]]) · `plants` ([[Plantes]]) · `recipes` ([[Stations de transformation]]) · `tutorials` ([[Tooltips contextuels]]) · `dialogue` ([[Dialogue PNJ]]) · `races` + `classes` ([[Races]], [[Classes]]) · `weather_states` ([[Météo]]) · `prototype_arenas` ([[Prototype de combat — spécification]]).
**Configurations** (fichier unique) : `noise_layers.json` ([[Catalogue des couches de bruit]]) · `material_categories.json` ([[Catégories de matériaux]]) · `reserved_colors.json` ([[Squelette modulaire et points d'attache]]) · `strata.json` + `ore_bands.json` ([[Décision — Minerais et strates après le pivot]]) · `reading_failures.json` ([[Lecture des livres]]) · `rare_epithets.json` ([[Monstres rares]]) · `absurd_laws_pool.json` ([[Lois et infractions]]).

## Ce que ça garantit

- **Le contenu du coffre `docs/09 - Contenu/` se transcrit tel quel** : chaque ligne des catalogues (153 matériaux, 61 modules, 19 races animales, 18 profils de PNJ…) devient un fichier, sans interprétation.
- **L'itération est instantanée** : éditer un JSON, F5, tester — la boucle de tuning des 3 arènes du prototype ([[Prototype de combat — spécification]]) repose dessus.
- **Pas d'éditeur interne au lancement** ([[Data-driven design]], décision confirmée) : JSON à la main + templates + validation stricte suffisent ; un éditeur visuel ne sera envisagé que si le volume le justifie.

## Liens
- **Dépend de** : [[Data-driven design]], [[Décisions d'architecture]], [[Contraintes permanentes]]
- **Alimente** : [[Arborescence du projet]], [[Prototype de combat — spécification]], tous les schémas de l'Annexe B
- **Voir aussi** : [[Localisation]], [[EventBus]], [[Résolveur de modificateurs]]
