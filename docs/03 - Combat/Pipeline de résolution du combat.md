---
aliases: ["E.3", "Annexe E.3", "Pipeline de combat", "Résolution du combat", "E.3.3", "E.3.4"]
tags: [combat, technique, formule, décidé]
domaine: combat
statut: décidé
etape: 0
---

Les six étapes de résolution d'une attaque, avec les jets de dés explicites façon roguelike.

Combat et actions risquées reposent sur des **jets de dés explicites**, façon roguelike (ToME/Elona) — lisibles en mode tactique, générateurs de variance et de récit. Notation XdY dans les données.

```
Une attaque (arme ou compétence-module) :
1. Coût : mana (A.6) déduit — ou surchauffe (A.5).
2. JET DE TOUCHER :
     attaque = 1d20 + N_arme/2 + Dex/4
     défense = 10 + N_esquive/2 - malus_poids_armure
     attaque >= défense → touché.
     1d20 naturel 20 → CRITIQUE (dégâts max +50 %) ; naturel 1 → échec
     critique (raté + le défenseur gagne une riposte gratuite).
     DEGRÉS DE RÉUSSITE : battre la défense de 10+ = coup solide
     (dégâts +25 %) — garde la marge signifiante à haut niveau,
     quand les bonus N/2 dépassent l'amplitude du d20.
3. JET DE DÉGÂTS (le jet de TOUCHER n'existe plus — la géométrie
     décide, 5.1 ; les dés de dégâts, eux, sont conservés) :
     bruts = jet(des_fonctionnalité, cf. B.3.1)
             * (durete_BASE/20) * qualite    (règle A.4.1)
             + For/4 (mêlée) ou Dex/4 (distance)
             + effets des modules actifs (leurs propres dés)
     puis multiplicateur élémentaire Wu Xing (A.4.6) si l'attaque
     porte un élément : domination x1.5 / dominé x0.65 / engendré
     x0.8 — affiché au survol en mode tactique.
4. MITIGATION À JET : l'armure ENCAISSE un jet
     reduction = jet(des_protection_totale)  — chaque pièce contribue
     ses dés selon dureté/qualité/facteur_slot (A.4.2) ;
     degats_finaux = max(0, bruts - reduction)
5. Application santé + événements EventBus : `damage_dealt`,
   `creature_killed` si mort (écoutés par quêtes, XP, réputation).
6. XP : attaquant gagne XP d'arme et de modules utilisés ; défenseur
   gagne XP d'Esquive et d'Encaissement.
UI mode tactique : au survol d'une cible, afficher chance de toucher,
fourchette de dégâts, chance de critique — la lisibilité est le but.
Statuts (brûlure, gel, poison...) : appliqués par tags des modules,
tickés en phase 2 de E.1, données dans data/status_effects/.
Le host tire tous les dés (autorité, E.11) — RNG seedé par tick pour
la reproductibilité en debug.
```

> **Note de cohérence :** l'étape 2 (jet de toucher) et l'étape 4 (mitigation à jet) sont **remplacées** par les décisions ultérieures de la direction tactique — [[Combat tactique sur grille]] supprime le jet de toucher (« une cible à portée est touchée »), et [[Armure par zone et constructions]] remplace la mitigation par dés par une **réduction plate par zone**. Le texte intégral d'origine est conservé ci-dessus ; les étapes 1, 3, 5 et 6 restent en vigueur telles quelles. Voir [[Décisions fondatrices]] (« Armure par zone → supprime la mitigation par dés, cause structurelle de l'écrasement des dégâts »).

**Jet de compétence universel (hors combat) :** voir [[Jet de compétence universel]].

## Liens
- **Dépend de** : [[Boucle de tick]], [[Mana]], [[Stats d'armes]], [[Fonctionnalité]]
- **Alimente** : [[XP de combat]], [[Statuts]], [[Armure par zone et constructions]], [[Domination et multiplicateurs]]
- **Voir aussi** : [[Jet de compétence universel]], [[Combat tactique sur grille]], [[Zones de coup par dénivelé]], [[EventBus]], [[Réseau]], [[Armures et poids porté]]
