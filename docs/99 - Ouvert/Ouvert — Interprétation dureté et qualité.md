---
aliases: ["Ouvert — Interprétation dureté et qualité", "Interprétation dureté/qualité"]
tags: [ouvert, objets, craft, décidé-par-défaut]
domaine: objets
statut: décidé-par-défaut
etape: 6
---

> [!success] Défaut fixé le 2026-08-26 — implémentable tel quel
> Sur délégation du designer : **le code part de cette valeur**, aucune question à se poser. La question reste légitimement ouverte au playtest — la réviser est une décision de tuning, pas de conception.

**La question, telle que posée en 4.2 ([[Qualité d'artisanat]]) :** *« Interprétation à confirmer : la dureté de base d'un outil crafté vient des stats fixes des matériaux utilisés ; la qualité vient ensuite multiplier ces stats de base pour obtenir les stats finales de l'objet. »*

**Ce qui a été tranché depuis (décision de 4.2) :** *Formule dureté/qualité : **résolu** ([[Stats d'un objet crafté]]/[[Stats d'armes]]) — dureté de base = moyenne pondérée des matériaux, **qualité appliquée une seule fois**.*

L'interprétation est donc **confirmée**, avec un garde-fou explicite ([[Stats d'armes]]) :

> `durete_BASE` = moyenne pondérée des matériaux **AVANT** qualité. La qualité n'est appliquée qu'**UNE** fois ; ne jamais utiliser la dureté finale déjà multipliée, **ce serait un double comptage**.

**Nuance importante ([[Application des stats de matériau]]) :** la qualité **ne multiplie PAS** les 13 stats de matériau — *ce sont des propriétés physiques, pas des performances*. Seule la **dureté → dégâts/protection** passe par la qualité.

**Traitement appliqué le 2026-08-26 :** la mention « à confirmer » a été **retirée** de [[Qualité d'artisanat]] et remplacée par la règle confirmée, avec le garde-fou anti-double-comptage. Cette note ne subsiste que comme trace de la question d'origine.

## Statut : clos

La formulation « à confirmer » du GDD est **levée** dans [[Qualité d'artisanat]] : la dureté de base vient des matériaux, la qualité multiplie **une seule fois** ([[Stats d'un objet crafté]], garde-fou anti-double-comptage en [[Stats d'armes]]). Aucune ambiguïté ne subsiste dans le coffre.

## Liens
- **Dépend de** : [[Qualité d'artisanat]], [[Stats d'un objet crafté]]
- **Alimente** : [[Stats d'armes]], [[Armures et poids porté]], [[Stats et qualité de l'assemblage]]
- **Voir aussi** : [[Application des stats de matériau]], [[Matériaux — 13 stats]]
