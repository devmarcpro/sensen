---
aliases: ["A.5", "A.6", "Annexe A.5", "Annexe A.6", "Mana", "Surchauffe"]
tags: [combat, ressource, formule, décidé]
domaine: combat
statut: décidé
etape: 0
---

Le pool de mana, sa régénération façon Elin, et la surchauffe — lancer sans mana est permis, mais ça coûte des PV.

```
mana_max = 20 + (Volonté * 3) + (N_meditation * 2)
    N_meditation inclut les niveaux effectifs d'équipement (A.4.4) ;
    au retrait d'un objet, le mana courant est clampé au nouveau max
    (règle de retrait A.4.4).
Régénération passive : tous les 10 ticks (≈1 s en temps réel — voir 5.0 et D.2),
    chance de 1/8 de régénérer
    regen = 1 + N_meditation * 0.2 (niveaux effectifs inclus ; l'XP de
    Méditation gagnée à chaque proc est calculée sur le niveau réel)
Repos actif (s'asseoir/camper) : la chance passe à 1/2 par seconde.
Surchauffe : lancer sans mana suffisant est permis ; le déficit est infligé
    en dégâts de santé * 2. La compétence Contrôle du Mana réduit ce
    multiplicateur : 2 / skill_factor(N_controle).
```

**Coût en mana d'une compétence assemblée (A.6) :**
```
cout_total = somme des couts des modules équipés dans la compétence
cout_module_effectif = cout_base_module / skill_factor(N_module)
```
Monter un module en niveau le rend plus puissant ET moins coûteux (puissance : `effet_base * skill_factor(N_module)`).

**Décision ([[Structure compétences-modules-slots]]) :** *Pool de mana : résolu* — `20 + Volonté×3 + Méditation×2` (+ effets d'équipement, règle de retrait [[Effets d'équipement passifs]]). **Ni la race** (sauf via ses bonus de stats) **ni l'arme** n'y entrent directement.

**Deux modulateurs externes :**
- **Conductivité de mana de l'arme tenue** ([[Application des stats de matériau]]) : `cout_effectif *= (1 - conductivite_mana_arme / 140)` (max ~−65 %).
- **Élément du lieu** ([[Wu Xing hors combat]]) : ×0.85 si le module partage l'élément dominant du lieu, ×1.15 si le lieu domine son élément.

**Régénération accélérée par le sommeil :** ×4 pendant le sommeil ([[Cycle jour-nuit et sommeil]]).

> [!success] Décidé le 2026-08-26 — dans le prototype
> La régénération est tirée par le RNG seedé de la simulation : à chaque tranche de 10 ticks franchie par une entité, 1 chance sur 8 de rendre `1 + N_meditation × 0.2` (N = 0 pour l'instant). La surchauffe est en place : le déficit est infligé en PV × 2 (`combat_rules.json`, bloc `mana`). Le `skill_factor` des modules vaut 1 jusqu'à la progression (étape 4).

## Liens
- **Dépend de** : [[Stats de personnage]], [[Progression par l'usage]], [[Boucle de tick]]
- **Alimente** : [[Structure compétences-modules-slots]], [[Pipeline de résolution du combat]], [[Armes fantomatiques]], [[Modules]]
- **Voir aussi** : [[Effets d'équipement passifs]], [[Application des stats de matériau]], [[Wu Xing hors combat]], [[Endurance]], [[Compétences — liste]], [[Cycle jour-nuit et sommeil]]
