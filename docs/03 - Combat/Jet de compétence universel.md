---
aliases: ["Jet de compétence universel", "Jet universel", "E.3 jet universel"]
tags: [combat, formule, décidé]
domaine: combat
statut: décidé
etape: 0
---

Une seule grammaire de résolution pour tout ce qui n'est pas un coup d'arme : lecture, dressage, négociation, discrétion, conquête.

**Jet de compétence universel (hors combat)** — remplace les formules ad hoc :

```
1d20 + N_competence/2 + stat_associée/4  vs  DD (difficulté fixe)
Degrés : réussite de 10+ = succès supérieur ; échec de 10+ (ou 1 naturel)
= échec grave (table d'effets aggravés).
S'applique à : lecture (A.7 révisé), dressage/capture, négociation,
vol/discrétion, désamorçage, etc. UNE grammaire pour tout le jeu.
```

**Applications explicitement chiffrées ailleurs :**
- **Lecture d'un livre** ([[Lecture des livres]]) : `1d20 + N_lecture/2 + Perception/4 vs DD = 10 + difficulte_livre/2`
- **Apprivoisement** ([[Apprivoisement et recrutement]]) : `1d20 + Dressage/2 + Charisme/4 vs DD = 10 + niveau_combat_cible/2`, cible affaiblie = bonus
- **Conquête d'un village** ([[Conquête de village]]) : `1d20 + Leadership/2 + Charisme/4 vs DD = population du village × 2`
- **Détection d'infraction** ([[Lois et infractions]]) : jet opposé Discrétion du joueur vs Perception du PNJ témoin le plus proche
- **Détection par les créatures** ([[IA des créatures]]) : jet opposé quand ça compte

**Les jets de dés survivent hors combat ([[Combat tactique sur grille]]) :** le jet de compétence universel reste la résolution de la lecture, du dressage, de la négociation, de la discrétion, de la capture — alors même que le **jet de toucher** a disparu du combat.

> [!success] Constaté codé le 2026-08-31 — la grammaire vit, la note n'avait pas de callout
> Le jet universel est bien la résolution hors combat, vérifié site par site : **conquête** (`1d20 + Leadership/2 + Charisme/4`), **dressage** (`1d20 + Dressage/2 + Charisme/4`), **détection d'infraction** (jet opposé Perception/2 du témoin contre Discrétion du joueur — le +4 de nuit vient du cycle), **négociation** (`1d20 + Charisme/4` contre `commerce.parler_charisme_dd`), bras de fer du courant (`Force/2` opposé). La **capture d'élevage** emploie sa compétence à taux plein + palier — c'est le callout de sa propre note qui l'emporte, comme la règle du coffre le veut. Les degrés (succès supérieur à +10, échec grave à −10) restent à brancher là où une table d'effets aggravés existera.

## Liens
- **Dépend de** : [[Pipeline de résolution du combat]], [[Progression par l'usage]], [[Stats de personnage]]
- **Alimente** : [[Lecture des livres]], [[Apprivoisement et recrutement]], [[Conquête de village]], [[Lois et infractions]], [[IA des créatures]]
- **Voir aussi** : [[Combat tactique sur grille]], [[Compétences — liste]]
