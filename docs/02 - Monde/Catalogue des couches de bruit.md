---
aliases: ["B.8", "Annexe B.8", "noise_layers.json"]
tags: [monde, données, schéma, décidé]
domaine: monde
statut: décidé
etape: 8
---

Les paramètres chiffrés des 8 couches de bruit, en données.

`data/noise_layers.json` :

```json
{
  "altitude":    { "type": "fbm",     "octaves": 5, "frequency": 0.0008, "seed_offset": 1 },
  "temperature": { "type": "simplex", "octaves": 3, "frequency": 0.0005, "seed_offset": 2 },
  "humidite":    { "type": "simplex", "octaves": 3, "frequency": 0.0005, "seed_offset": 3 },
  "mana":        { "type": "simplex", "octaves": 4, "frequency": 0.0012, "seed_offset": 4 },
  "danger":      { "type": "simplex", "octaves": 2, "frequency": 0.0004, "seed_offset": 5 },
  "vegetation":  { "type": "simplex", "octaves": 3, "frequency": 0.002,  "seed_offset": 6 },
  "sismique":    { "type": "simplex", "octaves": 2, "frequency": 0.0006, "seed_offset": 7 },
  "ressources":  { "type": "fbm",     "octaves": 4, "frequency": 0.003,  "seed_offset": 8 }
}
```

Toutes dérivées d'une seed monde unique + `seed_offset` (reproductibilité totale).

## Liens
- **Dépend de** : [[Génération par couches de bruit]], [[Data-driven design]]
- **Alimente** : [[Biomes — schéma]], [[Terrain spectaculaire]], [[Dérive de la corruption]], [[Minerais par profondeur]]
- **Voir aussi** : [[Génération procédurale — performance]], [[Décisions d'architecture]]
