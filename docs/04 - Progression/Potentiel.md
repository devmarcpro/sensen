---
aliases: ["6.4", "6.4 Potentiel", "A.1.1", "Annexe A.1.1", "Potentiel", "Potentiel de progression"]
tags: [progression, formule, décidé]
domaine: progression
statut: décidé
etape: 4
---

Le cœur d'Elin : une sous-stat de potentiel par stat et par compétence, qui accélère la progression et s'épuise en montant. La gestion du potentiel est une boucle de jeu à part entière.

Chaque **stat** (les 6 de [[Stats de personnage]]) et chaque **compétence** possède une sous-stat de **Potentiel**, de 0 à 200 :

- **Plus le potentiel est haut, plus la stat/compétence monte vite** : l'XP gagnée est multipliée par `potentiel/100` (potentiel 200 = progression ×2, potentiel 50 = ×0.5).
- **Monter de niveau consomme du potentiel** : chaque level up de la stat/compétence fait baisser son potentiel — la progression s'essouffle d'elle-même si on ne l'entretient pas.
- **Potentiel de base permanent** : chaque personnage a un plancher de potentiel par stat/compétence, déterminé par sa **race et sa classe** ([[Races]]/[[Classes]]) — le potentiel ne descend jamais sous ce plancher. C'est ce qui donne son identité mécanique durable à chaque combinaison race/classe (un nain garde toujours un bon potentiel de Forge, même sans l'entretenir).
- **Restaurer/dépasser le potentiel :** principalement en **mangeant des plats cuisinés** ([[Cuisine et alchimie]] — chaque aliment porte des bonus de potentiel vers les stats concernées), en dormant (buff Reposé, [[Cycle jour-nuit et sommeil]]), et via des **entraîneurs PNJ** (service payant en ville ou PNJ entraîneur recruté sur sa base — un puits d'or supplémentaire, [[Économie — sources et puits]]).
- La gestion du potentiel devient une **boucle de jeu à part entière** (le cœur d'Elin) : bien manger n'est pas de la survie, c'est de l'optimisation de croissance — et ça raccorde l'agriculture, la chasse, la cuisine et l'élevage à la progression du personnage.
- S'applique aux **PNJ et compagnons** aussi (même système, [[Schéma unifié créature-PNJ]]) : nourrir ses compagnons avec de bons plats accélère leur croissance.

**Formules (A.1.1) :**

```
xp_effective = xp_gagnée * (potentiel / 100)
À chaque level up de la stat/compétence :
  potentiel = max(potentiel_base, potentiel - (10 + niveau/10))
potentiel_base : par race+classe (C.2/C.3), défaut 80, fourchette 50-130
Sources de potentiel : plats (A.9.1, principal), sommeil (Reposé : +2
  à toutes les stats consommées récemment), entraîneur PNJ (20 or *
  niveau actuel → +10 de potentiel dans une compétence choisie)
Cap : 200. Le potentiel est par-personnage (joueur, PNJ, compagnons).
```

**Le potentiel régule seul l'emballement ([[XP de combat]]) :** l'élément le plus monté épuise son potentiel et ralentit, les éléments frais gardent le leur — aucune règle anti-farm n'est nécessaire.

**Astrologie ([[Astrologie — cycle sexagésimal]]) :** *tout passe par le potentiel, jamais par un bonus dur — la naissance donne une pente, pas un plafond.*

> [!success] Codé le 2026-08-27
> `xp_effective = xp × potentiel/100 × bonus de race` ; au niveau : `potentiel = max(base, potentiel − (10 + N/10))` ; **potentiel de base** = moyenne race/classe quand elles diffèrent (défaut 80 ; par compétence, sinon par famille — `armes`, `magie`, `artisanat`… — sinon `_defaut` ; Humain 90 partout, Le Vent 100 partout), + 10 par l'astrologie, borné 50-130. Les sources de restauration (plats, sommeil, entraîneur) attendent les étapes 7-9 ; le cap 200 est en données.

> [!success] Précisé le 2026-08-28
> Première source de restauration codée : le **sommeil** (+2 aux cinq compétences/stats les plus travaillées depuis le dernier repos, [[Cycle jour-nuit et sommeil]]). Les plats et l'entraîneur suivent.

> [!success] Codé le 2026-08-28 — l'entraîneur
> Les PNJ tagués `entraineur` (maîtres de guilde, gardes de village) offrent *Entraîner* dans le dialogue : un écran liste les compétences du joueur, `coût = 20 or × niveau actuel` (20 au minimum), **+10 de potentiel** (plafond `potentiel_max`) ; l'or va au PNJ (puits partiel : il le dépense en rachats, sa bourse est finie). Décision : un garde n'entraîne que les compétences de combat (`category` ≠ general), un maître de guilde toutes.

## Liens
- **Dépend de** : [[Progression par l'usage]], [[Races]], [[Classes]]
- **Alimente** : [[XP de combat]], [[Cuisine et alchimie]], [[Astrologie — cycle sexagésimal]], [[Nourriture, potentiel et potions]]
- **Voir aussi** : [[Stats de personnage]], [[Cycle jour-nuit et sommeil]], [[Économie — sources et puits]], [[Compagnons]], [[Le vocabulaire des modules et l'absence d'arbre de talents]]
