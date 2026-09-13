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
    base : le `portefeuille` de la FICHE DE FONCTION (data/functions/),
    pas l'espèce (Profils de PNJ). Au 2026-09-13 : journalier et
    portefaix 12, villageois/fermier/mineur/aventurier 30, artisan et
    garde 60, marchand et maire 300, commandant 400, prêtre 500,
    syndic 600, seigneur 800, maître de guilde et dirigeant 2000
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

> [!note] Le roi à 15 000 n'a jamais existé en données — corrigé le 2026-09-13 (le coffre qui se contredit, ordre de travail 47)
> Cette note annonçait un **roi à 15 000** ; la fiche du dirigeant porte **2 000** depuis qu'elle existe, à égalité avec le maître de guilde. La note est réécrite sur la donnée plutôt que l'inverse : aucun test ni aucune boucle économique ne s'est jamais appuyé sur 15 000, et le trésor d'un royaume vit dans le royaume, pas dans la bourse de son dirigeant. *Si le designer veut un roi plus riche, c'est un nombre dans `functions/dirigeant.json`.*

**Coût naturel du cumul de guildes ([[Quêtes et guildes]]) :** *les taxes hebdomadaires par guilde sont le coût naturel du cumul* — toutes les guildes sont cumulables au lancement.

**Paliers de dette :** voir [[Entretien et taxes]].

> [!success] Codé à l'étape 10 — trace ajoutée le 2026-09-04
> Les barèmes sont dans `combat_rules.royaume` (`claim_cout_par_cellule`, `entretien_pnj`, `entretien_structure`, `dette_paliers`), `combat_rules.commerce` et `combat_rules.guildes` ; aucun chiffre n'est dans le code.

## Liens
- **Dépend de** : [[Économie — sources et puits]], [[Prix suggéré]], [[Schéma royaume]]
- **Alimente** : [[Entretien et taxes]], [[Quêtes et guildes]], [[Boutique passive]]
- **Voir aussi** : [[Créatures]], [[Gouvernance, lois et diplomatie]], [[Écrans d'interface]], [[Population et exploitation]]
