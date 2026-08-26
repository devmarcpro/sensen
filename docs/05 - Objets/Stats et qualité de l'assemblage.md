---
aliases: ["A.4.7", "Annexe A.4.7", "Poids de slot", "Jet d'assemblage", "Assemblage"]
tags: [objets, craft, formule, décidé]
domaine: objets
statut: décidé
etape: 6
---

Les formules du craft compositionnel : poids de slots, jet d'assemblage, alignement Wu Xing composite.

```
STATS DE L'OBJET ASSEMBLÉ :
  stat_finale(s) = Σ (stat_composant_i(s) * poids_slot_i)
  poids par défaut : arme/outil : tête 0.7, manche 0.25, fixations 0.05
                     armure     : plaque 0.75, sangles 0.2, fixations 0.05
  stat_composant = stat du matériau du composant (13 stats, A.4.5),
    la dureté de la tête pilote les dégâts (A.4.1), la densité du
    manche pilote la vitesse — les rôles deviennent physiquement
    lisibles.

QUALITÉ :
  qualite_composant : tirée à la fabrication du composant (A.3, sur
    la compétence de sa station : Forge pour une tête, Menuiserie/
    Scierie pour un manche...)
  qualite_objet = (Σ qualite_composant_i * poids_slot_i)
                  * jet_assemblage
  jet_assemblage = tirage A.3 sur la compétence de la table
    d'assemblage, borné [0.7, 1.3] — l'assembleur peut sublimer ou
    gâcher, jamais annuler le travail des composants.

ALIGNEMENT WU XING COMPOSITE (5.2/A.4.6) :
  l'objet porte chaque élément au prorata des poids de slots de ses
  composants ; le multiplicateur de domination utilise l'élément
  majoritaire, les combos d'engendrement acceptent tout élément
  porté à >= 25 %.

RECETTES EXOTIQUES : aucune différence de formule — un manche en or
  suit les mêmes maths (densité 19 → arme très lente, CMa 65 →
  coûts de mana réduits). L'exotisme est dans l'ACCÈS (B.13), jamais
  dans un bonus caché : les matériaux parlent d'eux-mêmes.
```

**Conséquence pour l'élément d'une arme ([[Domination et multiplicateurs]]) :** *l'élément d'une arme est celui de sa TÊTE — les poids de slots A.4.7 garantissent qu'elle domine* (0.7 contre 0.25 et 0.05).

**Vecteur défensif du personnage ([[Wu Xing — cycles et vecteurs]]) :** l'alignement d'un personnage équipé est le **vecteur composite de ses composants**.

## Liens
- **Dépend de** : [[Craft compositionnel]], [[Qualité d'artisanat]], [[Application des stats de matériau]], [[Composant et recette d'obtention]]
- **Alimente** : [[Stats d'armes]], [[Armure par zone et constructions]], [[Domination et multiplicateurs]], [[Armes fantomatiques]]
- **Voir aussi** : [[Composants]], [[Stations de transformation]], [[Stats d'un objet crafté]], [[Palier industriel]]
