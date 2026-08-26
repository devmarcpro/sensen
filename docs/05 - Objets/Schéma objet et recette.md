---
aliases: ["B.3", "Annexe B.3", "Schéma objet", "data/items", "Recette"]
tags: [objets, données, schéma, décidé, héritage-voxel]
domaine: objets
statut: décidé
etape: 6
---

> [!warning] Héritage voxel
> `vox_model` et `vox_slots` sont héritage : leurs équivalents sont des sprites 2D avec le même mécanisme de couleurs stand-in ([[Squelette modulaire et points d'attache]]). La structure du schéma tient.
> — Classement complet : [[Héritage voxel — audit]].

Le format de données d'un objet et de sa recette.

`data/items/*.json` :

```json
{
  "id": "pioche",
  "name_key": "item.pioche.name",
  "type": "outil",
  "equip_slot": "arme",
  "hands": 1,
  "functionality": "recolte_minage",
  "recipe": {
    "station": "etabli",
    "craft_skill": "menuiserie",
    "inputs": [
      { "category": "bois",    "amount": 2 },
      { "category": "minerai", "amount": 3 }
    ]
  },
  "stat_weights": { "durete": { "minerai": 0.8, "bois": 0.2 } },
  "vox_model": "models/tools/pioche.vox",
  "vox_slots": { "#00FF00": "bois", "#FF00FF": "minerai" },
  "effects": [],
  "tags": ["outil", "recolte"]
}
```

- `vox_slots` : mapping couleur stand-in → catégorie de matériau ([[Squelette modulaire et points d'attache]]).
- `effects` : liste d'effets passifs (voir [[Effets d'équipement passifs]]) — vide pour les objets craftés, remplie sur le loot généré.
- Un objet sculpté par le joueur génère une entrée du même format, stockée dans la sauvegarde, avec `vox_model` pointant vers le modèle sauvegardé et `stat_weights` calculé depuis la composition voxel ([[Éditeur de sculpture]]).

**Slots du craft compositionnel ([[Composant et recette d'obtention]]) :** un objet déclare ses slots — `"slots": {"tete": "tete_pioche", "manche": "manche_court", "fixations": "fixations_std"}` avec les poids de [[Stats et qualité de l'assemblage]].

## Liens
- **Dépend de** : [[Fabrication d'outils]], [[Fonctionnalité]], [[Data-driven design]]
- **Alimente** : [[Effets d'équipement passifs]], [[Composant et recette d'obtention]], [[Éditeur de sculpture]]
- **Voir aussi** : [[Catégories de matériaux]], [[Squelette modulaire et points d'attache]], [[Localisation]], [[Sauvegarde]], [[Stats d'un objet crafté]]
