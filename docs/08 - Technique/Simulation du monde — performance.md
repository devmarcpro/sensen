---
aliases: ["G.6", "Annexe G.6", "Simulation du monde performance", "Timer wheel"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 8
---

La timer wheel : 10 000 cultures plantées coûtent zéro entre deux échéances.

```
Liquides : file active uniquement (E.22) — un lac stable coûte 0.
Cultures/faim PNJ/timers : PAS de per-tick — chaque instance stocke
  son échéance en ticks et s'enregistre dans une TIMER WHEEL globale
  (le tick ne visite que ce qui échoit ce tick). 10 000 cultures
  plantées = coût nul entre deux échéances.
Corruption (E.20), régénération (3.3), raids (E.7) : passages
  hebdomadaires sur listes filtrées (cellules à delta/foyer) — déjà
  bon marché par conception.
Boutiques/abstraction (E.6/E.8) : résolution par formules à
  l'échéance ou au retour du joueur — jamais de simulation de fond.
Détection de pièces (E.5) : throttlée (1 revalidation/s max par claim),
  flood fill borné, en thread.
```

**Autres usages de la timer wheel :** disparition d'un donjon nettoyé (1,5 jour, [[Génération de donjon]]), délai de transition de succession ([[Conquête de village]], [[Familles et succession]]), mort de vieillesse ([[Âge des PNJ]]).

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Simulation à ticks]]
- **Alimente** : [[Eau et liquides]], [[Agriculture et élevage]], [[Faim des PNJ]], [[Dérive de la corruption]], [[Détection de pièces]], [[Génération de donjon]]
- **Voir aussi** : [[Claims et persistance]], [[Raids et menaces]], [[Abstraction hors-site]], [[Boutique passive]], [[Conquête de village]], [[Âge des PNJ]], [[Budgets de performance]]
