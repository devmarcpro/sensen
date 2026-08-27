---
aliases: ["Grimoires et manuels", "Grimoires", "Manuels de combat", "Livres"]
tags: [combat, progression, loot, décidé]
domaine: combat
statut: décidé
etape: 3
---

Les modules ne se craftent pas : ils s'obtiennent en lisant des livres à usage unique, générés aléatoirement, dont la lecture peut échouer.

**Acquisition des modules — Grimoires et Manuels :**
- Les modules ne se craftent pas : ils s'obtiennent en lisant des **livres** trouvables en donjon, achetables chez les marchands, etc.
- Deux types de livres :
  - **Grimoire** : contient des modules pour les sorts (magie).
  - **Manuel de combat** : contient des modules pour les armes.
- Lire un livre octroie un certain nombre de modules associés.
- Les livres sont **générés aléatoirement**.
- Plus un livre est puissant, plus il est difficile à lire, ce qui peut provoquer un **échec de lecture**.
- **Lecture** est une compétence qui progresse à l'usage (façon Elin/Elona) ; plus elle est élevée, plus le joueur obtient de modules d'un même livre et plus les chances de succès sont hautes.

**Échec de lecture et consommation :**
- Un livre est à **usage unique** : il est consommé/détruit à la lecture, réussite ou échec.
- En cas d'échec, un **effet aléatoire** se déclenche, mineur ou fort selon les cas (ex : léger étourdissement à confusion/téléportation/invocation d'ennemi).

**Décisions :**
- **Effets d'échec de lecture : résolu ([[Lecture des livres]])** — mineur (étourdissement 5 s, perte de mana), grave (confusion, téléportation, invocation hostile ≈ difficulté du livre) ; la table détaillée vit en données (`data/reading_failures.json`), extensible.
- **Domaines de grimoires : oui, résolu ([[Domaines de grimoires et manuels]]/[[Vocabulaire des modules — six axes]])** — 8 domaines de grimoires + 4 de manuels ; chaque livre généré tire son domaine, qui filtre les modules qu'il contient.

**Source principale ([[Donjons — structure et intégration]]) :** les donjons sont la **source principale** des grimoires/manuels (piédestaux, coffres, salles de bibliothèque thématiques).

**Aide de mobilier ([[Meubles]]) :** la Bibliothèque stocke les livres et donne **+5 % de réussite de lecture** à proximité.

> [!success] Codé le 2026-08-27
> Deux bases (`items/grimoire.json`, `items/manuel.json`) que le générateur de loot **compose** : domaine tiré (grimoires : les 5 éléments + arcane + vie, mappés au Wu Xing ; manuels : frappes / postures / techniques / maîtrise), difficulté `10 + étage × 10`, 2-4 modules du catalogue filtrés par le domaine (noyaux à mana de l'élément, noyaux neutres pour l'arcane ; frappes = noyaux à endurance, postures = conditions, techniques = déclencheurs et liaisons, maîtrise = modificateurs et formes — `loot_rules.livres`). Lire (`L`, 5 ticks) applique le jet de [[Lecture des livres]] ; les modules appris rejoignent `modules_connus` de l'être. L'**écran d'assemblage** qui les mettra en slots est l'étape 4 : d'ici là les capacités restent déclarées dans la fiche.

## Liens
- **Dépend de** : [[Vocabulaire des modules — six axes]], [[Donjons — structure et intégration]]
- **Alimente** : [[Lecture des livres]], [[Modules]], [[Structure compétences-modules-slots]]
- **Voir aussi** : [[Domaines de grimoires et manuels]], [[Loot — affixes, gemmes et rareté]], [[Craft compositionnel]], [[Meubles]], [[Statuts]], [[Tooltips contextuels]]
