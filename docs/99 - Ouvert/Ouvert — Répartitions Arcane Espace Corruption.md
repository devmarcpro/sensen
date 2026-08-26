---
aliases: ["Ouvert — Répartitions Arcane Espace Corruption", "Arcane Espace Corruption"]
tags: [ouvert, combat, wuxing, décidé-par-défaut]
domaine: combat
statut: décidé-par-défaut
etape: 0
---

> [!success] Défaut fixé le 2026-08-26 — implémentable tel quel
> Sur délégation du designer : **le code part de cette valeur**, aucune question à se poser. La question reste légitimement ouverte au playtest — la réviser est une décision de tuning, pas de conception.

**La question :** quelles sont les répartitions élémentaires exactes des trois domaines « hors cycle » — Arcane, Espace, Corruption ?

**Valeurs par défaut posées ([[Domination et multiplicateurs]], explicitement notées « défauts à équilibrer ») :**
- **Arcane** : `{0.2 partout}` — quasi neutre PAR CONSTRUCTION, sans règle d'exception
- **Espace** : `{eau: 0.6, metal: 0.4}`
- **Corruption** : `{terre: 0.5, feu: 0.5}`

**L'enjeu :** ces vecteurs déterminent les multiplicateurs de domination de ces domaines, leur contribution à la [[Jauge de chaîne Wu Xing]] (quel segment ils posent, quelles transitions ils permettent), et donc la viabilité des builds Arcane/Espace/Corruption dans le système central.

**Ce qui en dépend :** l'équilibre des 9 domaines de grimoires ([[Domaines de grimoires et manuels]]), les modules concernés ([[Modules]] : 15 modules Arcane/Espace/Corruption sur 48).

**Implémentable sans :** oui — les défauts sont posés, seul le réglage reste.

## Le défaut : les vecteurs de A.4.6 sont retenus tels quels

**Arcane `{0.2 partout}` · Espace `{eau: 0.6, metal: 0.4}` · Corruption `{terre: 0.5, feu: 0.5}`** — implémentables sans changement.

**Ce que ça donne, vérifié :** Arcane est quasi neutre par construction (aucun matchup fort, aucun faible — le domaine du joueur qui refuse le système élémentaire, et qui le paie en multiplicateurs plats). Espace et Corruption sont des mixtes à deux composantes : ils bénéficient du choix de segment ([[Ouvert — Compensation de l'arme mixte]]) et amortissent les mauvais matchups, sans jamais atteindre le ×1.5 d'un domaine pur. **C'est cohérent** : ces trois domaines achètent de l'utilité (téléport, portée, drain) contre de la puissance élémentaire.

## Liens
- **Dépend de** : [[Domination et multiplicateurs]], [[Wu Xing — cycles et vecteurs]]
- **Alimente** : [[Domaines de grimoires et manuels]], [[Jauge de chaîne Wu Xing]], [[Modules]]
- **Voir aussi** : [[Modificateurs d'affinité]], [[Décisions fondatrices]]
