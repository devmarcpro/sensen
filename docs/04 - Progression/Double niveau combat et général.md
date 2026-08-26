---
aliases: ["6.0", "6.0 Double niveau", "Niveau de combat", "Niveau général", "Niveaux dérivés"]
tags: [progression, décidé]
domaine: progression
statut: décidé
etape: 4
---

Le « niveau » d'un personnage n'est pas une jauge qu'on remplit : ce sont deux agrégats calculés depuis les compétences.

Le "niveau" d'un personnage (joueur comme PNJ — même système, [[Schéma unifié créature-PNJ]]) est **divisé en deux valeurs dérivées** :

- **Niveau de combat** : moyenne de toutes les compétences liées au **combat et à la survie** (armes, dual wielding/bouclier/deux mains, magie offensive/défensive, discrétion, athlétisme...).
- **Niveau général** : moyenne de toutes les autres compétences (artisanat, récolte, lecture, négociation, agriculture...).

Aucun des deux n'est une jauge qu'on remplit directement : ce sont des **agrégats calculés** depuis les compétences, qui elles seules progressent (à l'usage). Usages :
- Le **niveau de combat** sert au scaling des menaces : sélection de cibles des gabarits de quête ([[Gabarit de quête]]), difficulté des raids ([[Défense et raids]]), évaluation d'une créature avant de l'engager.
- Le **niveau général** sert au contenu civil : exigences de rang de guilde non-combat, évaluation d'un PNJ pour un poste de travail ([[Population et exploitation]]), etc.

**Décisions :**
- **Classification figée** (champ `category` de chaque compétence en données) : *combat/survie* = toutes les compétences d'armes, Dual Wielding, Bouclier, Deux Mains, tous les domaines de magie, Méditation, Contrôle du Mana, Esquive, Encaissement, Discrétion, Athlétisme. *Général* = tout le reste (récolte, artisanat, Lecture, Négociation, Dressage, Leadership, Agriculture, Élevage, Navigation).
- **Agrégat : résolu ([[Progression par l'usage]])** — moyenne des **5 meilleures** compétences de chaque catégorie (anti-dilution).

**Formule (A.1) :**
```
niveau_combat  = moyenne des 5 meilleures compétences taguées "combat/survie"
niveau_general = moyenne des 5 meilleures compétences taguées "general"
```
Le tag combat/general est un champ de la définition de chaque compétence (data-driven). "5 meilleures" évite la dilution quand un personnage touche à tout.

**Note ([[Effets d'équipement passifs]]) :** les niveaux **effectifs** apportés par l'équipement comptent dans `skill_factor()` et dans toutes les formules, **mais n'entrent PAS dans les niveaux dérivés**.

**Succession ([[Conquête de village]]) :** `succession_rule = "next_in_rank"` sélectionne le PNJ de plus haut **niveau général** de la faction.

## Liens
- **Dépend de** : [[Progression par l'usage]], [[Compétences — liste]]
- **Alimente** : [[Gabarit de quête]], [[Défense et raids]], [[Population et exploitation]], [[Conquête de village]]
- **Voir aussi** : [[Effets d'équipement passifs]], [[Schéma unifié créature-PNJ]], [[Quêtes et guildes]], [[EventBus]]
