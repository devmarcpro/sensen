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

> [!success] Décidé et codé le 2026-08-29 — les modules sont des **charges**, pas un savoir acquis
> **Précision du designer** : « on obtient des **charges** de modules en lisant des livres, et **chaque sort utilise 1 de chaque module utilisé** » — et la charge se consomme **à chaque lancer** (choix explicite du designer, contre la lecture « à la composition »). Un module cesse donc d'être une connaissance définitive pour devenir une **munition** : composer une capacité reste gratuit et permanent, mais **la lancer dépense une charge de chacun de ses modules** ; à court de charges, le sort ne part plus et le journal le dit.
> **Conséquences réglées ici.** L'être porte `modules_charges` (`id → n`) à côté de `modules_connus` (ce qu'il sait composer, acquis une fois pour toutes à la première lecture) — la connaissance ne se perd jamais, seule la munition s'épuise. Lire un livre donne **`charges_par_module`** charges de chacun des modules qu'il contient (`combat_rules.modules.charges_par_lecture`, 5), et non plus une simple entrée dans une liste ; relire un livre du même domaine **recharge**. Les modules de départ (classe, capacités déclarées d'une fiche) arrivent avec **`charges_depart`** (10). Les créatures d'IA ne consomment rien : elles n'ont pas de livres, et les priver de leurs capacités les rendrait inertes au bout de dix tours — **décision** assumée, à revoir si le designer veut une économie symétrique.
> **Ce que ça change pour le joueur** : les grimoires cessent d'être des cases à cocher pour devenir la ressource de fond du mage ; un sort à quatre modules coûte quatre charges par lancer, ce qui donne enfin un prix aux séquences longues, en plus de leurs ticks et de leur mana. L'écran *Capacités* et l'écran *Composer* affichent le stock, et un sort sans munition apparaît barré.

## Liens
- **Dépend de** : [[Vocabulaire des modules — six axes]], [[Donjons — structure et intégration]]
- **Alimente** : [[Lecture des livres]], [[Modules]], [[Structure compétences-modules-slots]]
- **Voir aussi** : [[Domaines de grimoires et manuels]], [[Loot — affixes, gemmes et rareté]], [[Craft compositionnel]], [[Meubles]], [[Statuts]], [[Tooltips contextuels]]
