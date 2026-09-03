---
aliases: ["A.8.1", "Annexe A.8.1", "Barèmes économiques", "Taxes de guilde", "Entretien du royaume"]
tags: [société, économie, formule, décidé]
domaine: société
statut: décidé
etape: 10
---

Les chiffres de l'économie : portefeuilles PNJ, taxes de guilde, entretien du royaume.

```
PORTEFEUILLE PNJ (marchands ET clients, règle unifiée) :
  or_max = base(métier) * (1 + rang*0.5)
    base : villageois/client 30, marchand 300, maître de guilde 2000,
    roi 15000 — indexé sur la FONCTION du PNJ (Fonctions), pas sur
    son espèce (Profils de PNJ)
  recharge hebdomadaire : +15 % de or_max (plafonné à or_max)
  Vente du joueur refusée en or au-delà du stock du PNJ → PROPOSITION
    DE TROC automatique : objets de son inventaire ≈ valeur équivalente
    (±15 %), le joueur accepte ou refuse.

TAXES DE GUILDE (hebdomadaire, prélevée automatiquement, DÉTRUITE) :
  taxe = 0.05 * gains_de_quetes_de_la_semaine * rang_guilde_du_joueur
  (rang 1 = x1, rang 5 = x1.4 — les hauts rangs coûtent plus cher
  mais rapportent plus, cf. 7.3)

ENTRETIEN DU ROYAUME (hebdomadaire, prélevé sur le trésor du royaume,
  taux `base_rate` défini par royaume — B.9 — module selon la
  gouvernance : dictature/ploutocratie plus haut, anarchie proche 0
  car pas d'administration à financer) :
  entretien = Σ(10 or / PNJ assigné) + Σ(25 or / structure spéciale
              : station, tourelle, hall de guilde)
  Payé automatiquement si trésor suffisant. Sinon : dette d'entretien
    += manquant ; malus progressifs par palier de dette (14.6) —
    jamais de destruction automatique de structures.
  Trésor du royaume alimenté par les boutiques passives (E.8) du
    territoire, consultable dans l'écran de gestion de claim (E.13).
```

**Coût naturel du cumul de guildes ([[Quêtes et guildes]]) :** *les taxes hebdomadaires par guilde sont le coût naturel du cumul* — toutes les guildes sont cumulables au lancement.

**Paliers de dette :** voir [[Entretien et taxes]].

> [!success] Codé à l'étape 10 — trace ajoutée le 2026-09-04
> Les barèmes sont dans `combat_rules.royaume` (`claim_cout_par_cellule`, `entretien_pnj`, `entretien_structure`, `dette_paliers`), `combat_rules.commerce` et `combat_rules.guildes` ; aucun chiffre n'est dans le code.

## Liens
- **Dépend de** : [[Économie — sources et puits]], [[Prix suggéré]], [[Schéma royaume]]
- **Alimente** : [[Entretien et taxes]], [[Quêtes et guildes]], [[Boutique passive]]
- **Voir aussi** : [[Créatures]], [[Gouvernance, lois et diplomatie]], [[Écrans d'interface]], [[Population et exploitation]]
