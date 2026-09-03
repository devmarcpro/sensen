---
aliases: ["H.7", "Annexe H.7", "Blocs de l'être", "L'être unique", "Être unique", "Schéma d'être"]
tags: [êtres, architecture, décidé]
domaine: êtres
statut: décidé
etape: 9
---

> [!success] Annexe H — intégré le 2026-08-26
> Le principe le plus structurant du jeu, formulé définitivement. Il **remplace** toute idée de « types » d'entités.

Le même schéma décrit un mouton, un bandit, un roi et un dragon. **La différence n'est pas une branche dans le code : c'est un bloc vide dans la fiche.**

## Le schéma unique

```js
{ id, race, classe, fonction, nom, role,
  génome : { … },                              // les loci déclarés par l'espèce
  corps  : { stats, silhouette, taille, âge, sexe, slots },
  esprit : { intelligence, tempérament, dressabilité },
  social : { culture, foyer, lignée, rang, relations },
  agenda : { métier, poste, ordre, territoire },
  repro  : { moteur, conditions, portée, coûts } }
```

| Être | Blocs remplis |
|---|---|
| mouton sauvage | génome, corps, repro |
| bandit | corps, esprit, social, agenda |
| roi | corps, esprit, social, agenda, repro |
| dragon | tous |

**Les trois axes ([[Les trois axes — race, classe, fonction]]) :** `race` remplace l'ancien `espece` (les deux faisaient le même travail), `classe` porte le talent ([[Talents de classe]]) et **est un bloc comme les autres — présent ou absent** : un mouton n'en a pas, jusqu'à ce que sa lignée monte assez d'Intelligence pour en apprendre une. `fonction` est ce qu'il fait de ses journées ([[Fonctions]]).

**Les systèmes hebdomadaires parcourent tous les êtres et appliquent ceux dont le bloc est présent. Aucun test d'espèce.** Un système lit `si le bloc existe`, jamais `si c'est un mouton` — c'est la même discipline que les tags de [[Data-driven design]], appliquée au vivant.

**Conséquence directe :** le vieillissement ([[Âge des PNJ]]) tourne sur tout être qui a `corps.âge` — moutons compris. La succession ([[Familles et succession]]) tourne sur tout être qui a `social.rang` — un chef de meute compris. L'élevage ([[Élevage — intention et familles]]) tourne sur tout être qui a `repro` — un roi compris.

## Le champ `role`

`sauvage` → `apprivoisé` → `résident` → `garde` → `bétail`

Un être change de rôle **selon sa place dans le monde, jamais selon son espèce**. La faisabilité d'une transition vient de la **dressabilité** (`esprit`) et de la **relation** ([[Réputation et relations]]) — et de la réaction de l'intéressé : un être qui a un métier, une famille, une culture et un nom qu'on connaît **ne se met pas en enclos. Il part, ou il se retourne.**

Ce n'est pas une interdiction, c'est une **conséquence** — la même grammaire que les lois des royaumes ([[Lois et infractions]]), qui n'interdisent rien mais font payer.

*Ce champ absorbe et généralise le `housing_default` normal/bétail de [[Habitat des PNJ]] et le `recruitable` de [[Schéma créature]] : voir [[Rôles de l'être]].*

## Conséquence : rien n'est réservé

Il n'y a **pas de refus par type**. Un compagnon porte une arme s'il a un slot de main, des modules s'il a l'intelligence, une barde si son corps est quadrupède ([[Équipement — 14 slots]] : emplacements par morphologie).

**Un mouton de lignée sélectionnée peut donc devenir un membre de groupe redoutable** — pas par une exception, mais parce que quelqu'un a emprunté toutes les routes du jeu :

- des dizaines de générations pour monter Force, Endurance et Intelligence ([[Règle d'anneau]], loci `nombre` sans plafond — [[Loci — les dix types]]) ;
- une lignée nourrie et logée, dont le potentiel a été rendu par la cuisine ([[Potentiel]], [[Cuisine et alchimie]]) ;
- des bardes forgées en mithril, donc les strates profondes, donc l'Artisanat ([[Craft compositionnel]]) ;
- des heures de combat pour que ses compétences montent par l'usage ([[Progression par l'usage]]) ;
- du Leadership pour qu'il tienne une place d'escorte ([[Compagnons]]) ;
- des modules lus, appris et sertis ([[Grimoires et manuels]]).

> **Le mouton ultime n'est pas une permission accordée, c'est une conséquence atteinte.**

**Le jeu doit le reconnaître quand ça arrive** — cut-in, entrée au registre, réputation ([[Réputation et relations]]). *Un exploit que personne ne salue n'en est pas un.*

> [!success] Corrigé le 2026-08-29 — « agilité » n'existe pas
> Les six stats du jeu sont **Force, Dextérité, Endurance, Volonté, Perception, Charisme**. Huit fiches citaient pourtant une **`agilite`** ou un **`esprit`** : cinq classes cachées (**Le Masque**, **Le Passeur**, **Le Fossoyeur**, **Le Sablier**, **Le Sceau**) — des points de création perdus —, la **tomate** (objet et plante) et **deux masques** (Renard et Hibou), dont les bonus ne s'appliquaient à rien. `agilite` est reversée sur **Dextérité**, `esprit` sur **Volonté** — les noms courants de ces deux idées dans ce jeu. Les points sont **additionnés**, jamais écrasés : Le Masque avait *agilité 2 + dextérité 1*, il a désormais **dextérité 3** (ma première passe, qui remplaçait la clé sans additionner, lui en avait fait perdre deux — attrapé en relisant le diff). Trouvé par le même contrôle que les compétences fantômes des classes cachées : comparer chaque nom cité en données à la liste réelle. `tools/audit_donnees.py` vérifie désormais **tout nom de stat** cité par une classe, une race, un objet, une plante ou un statut (`stat:<nom>`).

> [!success] Constaté le 2026-09-03 — `housing_default` n'existe pas : le logement est un **lit** dans le territoire
> Le bloc « rôle » proposait un champ `housing_default`. Le code l'a résolu autrement : la fiche porte `role` et `fonction`, et le logement d'un résident est un **lit** posé dans le territoire du joueur — c'est l'attribution d'un lit qui fait l'humeur, pas un défaut de fiche (`_recalculer_humeurs`). Le champ n'existe donc pas, et n'a pas à exister.

## Liens
- **Dépend de** : [[Schéma unifié créature-PNJ]], [[Data-driven design]]
- **Alimente** : [[Rôles de l'être]], [[Apparence — données et équipement]], [[Schéma créature]], [[Élevage — intention et familles]], [[Compagnons]]
- **Voir aussi** : [[Âge des PNJ]], [[Familles et succession]], [[Habitat des PNJ]], [[Équipement — 14 slots]], [[Loci — les dix types]], [[Tests de conformité — élevage]]
