---
aliases: ["B.10", "Annexe B.10", "Salle de donjon", "Connecteur de donjon", "dungeon_rooms"]
tags: [monde, donjon, données, schéma, décidé, héritage-voxel]
domaine: monde
statut: décidé
etape: 2
---

> [!warning] Héritage voxel
> `vox_model` et les positions 3D des connecteurs sont héritage : les prefabs deviennent des **plans de tuiles 2D par étage** (avec hauteurs de tuile pour estrades/fosses). Les points d'attache typés et `special_tags` survivent.
> — Classement : [[Héritage voxel — audit]] · **Proposition de remplacement à valider : [[Proposition — Prefabs de donjon en tuiles]]**.

Le format de données des prefabs de donjon : salles et connecteurs, avec leurs points d'attache typés.

`data/dungeon_rooms/*.json` :

```json
{
  "id": "salle_ronde_moyenne",
  "kind": "salle",
  "size_category": "moyenne",
  "floor_theme": ["ruine", "crypte"],
  "vox_model": "models/dungeon/rooms/salle_ronde_moyenne.vox",
  "flat_floor": false,
  "connectors": [
    { "type": "porte", "position": [0, 0, 8], "direction": "nord" },
    { "type": "porte", "position": [8, 0, 0], "direction": "est" }
  ],
  "special_tags": ["boss_room_eligible", "treasure_eligible"],
  "vox_slots": { "#00FF00": "roche", "#FF00FF": "minerai" }
}
```

`data/dungeon_connectors/*.json` :

```json
{
  "id": "escalier_descendant",
  "kind": "connecteur",
  "type": "escalier",
  "vertical_offset": -16,
  "vox_model": "models/dungeon/connectors/escalier_descendant.vox",
  "connectors": [
    { "type": "cage_escalier_haut", "position": [0, 0, 0] },
    { "type": "cage_escalier_bas", "position": [0, -16, 0] }
  ]
}
```

- `connectors[].type` doit correspondre entre une salle et le connecteur qui s'y attache (ex. `porte` ↔ `porte`, `cage_escalier_haut` ↔ `cage_escalier_bas`) — résolution par l'algorithme [[Génération de donjon]].
- `special_tags` pilote la sélection lors du peuplement (`boss_room_eligible`, `treasure_eligible`, `entree` réservé à la salle de départ).
- Réutilise exactement le pipeline `.vox` existant : couleurs stand-in de matériaux ([[Direction artistique]]) + marqueurs d'attache ([[Squelette modulaire et points d'attache]]), aucune nouvelle technique d'import.

## Liens
- **Dépend de** : [[Génération de donjon]], [[Data-driven design]], [[Squelette modulaire et points d'attache]]
- **Alimente** : [[Donjons — structure et intégration]]
- **Voir aussi** : [[Décisions d'architecture]], [[Ouvert — Taille des salles de donjon]]
