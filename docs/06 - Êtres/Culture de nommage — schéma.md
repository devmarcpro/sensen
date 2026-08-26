---
aliases: ["B.11", "Annexe B.11", "Culture de nommage", "data/name_cultures"]
tags: [êtres, données, schéma, décidé]
domaine: êtres
statut: décidé
etape: 9
---

Le format de données d'une culture de nommage : des pools A/B, des affinités de race, et une table de titres par gouvernance.

`data/name_cultures/*.json` :

```json
{
  "id": "culture_sino",
  "name_key": "culture.sino.name",
  "name_order": "nom_prenom",
  "race_affinity": { "humain": 1.0 },
  "prenom_a": ["Li", "Wang", "Zh", "Xi", "Mei", "Jian", "Hu", "Chen"],
  "prenom_b_m": ["ang", "ong", "ing", "un"],
  "prenom_b_f": ["ei", "an", "ao", "ua"],
  "famille_a": ["Li", "Wang", "Zhang", "Chen", "Liu", "Yang", "Huang"],
  "famille_b": [""],
  "ville_a": ["Bei", "Nan", "Shang", "Hang", "Chang", "Guang"],
  "ville_b": ["jing", "hai", "zhou", "yang", "an", "sha"],
  "titres": {
    "monarchie_hereditaire": { "m": "Empereur", "f": "Impératrice" },
    "republique_elue": { "m": "Premier Ministre", "f": "Première Ministre" },
    "theocratie": { "m": "Grand Prêtre", "f": "Grande Prêtresse" },
    "ploutocratie": { "m": "Négociant en Chef", "f": "Négociante en Chef" },
    "dictature_militaire": { "m": "Généralissime", "f": "Généralissime" },
    "guilde_maitre": { "m": "Grand Maître", "f": "Grande Maîtresse" }
  }
}
```

- `prenom_a`, `prenom_b_m`, `prenom_b_f`, `famille_a`, `famille_b_m`, `famille_b_f`, `ville_a/b` : pools de la partie A et B, concaténées ([[Génération de noms]]). **Les terminaisons de prénom sont genrées, et celles de patronyme le sont là où la langue l'exige** (nordique -sson ⟋ -sdottir, slave -ov ⟋ -ova) — voir [[Pools de noms des cultures]]. La partie A est commune aux deux genres. `famille_b: [""]` (chaîne vide) = culture à noms de famille "pleins" plutôt que composés (comme le sino ci-dessus) ; la plupart des autres cultures ont un vrai suffixe.
- `race_affinity` : poids de tirage par race à la génération d'un royaume ([[Génération des royaumes PNJ]]) ; les races absentes ont un poids 0 (jamais tirées pour elles). Les 7 cultures sont toutes partageables — l'Humain a le spectre le plus large, le Nain penche vers le nordique, l'Elfe vers le celte.
- `titres` : une entrée par type de gouvernance ([[Schéma royaume]]) + `guilde_maitre` (utilisé indépendamment du royaume, pour tout maître de guilde, [[Quêtes et guildes]]) ; genré `m`/`f` selon le PNJ.

**Les pools sont écrits :** [[Pools de noms des cultures]] — les 7 cultures ([[Cultures de nommage]]).

## Liens
- **Dépend de** : [[Noms culturels]], [[Data-driven design]]
- **Alimente** : [[Génération de noms]], [[Cultures de nommage]], [[Génération des royaumes PNJ]], [[Schéma royaume]]
- **Voir aussi** : [[Races]], [[Identité visuelle chinoise]], [[Localisation]], [[Ouvert — Pools de noms des cultures]]
