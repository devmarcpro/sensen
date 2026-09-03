---
aliases: ["Attaque lourde", "Télégraphe", "Attaque lourde et télégraphe"]
tags: [combat, décidé]
domaine: combat
statut: décidé
etape: 0
---

L'action qui brise la garde — et le gain décisif de la direction tactique : le télégraphe devient une information d'interface, pas une animation.

**Attaque lourde** : action distincte, **coût ×2 en ticks**, **dégâts ×2.2**, **brise la garde**. Elle est **visible par l'adversaire** pendant sa préparation (icône d'intention) — en tactique, le télégraphe est une **information d'interface**, pas une animation. C'est le gain décisif de la direction ([[Décisions fondatrices]]).

**Coût en endurance ([[Endurance]]) :** attaque lourde 18 (contre 8 pour une attaque normale).

**Coût en ticks ([[Boucle de tick]]) :** `attaque : 10 / vitesse_arme ticks · attaque lourde : ×2`.

**Rôle dans la jauge de chaîne ([[Jauge de chaîne Wu Xing]]) :** la voie **construction/détonation** consiste précisément à placer une frappe lourde en 5ᵉ position — *placer sa plus grosse frappe en dernier est la stratégie centrale du système*.

**Extension du principe aux sorts ([[Sorts cataclysmiques]]) :** une **canalisation visible** (l'adversaire voit la préparation, peut fuir ou interrompre) complète la mécanique pour les sorts longs.

**Note sur les créatures ([[Trous connus du combat]]) :** en tactique, l'intention est **affichée** plutôt que devinée — le besoin d'un vocabulaire d'attaque lisible des créatures est donc moindre, mais chaque famille doit avoir des actions distinctes.

> [!success] Décidé le 2026-08-26 — quand se résout une action télégraphée
> Une action télégraphée (attaque lourde, action de créature > 10 ticks, canalisation) est **engagée** à la décision — le compteur est poussé de son coût, l'intention et sa zone deviennent visibles — et **résolue à l'échéance**, quand le compteur revient : la cible a donc tout ce temps pour bouger, prendre la garde ou interrompre ([[Décision — Chaîne côté ennemis]]). Si la cible n'est plus à portée ou en vue à l'échéance, le coup passe dans le vide. Une action **non** télégraphée (≤ 10 ticks) se résout **immédiatement**, son coût est le temps de récupération. C'est ce qui rend le tempo rapide « sans préavis » et le tempo lourd lisible.

> [!success] Codé depuis l'étape 0 — trace ajoutée le 2026-09-04
> `Regles.ticks_attaque()` double les ticks d'une lourde (`actions.lourde_mult_ticks`) et `degats_arme()` multiplie ses dégâts (`lourde_mult_degats`) ; toute action plus longue que `actions.telegraphe_seuil_ticks` est télégraphiée (`est_telegraphee()`) — visible de tous, interruptible — et le composeur avertit dès qu'un sort passe le seuil.

## Liens
- **Dépend de** : [[Combat tactique sur grille]], [[Garde en posture]], [[Boucle de tick]]
- **Alimente** : [[Jauge de chaîne Wu Xing]], [[Sorts cataclysmiques]]
- **Voir aussi** : [[Endurance]], [[Décisions fondatrices]], [[Trous connus du combat]], [[Écrans d'interface]]
