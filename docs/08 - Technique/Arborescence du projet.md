---
aliases: ["D.1", "Annexe D.1", "Arborescence", "Arborescence du projet", "Structure de dossiers"]
tags: [technique, architecture, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!note] Adapté au pivot tactique
> `systems/voxel/` renommé `systems/grid/` (chunks de tuiles, hauteur, nav-grille) ; `models/` héberge les sources graphiques 2D. Le reste de l'arborescence est inchangé.

L'organisation du projet Godot : autoloads, données, systèmes purs, scènes.

*Godot 4.x, langage principal GDScript (itération rapide), C# ou GDExtension/Rust en option ciblée pour le meshing voxel si les performances l'exigent (à profiler d'abord).*

```
res://
├── autoload/            # Singletons globaux
│   ├── GameData.gd      # Charge et indexe tout data/ au démarrage
│   ├── WorldManager.gd  # Seed, couches de bruit, streaming de chunks
│   ├── SaveManager.gd   # Sauvegarde différentielle
│   ├── NetworkManager.gd# Host/join, RPC haut niveau
│   └── EventBus.gd      # Signaux globaux inter-systèmes
├── data/                # TOUT le contenu (JSON) — pipeline : Décision — Pipeline de contenu
│   ├── materials/  ├── items/  ├── modules/  ├── creatures/
│   ├── biomes/     ├── quest_templates/  └── ...
├── systems/             # Logique pure, sans scène
│   ├── grid/            # Chunks de tuiles, hauteur, nav-grille (ex-voxel/)
│   ├── worldgen/        # Évaluation des couches de bruit, biomes, POI
│   ├── crafting/        # Recettes, qualité, stations
│   ├── combat/          # Résolution des modules, mana, dégâts
│   ├── simulation/      # Les bibliothèques statiques Sim… : les règles, l'état reste dans combat/simulation.gd (2026-09-05)
│   ├── skills/          # XP par usage, skill_factor
│   ├── economy/         # Prix, boutiques passives, abstraction hors-site
│   └── reputation/
├── scenes/
│   ├── world/           # Monde voxel, chunk.tscn
│   ├── entities/        # creature.tscn (générique !), player.tscn
│   ├── ui/              # Inventaire, craft, carte du monde, sculpture
│   └── main.tscn
├── locale/              # Traductions : fr.csv, en.csv... (voir 10.1)
├── models/              # sources graphiques 2D (parties paperdoll, prefabs)
└── addons/
```

**Système à ajouter ([[Habitat des PNJ]]) :** la détection de pièce est à ranger dans `systems/` — voir [[Détection de pièces]].

**Autres dossiers de données cités ailleurs :** `data/functionalities/`, `data/recipes/`, `data/components/`, `data/component_recipes/`, `data/status_effects/`, `data/ai_profiles/`, `data/tutorials/`, `data/dialogue/`, `data/kingdoms/`, `data/name_cultures/`, `data/dungeon_rooms/`, `data/dungeon_connectors/`, `data/plants/`, `data/weather_states/`, `data/minerais_par_etage.json`, `data/minerais_par_etage.json`, `data/palette_materiaux.json`, `data/reading_failures.json`, `data/rare_epithets.json`, `data/absurd_laws_pool.json`, `data/noise_layers.json`, `data/material_categories.json`.

**Le pipeline des catalogues data/ est décidé et squeletté :** [[Décision — Pipeline de contenu]] (`godot/data/README.md` + un `_template.json` par dossier).

## Liens
- **Dépend de** : [[Data-driven design]]
- **Alimente** : [[Décisions d'architecture]], [[EventBus]], [[Sauvegarde]], [[Réseau]]
- **Voir aussi** : [[Localisation]], [[Détection de pièces]], [[Squelette modulaire et points d'attache]], [[Ordre de construction]], [[Optimisation — principes]]
