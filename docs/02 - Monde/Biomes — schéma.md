---
aliases: ["B.6", "Annexe B.6", "Biome", "data/biomes"]
tags: [monde, données, schéma, décidé]
domaine: monde
statut: décidé
etape: 8
---

Le format de données d'un biome : des conditions sur les couches de bruit, une priorité, et tout ce que le biome pilote.

`data/biomes/*.json` :

```json
{
  "id": "foret_de_mana",
  "name_key": "biome.foret_de_mana.name",
  "conditions": {
    "altitude":    [0.3, 0.6],
    "temperature": [0.4, 0.7],
    "humidite":    [0.5, 1.0],
    "mana":        [0.7, 1.0]
  },
  "priority": 5,
  "element": "bois",
  "surface_material": "terre_fertile",
  "subsurface_material": "terre",
  "vegetation": [
    { "id": "if", "density": 0.05 },
    { "id": "champignon", "density": 0.02 }
  ],
  "village_palette": { "mur": "chene", "toit": "chaume_tresse", "sol": "calcaire" },
  "poi_weights": { "sanctuaire": 3, "donjon": 1, "camp": 1 },
  "farming_yield": 1.2,
  "tags": ["magique", "foret"]
}
```

- Résolution : pour chaque colonne du monde, le biome retenu est celui dont toutes les `conditions` matchent les valeurs de bruit, à la `priority` la plus haute (les biomes rares/spécifiques ont une priorité haute, les génériques une basse).

**Usages du champ `farming_yield` :** rendement agricole ([[Agriculture et élevage]], formule en [[Application des stats de matériau]] : `rendement_final = rendement_biome × (0.5 + fertilite_sol / 100)`).

**Usage du champ `poi_weights` :** tirage des POI par cellule ([[Unification macro-micro]]).

**Attention ([[Wu Xing hors combat]]) :** le vecteur élémentaire d'un **lieu** est dérivé des **couches de bruit**, jamais de l'étiquette de biome — le champ `element` ci-dessus est une propriété descriptive du biome, pas la source du vecteur de lieu.

## Liens
- **Dépend de** : [[Génération par couches de bruit]], [[Catalogue des couches de bruit]], [[Data-driven design]]
- **Alimente** : [[Biomes de départ]], [[Agriculture et élevage]], [[Unification macro-micro]], [[Créatures]]
- **Voir aussi** : [[Localisation]], [[Wu Xing hors combat]], [[Application des stats de matériau]]
