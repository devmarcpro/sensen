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
