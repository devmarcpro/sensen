---
aliases: ["Ouvert — Interprétation dureté et qualité", "Interprétation dureté/qualité"]
tags: [ouvert, objets, craft, à-trancher]
domaine: objets
statut: à-trancher
etape: 6
---

**La question, telle que posée en 4.2 ([[Qualité d'artisanat]]) :** *« Interprétation à confirmer : la dureté de base d'un outil crafté vient des stats fixes des matériaux utilisés ; la qualité vient ensuite multiplier ces stats de base pour obtenir les stats finales de l'objet. »*

**Ce qui a été tranché depuis (décision de 4.2) :** *Formule dureté/qualité : **résolu** ([[Stats d'un objet crafté]]/[[Stats d'armes]]) — dureté de base = moyenne pondérée des matériaux, **qualité appliquée une seule fois**.*

L'interprétation est donc **confirmée**, avec un garde-fou explicite ([[Stats d'armes]]) :

> `durete_BASE` = moyenne pondérée des matériaux **AVANT** qualité. La qualité n'est appliquée qu'**UNE** fois ; ne jamais utiliser la dureté finale déjà multipliée, **ce serait un double comptage**.

**Nuance importante ([[Application des stats de matériau]]) :** la qualité **ne multiplie PAS** les 13 stats de matériau — *ce sont des propriétés physiques, pas des performances*. Seule la **dureté → dégâts/protection** passe par la qualité.

**Cette note subsiste** parce que la formulation « à confirmer » figure toujours dans le corps de la section 4.2 du GDD, en tension avec la décision qui la suit. À trancher formellement : supprimer la mention, ou documenter l'exception.

## Liens
- **Dépend de** : [[Qualité d'artisanat]], [[Stats d'un objet crafté]]
- **Alimente** : [[Stats d'armes]], [[Armures et poids porté]], [[Stats et qualité de l'assemblage]]
- **Voir aussi** : [[Application des stats de matériau]], [[Matériaux — 13 stats]]
