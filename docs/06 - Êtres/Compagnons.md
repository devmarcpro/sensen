---
aliases: ["E.17", "Annexe E.17", "Compagnons", "Escorte", "Leadership", "Résurrection"]
tags: [êtres, décidé]
domaine: êtres
statut: décidé
etape: 9
---

La capacité d'escorte, les deux statuts de compagnon, et la mort façon Elona : mort réelle, mais résurrection payante.

**Capacité d'escorte** — le nombre de compagnons actifs qui suivent le joueur dépend du Charisme et d'une compétence dédiée **Leadership** (progresse à l'usage : gagner des combats avec des compagnons actifs, donner des ordres) :

```
places_escorte = 1 + floor(Charisme / 5) + floor(N_leadership / 10)
  (départ typique : 2 ; bâti Charisme/Leadership élevés : 6+)
```

**Deux statuts distincts :**
- **Compagnon permanent** : recruté ([[Apprivoisement et recrutement]]), voyage partout avec le joueur, compte dans `places_escorte` quand actif ; les inactifs attendent à la base (et peuvent y être assignés à des jobs, [[Population et exploitation]]).
- **Suiveur territorial** : PNJ résident mis en état "suivre" UNIQUEMENT sur le territoire du joueur (aider à un chantier, escorte locale) — ne compte pas dans `places_escorte`, refuse de quitter le territoire.

**Ordres** (via dialogue ou raccourci, façon Elona) : suis-moi / attends ici / posture agressive / défensive / évite les combats / retourne à la base. En mode tactique ([[Action-time à ticks]]), les ordres sont donnés **sans coût de ticks**.

**Consignes en combat ([[Combat tactique sur grille]]) :** ils agissent à leur propre compteur, comme toute entité. Le joueur leur donne des consignes (suivre / tenir la position / cibler en priorité / repli / posture agressive-défensive) modifiables à tout moment, gratuitement — donner un ordre ne coûte pas de ticks, seul l'agir en coûte.

**Équipement :** géré par le joueur via un écran d'échange ; les compagnons utilisent leurs compétences (qui progressent à l'usage, comme acté en [[Schéma créature]]).

**Mort d'un compagnon (façon Elona) :** un compagnon tué est MORT, pas inconscient — mais **ressuscitable** :
- Son corps/dépouille est récupérable (objet-âme dans l'inventaire, poids symbolique) ; son équipement reste sur lui.
- Résurrection = action dédiée coûteuse : soit un PNJ prêtre/autel de sanctuaire (POI, [[Carte du monde]]) contre de l'or (coût ∝ niveau du compagnon), soit plus tard un sort du domaine Vie ([[Domaines de grimoires et manuels]]) de haut niveau.
- Un compagnon mort non ressuscité reste mort indéfiniment (pas de disparition du corps) — la perte n'est jamais irréversible, mais elle coûte et interrompt (retour au sanctuaire).
- À la résurrection : malus temporaire ("affaibli", −20 % stats pendant 1 jour in-game). Relation inchangée — mourir pour vous n'est pas un motif de rancune, être laissé mort longtemps pourrait le devenir (extension future).

**Puits d'or ([[Économie — sources et puits]]) :** la résurrection de compagnons est un puits récurrent — coût ∝ niveau, payé à un prêtre, lui-même limité par son propre portefeuille.

**Autel domestique ([[Meubles]]) :** résurrection à domicile, coût ×1.5.

**Progression :** nourrir ses compagnons avec de bons plats accélère leur croissance ([[Potentiel]]). Parité totale d'XP avec le joueur ([[XP de combat]]).

**Un compagnon mortel vieillit ([[Âge des PNJ]]) :** son espérance de vie raciale s'applique — attachement et renouvellement.

> [!success] Codé le 2026-08-28 — étape 9.D, `combat_rules.compagnons`
> `places_escorte = 1 + ⌊Charisme/5⌋ + ⌊Leadership/10⌋` tel quel. **Recruter** (dialogue, option affichée quand la relation atteint `recruitable.threshold` ou la faveur du palier 90) : le PNJ passe au camp du joueur, profil `compagnon`, relation conservée ; les **ordres** (dialogue : *Suis-moi* / *Attends ici*) ne coûtent aucun tick, seul l'agir en coûte (action d'utility `suivre` : rejoindre le maître au-delà de 2 tuiles). Parité d'XP : un compagnon progresse par l'usage comme le joueur (déjà le cas). **Mort** : le compagnon reste mort sur place ; son **âme** (objet `ame`, poids symbolique) va dans le sac du joueur ; **résurrection** sur un **autel domestique** adjacent (meuble) contre `or_par_niveau × niveau × 1,5` (décision : 20 or par niveau ; le prêtre attend le sanctuaire), il revient **affaibli** (−20 % de stats un jour in-game, statut `affaibli`) et sa relation ne change pas. Postures de combat, échange d'équipement et suiveurs territoriaux attendent.

> [!success] Codé le 2026-08-28 — le prêtre
> Bâtiment **chapelle** (autel + lit) dans le pool des villages, tenu par un **prêtre** (créature `pretre`, fonction `pretre`, bourse 500). Dialogue → *Ressusciter* (N) avec une âme dans le sac : `coût = 20 or × niveau` (**sans** le ×1,5 de l'autel domestique), payé au prêtre — sa bourse est finie : ce qui dépasse `or_max` sort du jeu (puits). À la résurrection, chez le prêtre comme à l'autel, le compagnon revient **Affaibli** (−20 % de stats, mécanisme existant). Le sort de Vie attend.

## Liens
- **Dépend de** : [[Apprivoisement et recrutement]], [[Stats de personnage]], [[Compétences — liste]], [[IA des créatures]]
- **Alimente** : [[Population et exploitation]], [[Économie — sources et puits]], [[XP de combat]]
- **Voir aussi** : [[Potentiel]], [[Âge des PNJ]], [[Meubles]], [[Dialogue PNJ]], [[Familles de capacités de la grille]], [[Domaines de grimoires et manuels]], [[Combat tactique sur grille]], [[Statuts]]
