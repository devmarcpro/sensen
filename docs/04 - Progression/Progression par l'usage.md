---
aliases: ["A.1", "Annexe A.1", "Progression des compétences", "skill_factor", "Usage"]
tags: [progression, formule, décidé]
domaine: progression
statut: décidé
etape: 4
---

La courbe unique que suivent toutes les compétences du jeu : polynomiale, sans plafond.

Toutes les compétences (armes, modules, récolte, artisanat, lecture, dual wielding, bouclier, deux mains, etc.) suivent la même courbe :

```
XP requise pour passer du niveau N au niveau N+1 :
xp_next(N) = base_xp * (N + 1)^1.6
avec base_xp = 100
```

- Niveau 1→2 : ~300 XP ; niveau 10→11 : ~4 600 XP ; niveau 50→51 : ~53 000 XP.
- Chaque usage donne une XP fixe selon l'action (voir [[Récolte]], [[Qualité d'artisanat]], [[Lecture des livres]], [[XP de combat]], [[Mana]], [[Endurance]]). Croissance polynomiale (pas exponentielle) : la progression ralentit mais ne devient jamais absurde, cohérent avec « infini à la Elin ».
- **Bonus de compétence :** la plupart des formules utilisent `skill_factor(N) = 1 + N * 0.02` (+2 % d'efficacité par niveau, sans plafond).

**Cadre général ([[Création de personnage]]) :** au départ, le joueur choisit une **Race** et une **Classe**, qui déterminent un kit de base (stats, compétences de départ). Au-delà de ce kit initial, tout se débloque et progresse par l'usage (façon Elona), sans plafond. **Mort :** pas de permadeath — mort avec pénalité (perte d'objets/XP), puis respawn ([[Mort et pénalité]]).

**Régulation :** [[Potentiel]] — l'XP effective est multipliée par `potentiel/100`.

**Agrégation :** [[Double niveau combat et général]].

**Signal :** `skill_level_up` sur l'EventBus, écouté par l'UI, les niveaux dérivés et les guildes ([[EventBus]]).

> [!success] Codé le 2026-08-27 — `systems/skills/progression.gd`, `data/competences/`
> La courbe telle quelle (`xp_next = 100 × (N+1)^1.6`, `combat_rules.progression`) ; **58 compétences en données** (`data/competences/`, `tools/gen_progression_data.py`) avec `category` combat/général, `stat` associée et `famille` ; les **modules** progressent sous leur propre id (catégorie combat, stat Volonté) sans fiche. Ce qui verse de l'XP aujourd'hui : chaque dégât appliqué (arme, type de dégâts, élément dominant, modules employés — [[XP de combat]]), l'armure qui épargne (construction), le défenseur (Encaissement = dégâts subis), Bouclier (dégâts bloqués), Esquive (1 par tuile adjacente à un hostile en combat), Athlétisme (1 par tuile), Méditation (chaque régénération), Lecture. Signal `skill_level_up`, journal, écran de fin.
> **Décision** : la **stat associée** à une compétence reçoit **la moitié** de l'XP versée (`part_stat: 0.5`), sur la même courbe et son propre potentiel — un niveau de stat = +1 ; c'est ainsi que les six stats progressent par l'usage, façon Elin, sans note dédiée jusqu'ici.

## Liens
- **Dépend de** : [[Le vocabulaire des modules et l'absence d'arbre de talents]]
- **Alimente** : [[Potentiel]], [[Double niveau combat et général]], [[XP de combat]], [[Récolte]], [[Qualité d'artisanat]], [[Structure compétences-modules-slots]]
- **Voir aussi** : [[Compétences — liste]], [[Mort et pénalité]], [[Piliers d'inspiration]], [[EventBus]]

> [!important] 2026-09-05, 13 h 30 — le designer : « retravaille les ratios pour les premiers niveaux, c'est trop lent de progresser au début »
> La courbe `xp_next = 100 × (N + 1)^1,6` demandait 100 XP pour le premier niveau d'une compétence, et l'XP de combat vaut les dégâts appliqués : avec un kit de départ qui frappe à 1-3, c'est cinquante coups pour un niveau. **Décision** : `xp_base` 100 → **40** et `xp_exposant` 1,6 → **1,9** (`combat_rules.progression`) — les seuils deviennent 40, 149, 322, 555, 852 … au lieu de 100, 303, 580, 918, 1 310 : les premiers niveaux viennent deux fois et demie plus vite, et le dixième presque comme avant (3 800 XP au lieu de 4 630). Les XP fixes des actions (récolte, artisanat, lecture) ne changent pas. Mesuré par le robot (« progression à l'étage N », 5 000 images, kit de départ, trois objets et trois sorts) : graine 9, resté au premier étage après cinq combats et deux tués — **quatre niveaux** (Épée 1, Tranchant 1, Métal 1, Athlétisme 1, 902 XP en cours) ; graine 21, un étage descendu, six combats, quatre tués — **huit niveaux** (Épée 2, Tranchant 2, Métal 2, Encaissement 1, Athlétisme 1). Avec l'ancienne courbe, la même XP donnait Épée 1 au plus (le deuxième niveau demandait 403 XP cumulées au lieu de 189) : le niveau de combat dérivé passe de 1,0 à 1,6 sur la graine 21.
