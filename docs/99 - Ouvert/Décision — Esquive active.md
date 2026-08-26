---
aliases: ["Décision — Esquive active", "Ouvert — Esquive active", "Esquive active", "Esquive"]
tags: [combat, décidé]
domaine: combat
statut: décidé
etape: 0
---

> [!success] Décidé le 2026-08-26
> Tranché sur délégation du designer (« tout doit être rédigé et décidé avant production »). Le code s'appuie dessus ; révisable au playtest comme toute décision.

**La décision : pas d'esquive active dédiée — le mouvement EST l'esquive, et la compétence Esquive devient la mobilité de combat.**

- Cohérent avec [[Combat tactique sur grille]] : *pas de jet de toucher — ce qui décide, c'est le placement, le tempo et les éléments.* Une esquive active en plus serait un second système de défense redondant avec la garde ([[Garde en posture]]) et le déplacement.
- **La compétence Esquive** ([[Compétences — liste]], catégorie combat/survie) est conservée et redéfinie : **mobilité de combat**.

```
coût_déplacement_en_combat = 3 ticks × (1 − min(0.33, N_esquive × 0.005))
    arrondi au tick, minimum 2 ticks
    (N50 ≈ −25 %, plafond −33 % : un duelliste se déplace à 2 ticks)
XP d'Esquive : se déplacer en combat en étant adjacent à un hostile
    (XP = 1 par tuile sous menace — la mobilité s'apprend sous le feu)
```

- Le module **Pas de côté** ([[Modules]] : esquive-déplacement 2 tuiles) reste le déplacement actif payé en mana — c'est l'« esquive active » de ceux qui la veulent, au prix d'un slot.
- Toutes les références existantes restent valides : Lapin → Esquive ([[Astrologie — cycle sexagésimal]]), skill +2..+6 Esquive ([[Effets d'équipement types]]), classification combat/survie ([[Double niveau combat et général]]). Les niveaux effectifs d'équipement accélèrent le déplacement — un anneau d'Esquive se sent.
- Le `malus_poids_armure` de l'ancien jet de défense ([[Pipeline de résolution du combat]], étape supprimée) ne s'applique plus qu'au **déplacement** via la capacité de poids ([[Armures et poids porté]]).

## Liens
- **Dépend de** : [[Combat tactique sur grille]], [[Compétences — liste]], [[Trous connus du combat]]
- **Alimente** : [[Boucle de tick]], [[XP de combat]], [[Double niveau combat et général]]
- **Voir aussi** : [[Garde en posture]], [[Modules]], [[Astrologie — cycle sexagésimal]], [[Effets d'équipement types]], [[Armures et poids porté]]
