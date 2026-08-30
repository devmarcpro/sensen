---
aliases: ["Modificateurs d'affinité", "Affinité", "Purification", "Transmutation"]
tags: [combat, wuxing, formule, décidé]
domaine: combat
statut: décidé
etape: 3
---

Quatre opérations sur le vecteur élémentaire, résolues dans un ordre strict puis normalisées. Ces effets déplacent l'identité, ils n'ajoutent pas des chiffres.

**MODIFICATEURS D'AFFINITÉ** (affixes, anneaux, buffs, gemmes taillées en affinité) — quatre opérations sur le vecteur :

```
  AJOUT         « +X % de [élément] »
  AMPLIFICATION « part de [élément] ×N » (sans effet si absent)
  PURIFICATION  « +X % au dominant, −X % réparti » → vers le mono
  TRANSMUTATION « remplace [X] par [Y] »
  ORDRE : base → amplifications → ajouts → transmutations →
          purifications → NORMALISATION à somme 1.
  La normalisation garantit qu'un ajout DILUE toujours les autres :
  il n'est jamais gratuit. Un ajout suffisant fait BASCULER la
  dominante — donc le segment, les matchups et la piste d'XP.
  Ces effets déplacent l'IDENTITÉ, ils n'ajoutent pas des chiffres.
```

**Reformulation de [[Wu Xing — cycles et vecteurs]] :** quatre opérations sur le vecteur — **ajout**, **amplification**, **purification** (pousse vers le mono-élément — la voie qui rend une arme mixte tranchante), **transmutation** (« remplace X par Y »). Résolution ordonnée puis **normalisation à 1** : un ajout dilue toujours les autres parts, il n'est jamais gratuit. Un ajout suffisant fait **basculer la dominante**, donc le segment de chaîne, les matchups et la piste d'XP.

**La seule voie d'atelier vers l'identité élémentaire ([[Loot — affixes, gemmes et rareté]]) — la taille en affinité :**
```
  TROISIÈME OPTION — TAILLE EN AFFINITÉ : aucun nombre, mais AJOUT
    au vecteur (A.4.6) selon la qualité : misérable +0.04 →
    mythique +0.28. Seule voie par laquelle l'atelier touche à
    l'identité élémentaire, et elle est EXCLUSIVE.
    → PURIFIER : sertir son élément déjà dominant concentre le
      vecteur (l'artisanat devient la voie de purification que les
      armes mixtes cherchaient).
    → BASCULER : sertir massivement un autre élément peut renverser
      la dominante d'une arme MIXTE. Sur une arme PURE, jamais :
      la pureté reste une propriété du craft, pas quelque chose
      qu'on achète.
```

**Anneaux de transmutation :** l'un des [[Cinq accès au cycle]] — *le cycle complet lui-même : fermer un élément interdit la rotation mais rend la concentration naturelle*.

**Affixes Wu Xing associés ([[Loot — affixes, gemmes et rareté]]) :** « les coups touchés avancent l'élément dans le cycle » · « +[20-40] % [élément] au vecteur » · « +1 segment de chaîne » (rare) · « les combos donnent +2 dés au lieu de +1 » (très rare).

> [!success] Codé le 2026-08-29 — les quatre opérations, dans l'ordre de la note
> Deux des quatre existaient (**ajout**, **purification**, portées par des affixes d'arme) ; **amplification** et **transmutation** manquaient — donc les *anneaux de transmutation*, l'un des [[Cinq accès au cycle]], n'existaient pas. Deux gabarits d'affixes de plus (`wuxing_amplification` : *part de X × N*, `wuxing_transmutation` : *remplace X par Y*), **sur les anneaux et les amulettes** — c'est là que la note les place. Ils s'appliquent au vecteur du coup dans **l'ordre prescrit** (`Simulation._vecteur_modifie` : base → **amplifications** → ajouts → **transmutations** → purifications → normalisation à 1), après les affixes d'arme et les gemmes. Décisions : une transmutation dont l'élément source est **absent du vecteur** ne fait rien (elle ne crée pas d'élément à partir de rien) ; une amplification d'un élément absent non plus, comme le dit la note (« sans effet si absent ») ; fermer un élément avec deux anneaux qui transmutent vers le même Y **concentre** naturellement — c'est l'effet voulu (« fermer un élément interdit la rotation mais rend la concentration naturelle »).

> [!success] Codé le 2026-08-31 — « sur une arme pure, jamais »
> La taille en affinité (gemmes serties) ne s'ajoutait au vecteur de l'arme sans condition ; une épée mono-élément ou une lame fantomatique pouvait être diluée par sertissage, contre la règle écrite plus haut. `_affixes_offensifs` n'applique l'ajout normalisé que si le vecteur de l'arme n'est pas **pur** (`_vecteur_pur` : un seul élément porte tout). Les dégâts plats des gemmes et les affixes restent inchangés. Question voisine consignée dans [[À juger — parcours de jeu]] : la fourchette « misérable +0,04 → mythique +0,28 » est indexée sur la qualité de taille bornée [0,5 ; 2,0], donc le haut (mythique = 5,0) est inatteignable — élargir la borne ou réindexer sur les paliers ?

## Liens
- **Dépend de** : [[Wu Xing — cycles et vecteurs]], [[Domination et multiplicateurs]]
- **Alimente** : [[Cinq accès au cycle]], [[Jauge de chaîne Wu Xing]], [[Loot — affixes, gemmes et rareté]]
- **Voir aussi** : [[Armes fantomatiques]], [[Craft compositionnel]], [[Effets d'équipement passifs]], [[Ouvert — Fourchettes des gemmes]], [[Ouvert — Compensation de l'arme mixte]]
