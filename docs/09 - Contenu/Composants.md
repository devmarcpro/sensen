---
aliases: ["F.11", "Annexe F.11", "Composants", "14 composants", "Composants standard"]
tags: [contenu, craft, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 6
---

Les 14 composants standard du craft compositionnel — peu de types, beaucoup de matériaux.

*Peu de types, beaucoup de matériaux : chaque composant accepte plusieurs familles de matériaux via ses recettes ([[Composant et recette d'obtention]]).*

**Manches (3) :** Manche court (pioche, hache, marteau, masse, dague) · Manche long (lance, hallebarde, faux) · Poignée (épées, couteaux)

**Têtes et lames (5) :** Tête d'outil (pioche/hache/marteau — la forme finale vient de la fonctionnalité choisie, [[Fonctionnalité]]) · Lame courte (dague, couteau) · Lame longue (épées) · Tête d'arme lourde (masse, marteau de guerre) · Pointe (lance, flèches, trident)

**Armure (3) :** Plaque (torse, jambières, casque) · Sangles (attaches de toute pièce) · Rembourrage (confort — module le malus de poids)

**Fixations (1) :** Fixations standard (rivets/ligatures/colle — slot générique de toutes les recettes)

**Divers (2) :** Garde (épées — protège la main, petit bonus de parade) · Contrepoids (armes lourdes — module la vitesse)

**Note d'équilibrage :** chaque élément porte les 13 stats standard ([[Schéma matériau]]). Les stats des éléments doivent être cohérentes avec les matériaux qui les contiennent — vérification recommandée : recomposer un matériau connu depuis ses éléments doit redonner approximativement ses stats du catalogue [[Catalogue matériaux — Bois]] et suivants (**tolérance ±15 %**). C'est le test d'intégrité du système.

> *(Cette note d'équilibrage est un vestige de la chimie élémentaire supprimée le 2026-08-09 — voir [[Craft compositionnel]] et [[Décisions fondatrices]]. Conservée intégralement.)*

**Poids de slots ([[Stats et qualité de l'assemblage]]) :** arme/outil — tête 0.7, manche 0.25, fixations 0.05 · armure — plaque 0.75, sangles 0.2, fixations 0.05.

**Munitions compositionnelles ([[Équipement — 14 slots]]) :** le carquois contient des munitions faites de **pointe + hampe**.

**Véhicules ([[Véhicules]]) :** coque + roues + mât — le même modèle compositionnel.

**Contenu à produire :** [[Ouvert — Recettes de composants par famille]].

> [!success] Codé (vérifié le 2026-08-28)
> Les 14 composants sont dans `data/components/`.

## Liens
- **Dépend de** : [[Craft compositionnel]], [[Composant et recette d'obtention]], [[Stats et qualité de l'assemblage]]
- **Alimente** : [[Armure par zone et constructions]], [[Équipement — 14 slots]], [[Stations de transformation]], [[Véhicules]]
- **Voir aussi** : [[Fonctionnalité]], [[Schéma matériau]], [[Catégories de matériaux]], [[Ouvert — Recettes de composants par famille]], [[Décisions fondatrices]]
