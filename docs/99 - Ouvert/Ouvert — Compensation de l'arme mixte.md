---
aliases: ["Ouvert — Compensation de l'arme mixte", "Arme mixte"]
tags: [ouvert, combat, wuxing, décidé-par-défaut]
domaine: combat
statut: décidé-par-défaut
etape: 0
---

> [!success] Défaut fixé le 2026-08-26 — implémentable tel quel
> Sur délégation du designer : **le code part de cette valeur**, aucune question à se poser. La question reste légitimement ouverte au playtest — la réviser est une décision de tuning, pas de conception.

**La question :** qu'est-ce qui compense réellement une **arme mixte** face à une arme pure, au-delà de l'amortissement des matchups et de la purification par gemmes ?

**Le problème posé ([[Domination et multiplicateurs]]) :** une arme mixte exige d'investir dans **deux** niveaux d'élément pour égaler une arme pure — `Σ_e [proportion_e × (1 + niveau_élément_e / 100)]`. En échange, son vecteur amortit les mauvais matchups. Mais l'arme pure pose un **segment net** dans la [[Jauge de chaîne Wu Xing]] et prend les multiplicateurs pleins.

**Ce qui existe déjà comme compensation :**
- amortissement des mauvais matchups (multiplicateurs adoucis dans les deux sens)
- purification par gemmes taillées en affinité ([[Modificateurs d'affinité]] : *l'artisanat devient la voie de purification que les armes mixtes cherchaient*)
- les combos d'engendrement acceptent tout élément porté à ≥ 25 % ([[Stats et qualité de l'assemblage]])

**Ce qui en dépend :** la viabilité de tout un pan du [[Craft compositionnel]] — si le mono-élément domine toujours, le choix des matériaux de composants se réduit à « tout dans la même famille ».

**Implémentable sans :** oui.

## Le défaut : deux compensations chiffrées

1. **Seuil de combo abaissé** ([[Stats et qualité de l'assemblage]] pose déjà le principe : *les combos d'engendrement acceptent tout élément porté à ≥ 25 %*). Conséquence directe et suffisante : **une arme mixte peut poser le segment de l'un OU l'autre de ses éléments**, au choix du joueur à chaque coup — c'est l'avantage tactique du mixte : il s'adapte à la chaîne en cours sans payer les 4 ticks de swap ([[Jauge de chaîne Wu Xing]]).
2. **Amortissement défensif** déjà acquis : sur un mauvais matchup, un vecteur mixte encaisse la moyenne pondérée au lieu du plein ([[Domination et multiplicateurs]]).

**Le test au playtest** ([[Prototype de combat — spécification]]) : une arme mixte bien jouée doit rester **à ±15 %** d'une arme pure sur une rotation complète. Si le mixte gagne, retirer le choix du segment ; s'il perd, autoriser le mixte à compter pour **deux transitions** dans une rotation.

## Liens
- **Dépend de** : [[Domination et multiplicateurs]], [[Craft compositionnel]], [[Stats et qualité de l'assemblage]]
- **Alimente** : [[Jauge de chaîne Wu Xing]], [[Modificateurs d'affinité]]
- **Voir aussi** : [[Armes fantomatiques]], [[Palier industriel]], [[Décisions fondatrices]]
