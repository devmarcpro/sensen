---
aliases: ["B.7", "Annexe B.7", "Gabarit de quête", "quest_templates"]
tags: [société, données, schéma, décidé]
domaine: société
statut: décidé
etape: 9
---

Le format d'un gabarit de quête procédurale, avec son sélecteur de cible et son texte localisé à placeholders.

`data/quest_templates/*.json` :

```json
{
  "id": "chasse_prime",
  "guild": "guerriers",
  "rank_min": 1,
  "pattern": "tuer",
  "target_selector": { "tags_any": ["hostile"], "combat_level_range_around_player": [0.8, 1.2] },
  "count_range": [3, 8],
  "reward": { "gold_per_target_level": 15, "guild_xp": 10 },
  "text_key": "quest.chasse_prime.text"
}
```

- `text_key` pointe vers un gabarit localisé avec placeholders (ex : fr = "Éliminez {count} {target} près de {location}.") — une version par langue dans `locale/` (voir [[Localisation]]). Les valeurs `{target}`/`{location}` sont elles-mêmes résolues via les `name_key` des entités concernées.
- **Pattern `"donjon"`** ([[Quêtes et guildes]]/[[Donjons — structure et intégration]]) : `target_selector` référence un donjon POI généré à proximité plutôt qu'un type de créature — objectif "atteindre l'étage le plus profond" ou "vaincre le boss" (`dungeon_cleared` sur l'EventBus valide la quête automatiquement).

**Sélection de cible par niveau de combat ([[Double niveau combat et général]]) :** `combat_level_range_around_player` — le niveau de combat sert au scaling des menaces de quête.

**Écoute d'événements ([[EventBus]]) :** le système de quêtes écoute `creature_killed`, `item_crafted`, `block_placed/destroyed`, `dungeon_cleared` sans que ces systèmes connaissent les quêtes.

## Liens
- **Dépend de** : [[Quêtes et guildes]], [[Data-driven design]], [[Double niveau combat et général]]
- **Alimente** : [[Donjons — structure et intégration]], [[Économie — sources et puits]]
- **Voir aussi** : [[Localisation]], [[EventBus]], [[Créatures]], [[Génération de donjon]], [[Génération de noms]]
