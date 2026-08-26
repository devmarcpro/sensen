---
aliases: ["D.1", "Annexe D.1", "Arborescence", "Arborescence du projet", "Structure de dossiers"]
tags: [technique, architecture, décidé]
domaine: technique
statut: décidé
etape: 0
---

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
├── data/                # TOUT le contenu (JSON) — voir Annexe B
│   ├── materials/  ├── items/  ├── modules/  ├── creatures/
│   ├── biomes/     ├── quest_templates/  └── ...
├── systems/             # Logique pure, sans scène
│   ├── voxel/           # Chunks, meshing, subdivision (octree par bloc)
│   ├── worldgen/        # Évaluation des couches de bruit, biomes, POI
│   ├── crafting/        # Recettes, qualité, stations
│   ├── combat/          # Résolution des modules, mana, dégâts
│   ├── skills/          # XP par usage, skill_factor
│   ├── economy/         # Prix, boutiques passives, abstraction hors-site
│   └── reputation/
├── scenes/
│   ├── world/           # Monde voxel, chunk.tscn
│   ├── entities/        # creature.tscn (générique !), player.tscn
│   ├── ui/              # Inventaire, craft, carte du monde, sculpture
│   └── main.tscn
├── locale/              # Traductions : fr.csv, en.csv... (voir 10.1)
├── models/              # .vox sources (importés par script custom)
└── addons/
```

**Système à ajouter ([[Habitat des PNJ]]) :** la détection de pièce est à ranger dans `systems/` — voir [[Détection de pièces]].

**Autres dossiers de données cités ailleurs :** `data/functionalities/`, `data/recipes/`, `data/components/`, `data/component_recipes/`, `data/status_effects/`, `data/ai_profiles/`, `data/tutorials/`, `data/dialogue/`, `data/kingdoms/`, `data/name_cultures/`, `data/dungeon_rooms/`, `data/dungeon_connectors/`, `data/plants/`, `data/weather_states.json`, `data/strata.json`, `data/ore_bands.json`, `data/reserved_colors.json`, `data/reading_failures.json`, `data/rare_epithets.json`, `data/absurd_laws_pool.json`, `data/noise_layers.json`, `data/material_categories.json`.

## Liens
- **Dépend de** : [[Data-driven design]]
- **Alimente** : [[Décisions d'architecture]], [[EventBus]], [[Sauvegarde]], [[Réseau]]
- **Voir aussi** : [[Localisation]], [[Détection de pièces]], [[Squelette modulaire et points d'attache]], [[Ordre de construction]], [[Optimisation — principes]]
