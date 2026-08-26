---
aliases: ["B.10", "Annexe B.10", "Salle de donjon", "Connecteur de donjon", "dungeon_rooms"]
tags: [monde, donjon, données, schéma, décidé]
domaine: monde
statut: décidé
etape: 2
---

> [!note] Adapté au pivot tactique
> `vox_model` devient un `plan` de tuiles 2D par étage, les positions 3D des coordonnées de tuile (format décidé : [[Décision — Prefabs de donjon en tuiles]]). Le schéma voxel d'origine est archivé dans le GDD source.

Le format de données des prefabs de donjon : salles et connecteurs, avec leurs points d'attache typés.

`data/dungeon_rooms/*.json` :

```json
{
  "id": "salle_ronde_moyenne",
  "kind": "salle",
  "size_category": "moyenne",
  "floor_theme": ["ruine", "crypte"],
  "plan": "models/dungeon/rooms/salle_ronde_moyenne.png",
  "flat_floor": false,
  "connectors": [
    { "type": "porte", "position": [0, 8], "direction": "nord" },
    { "type": "porte", "position": [8, 0], "direction": "est" }
  ],
  "special_tags": ["boss_room_eligible", "treasure_eligible"],
  "vox_slots": { "#00FF00": "roche", "#FF00FF": "minerai" }
}
```

`data/dungeon_connectors/*.json` :

```json
{
  "id": "escalier",
  "kind": "connecteur",
  "type": "escalier",
  "plan": "models/dungeon/connectors/escalier.png",
  "links_floors": true,
  "connectors": [
    { "type": "cage_escalier", "position": [0, 0], "floor": "n" },
    { "type": "cage_escalier", "position": [0, 0], "floor": "n+1" }
  ]
}
```

- `connectors[].type` doit correspondre entre une salle et le connecteur qui s'y attache (ex. `porte` ↔ `porte`, `cage_escalier` ↔ `cage_escalier`) — résolution par l'algorithme [[Génération de donjon]]. Un escalier lie deux étages (`links_floors`).
- `special_tags` pilote la sélection lors du peuplement (`boss_room_eligible`, `treasure_eligible`, `entree` réservé à la salle de départ).
- Réutilise exactement le pipeline graphique existant : couleurs stand-in de matériaux ([[Direction artistique]]) + tuiles-marqueurs d'attache ([[Squelette modulaire et points d'attache]]), aucune nouvelle technique d'import. Le `plan` porte une couche matériau (stand-in) et une couche hauteur (0-20 relatif).

## Liens
- **Dépend de** : [[Génération de donjon]], [[Data-driven design]], [[Squelette modulaire et points d'attache]]
- **Alimente** : [[Donjons — structure et intégration]]
- **Voir aussi** : [[Décisions d'architecture]], [[Ouvert — Taille des salles de donjon]]
