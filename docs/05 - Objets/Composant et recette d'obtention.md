---
aliases: ["B.13", "Annexe B.13", "Composant", "Recette d'obtention", "data/components"]
tags: [objets, craft, données, schéma, décidé]
domaine: objets
statut: décidé
etape: 6
---

Le schéma de données du craft compositionnel : un composant logique, et une recette d'obtention par famille de matériaux.

`data/components/*.json` :

```json
{
  "id": "tete_pioche",
  "name_key": "component.tete_pioche.name",
  "slot_type": "tete",
  "used_by": ["pioche", "pioche_combat"]
}
```

`data/component_recipes/*.json` — recette de base (connue d'office) :

```json
{
  "id": "tete_pioche_metal",
  "component": "tete_pioche",
  "material_family": "lingot_metal",
  "station": "enclume",
  "unlocked_by_default": true
}
```

Recette exotique (à apprendre) :

```json
{
  "id": "tete_pioche_obsidienne",
  "component": "tete_pioche",
  "material_family": "obsidienne",
  "station": "tailleur_de_pierre",
  "unlocked_by_default": false,
  "unlock_sources": ["loot_donjon", "guilde_forgerons_rang_3"]
}
```

- Un objet ([[Schéma objet et recette]]) déclare ses **slots** : `"slots": {"tete": "tete_pioche", "manche": "manche_court", "fixations": "fixations_std"}` avec les poids de [[Stats et qualité de l'assemblage]].
- `material_family` : catégorie de matériau acceptée ([[Schéma matériau]]) — le joueur choisit librement le matériau *dans* la famille ; une famille exotique = une recette distincte à débloquer.
- `unlock_sources` : où la recette se trouve (parchemins en donjon, marchands, rangs de guilde) — même logique d'acquisition que les grimoires ([[Grimoires et manuels]]).
- L'UI de navigation ([[Craft compositionnel]]) ne fait que parcourir cet arbre : objet → slots → recettes connues (dépliables récursivement) / inconnues (silhouette).

**Palier industriel ([[Palier industriel]]) :** les recettes industrielles sont *des entrées de plus en B.13*, avec des `unlock_sources` exigeantes et des stations améliorées.

**Contenu à produire :** [[Ouvert — Recettes de composants par famille]] — recettes d'obtention par composant × famille et leurs sources exotiques.

## Liens
- **Dépend de** : [[Craft compositionnel]], [[Composants]], [[Data-driven design]]
- **Alimente** : [[Schéma objet et recette]], [[Stats et qualité de l'assemblage]], [[Palier industriel]], [[Armure par zone et constructions]]
- **Voir aussi** : [[Catégories de matériaux]], [[Grimoires et manuels]], [[Quêtes et guildes]], [[Localisation]], [[Ouvert — Recettes de composants par famille]]
