---
aliases: ["B.9", "Annexe B.9", "Schéma royaume", "data/kingdoms", "Royaume"]
tags: [société, données, schéma, décidé]
domaine: société
statut: décidé
etape: 10
---

Le format de données d'un royaume : gouvernance, culture, territoire, taxes, tarifs, lois, diplomatie.

`data/kingdoms/*.json` :

```json
{
  "id": "royaume_x",
  "name_key": "kingdom.royaume_x.name",
  "government_type": "monarchie_hereditaire",
  "culture": "culture_nordique",
  "capital_poi": "ville_x_capitale",
  "territory_cells": [[14,-3], [14,-4], [15,-3]],
  "taxes": { "base_rate": 0.08, "tariff_default": 0.10 },
  "tariffs": { "gemmes": 0.35, "houille": 0.02, "artefacts": 0.50 },
  "laws": [
    { "id": "loi_meurtre", "type": "comportement", "target": "meurtre",
      "status": "illegal", "consequence": "gardes_hostiles" },
    { "id": "loi_vol", "type": "comportement", "target": "vol",
      "status": "illegal", "consequence": "amende:50" },
    { "id": "loi_pomme", "type": "objet", "target": "pomme",
      "status": "illegal", "consequence": "confiscation" }
  ],
  "diplomacy": { "royaume_y": "hostile", "royaume_z": "allie" },
  "tags": ["cotier", "commercant"]
}
```

- `government_type` ([[Familles et succession]]/[[Gouvernance, lois et diplomatie]]) : `monarchie_hereditaire`, `republique_elue`, `theocratie`, `ploutocratie`, `dictature_militaire`, `anarchie` (ce dernier : pas de `capital_poi`/leadership requis, `laws` typiquement vide ou réduite).
- `culture` (schéma [[Culture de nommage — schéma]], [[Noms culturels]]/[[Génération de noms]]) : pilote la génération des noms de PNJ, de villes, et les titres des rôles de leadership — axe **indépendant** de la race dominante (une race peut porter plusieurs cultures possibles, avec des affinités de tirage).
- `laws[].consequence` : `"gardes_hostiles"`, `"amende:N"`, `"confiscation"`, ou combinaison — résolu par le système de détection d'infraction ([[Lois et infractions]]).
- `tariffs` : surcharge par catégorie de matériau ([[Catégories de matériaux]]) au-delà de `tariff_default` ; une valeur de `1.0`+ équivaut à une interdiction totale d'import/export (invendable/impossible de faire entrer le bien).
- `territory_cells` : dérivé dynamiquement des claims/conquêtes ([[Claims et persistance]]/[[Conquête de village]]), pas saisi à la main pour les royaumes générés.

**Champ `rivals` ([[Réputation et relations]]) :** les rivalités entre races/royaumes sont déclarées en données — un gain de réputation envers X applique −25 % de ce gain envers ses rivaux déclarés.

**Taux `base_rate` ([[Barèmes économiques]]) :** module l'entretien selon la gouvernance — dictature/ploutocratie plus haut, anarchie proche 0.

**Création pour le joueur ([[Défense et raids]]) :** une entrée B.9 est créée pour le joueur au seuil de 8+ cellules claim ET 5+ PNJ résidents.

## Liens
- **Dépend de** : [[Gouvernance, lois et diplomatie]], [[Data-driven design]], [[Culture de nommage — schéma]]
- **Alimente** : [[Lois et infractions]], [[Génération des royaumes PNJ]], [[Barèmes économiques]], [[Familles et succession]], [[Défense et raids]]
- **Voir aussi** : [[Réputation et relations]], [[Catégories de matériaux]], [[Conquête de village]], [[Localisation]], [[Génération de noms]]
