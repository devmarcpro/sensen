---
aliases: ["E.4", "Annexe E.4", "Résolveur de modificateurs", "Stats.get", "StatModifiers"]
tags: [technique, architecture, décidé]
domaine: technique
statut: décidé
etape: 0
---

Une seule fonction pour toute valeur de jeu interrogeable — aucun système ne modifie jamais une valeur en dur.

Toute valeur de jeu interrogeable passe par un résolveur unique :

`Stats.get(entity, "id")` = `(base + Σ add) × Π mult`

où les sources de modificateurs sont : équipement ([[Effets d'équipement passifs]]), statuts actifs ([[Statuts]]), bonus de race ([[Races]]), auras/buffs de modules ([[Modules]]), humeur (PNJ — [[Habitat des PNJ]]). Chaque source est enregistrée/retirée dynamiquement — **aucun système ne modifie jamais une valeur en dur**.

**Règles de combinaison ([[Effets d'équipement passifs]]) :** les `add` s'additionnent, les `mult` se multiplient entre tous les objets portés ; la qualité de l'objet multiplie les valeurs numériques.

**Potions ([[Nourriture, potentiel et potions]]) :** les potions passent par les statuts et le résolveur de modificateurs — **zéro système nouveau**.

**Affixes ([[Loot — affixes, gemmes et rareté]]) :** implémentés en StatModifiers avec la source `affixe:<uid>`.

> [!success] Codé — trace ajoutée le 2026-09-04
> `Etres.recalculer()` : `stats_eff = (base + Σ add) × Π mult`, en lisant les affixes passifs équipés et les statuts (`add_statuts`, `mult_statuts`) ; la suite vérifie qu'un affixe +3 Force change l'effective et pas la base.

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Data-driven design]]
- **Alimente** : [[Effets d'équipement passifs]], [[Statuts]], [[Nourriture, potentiel et potions]], [[Loot — affixes, gemmes et rareté]]
- **Voir aussi** : [[Races]], [[Habitat des PNJ]], [[Modules]], [[EventBus]], [[Statuts de contrôle et anti-stunlock]]
