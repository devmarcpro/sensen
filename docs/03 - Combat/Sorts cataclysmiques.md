---
aliases: ["Sorts cataclysmiques", "Cataclysmes", "Cratères"]
tags: [combat, build, décidé]
domaine: combat
statut: décidé
etape: 0
---

Les sorts spectaculaires sont autorisés et souhaitables ; trois leviers suffisent à les cadrer, sans cooldown arbitraire.

1. **Le coût en ticks est le régulateur principal.** Un sort qui creuse un cratère de 7 tuiles coûte ~60 ticks : pendant ce temps, un adversaire à 10 ticks par attaque frappe six fois. Le cataclysme devient un **pari**, lisible sur la timeline. Une **canalisation visible** (l'adversaire voit la préparation, peut fuir ou interrompre) complète la mécanique.
2. **Le coût en ressources doit mordre** : mana entier, endurance vidée, voire un coût persistant (fatigue, corruption accumulée). Non répétable dans un même combat.
3. **La destruction est triviale techniquement** sur grille : un cratère = *abaisser N tuiles de X niveaux*, une opération sur des entiers, instantanée et parfaitement synchronisable en réseau. Ce qui était un cauchemar en voxel devient une boucle.

**Deux garde-fous de simulation :** le **plancher et le plafond de hauteur** (0 et 20) bornent naturellement le vandalisme cumulé ; la **régénération des cases sauvages** ([[Claims et persistance]]) répare le terrain hors des claims — le joueur peut défigurer le monde, le monde se soigne. Sur les cases claim en revanche, les dégâts **persistent**, ce qui rend une attaque de royaume réellement traumatisante.

**Le critère de design qui prime :** un cratère doit être **tactiquement intéressant, pas seulement impressionnant**. Sur la grille, il crée une zone infranchissable, coupe des lignes de vue, piège des ennemis, se remplit d'eau. Le sort ne fait pas que des dégâts — il **réécrit le champ de bataille**. C'est cela qui justifie ses 60 ticks, pas ses chiffres.

> [!success] Codé le 2026-08-28 — le module Cataclysme et les trois leviers
> Noyau **Cataclysme** (`modules/cataclysme.json`, domaine Terre, effets `terrain` −4 avec chute + `degats`, **60 ticks**, **40 de mana**) : avec *Carré* et deux *Ampleur*, un cratère de 7 × 7. Les trois leviers : (1) **le coût en ticks** — 60 ticks franchissent le seuil de télégraphie, la canalisation est visible et interruptible comme toute charge lourde ; (2) **le coût qui mord** — tag `cataclysme` : **l'endurance est vidée** à l'exécution, et `unique_par_combat: true` : **une fois par combat** (`e.cataclysmes_combat`, remis à zéro à l'engagement), refusé sinon avec journal ; (3) **la destruction** : `terrain` abaisse des entiers, et mémorise désormais l'état d'origine (`_memoriser_terrain`) — **le monde se soigne hors claim**, le cratère persiste sur un claim. Décision : pas de coût persistant (fatigue, corruption) pour l'instant ; le cratère se remplit d'eau quand les liquides existeront.

## Liens
- **Dépend de** : [[Familles de capacités de la grille]], [[Action-time à ticks]], [[Hauteur de terrain ±10]]
- **Alimente** : [[Destruction du terrain]], [[Modules]]
- **Voir aussi** : [[Attaque lourde et télégraphe]], [[Mana]], [[Endurance]], [[Claims et persistance]], [[Eau et liquides]], [[Explosions]], [[Défense et raids]]
