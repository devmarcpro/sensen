---
aliases: ["E.8", "Annexe E.8", "Boutique passive", "Étal"]
tags: [société, économie, technique, décidé]
domaine: société
statut: décidé
etape: 10
---

Les clients viennent tout seuls : trafic calculé par formule, stock physique, or à relever sur place.

```
Trafic client = f(population PNJ dans un rayon de 3 cellules, réputation
locale, accessibilité (route générée à proximité)). Chaque heure in-game :
N clients potentiels ; chacun tire un objet de l'étal selon
attrait = demande(type d'objet localement) / prix_relatif.
Stock : l'étal est un conteneur physique (limite = taille du meuble étal).
L'or s'accumule dans le coffre de la boutique (à relever sur place ;
consultation à distance = extension future, pas MVP).
```

**Clients à portefeuille fini ([[Économie — sources et puits]]/[[Barèmes économiques]]) :** chaque client a un stock d'or maximal selon son métier/rang, qui se recharge lentement — un client à sec propose un troc.

**Acceptation du prix ([[Prix suggéré]]) :** les PNJ acceptent d'acheter en boutique passive si `prix_affiché <= prix_suggere × random(0.9, 1.3)` — vendre trop cher ralentit les ventes sans les bloquer totalement.

**Alimente le trésor du royaume ([[Entretien et taxes]]) :** les boutiques passives du territoire alimentent le trésor, consultable dans l'écran de gestion de claim ([[Écrans d'interface]]).

**Abstraction hors-site ([[Abstraction hors-site]]) :** `ventes boutique = débit_client(trafic local) × attractivité_prix` — résolution par formules, jamais de simulation.

**Résolution pendant une nuit sautée ([[Cycle jour-nuit et sommeil]]) :** les boutiques hors-site vendent pendant la durée sautée.

## Liens
- **Dépend de** : [[Commerce et boutiques]], [[Prix suggéré]], [[Meubles]]
- **Alimente** : [[Économie — sources et puits]], [[Entretien et taxes]], [[Abstraction hors-site]]
- **Voir aussi** : [[Barèmes économiques]], [[Réputation et relations]], [[LOD de simulation]], [[Simulation du monde — performance]], [[Cycle jour-nuit et sommeil]]
