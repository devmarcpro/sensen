---
aliases: ["H.6 capture", "Vivarium — capture et élevage", "Capture d'insectes", "Couvée"]
tags: [contenu, élevage, formule, décidé]
domaine: contenu
statut: décidé
etape: 10
---

> [!success] Annexe H — intégré le 2026-08-26
> Les formules du vivarium — capture, élevage, et la raison pour laquelle les prises sauvages sont ternes.

Comment on attrape, comment on croise, et pourquoi l'éleveur bat le chasseur.

## Capture

Le **biotope, la saison, l'heure et la météo** décident de ce qui vole — tous des systèmes déjà en place ([[Biomes — schéma]], [[Décision — Saisons activées à l'étape 10]], [[Cycle jour-nuit et sommeil]], [[Météo]]).

> La pluie fait sortir les insectes d'Eau et terre les autres, le brouillard favorise le Bois, le blizzard vide tout.

```
jet : 1d20 + Perception/4 + Dressage/2 + filet×2 + bonus de collection
DD  : 8 + rareté×3
```

*Forme exacte du [[Jet de compétence universel]] (`1d20 + compétence/2 + stat/4`), avec la qualité de l'outil en modificateur — comme la récolte ([[Récolte]]).*

**Les prises sauvages sont ternes par construction :** la couleur du motif est **celle du fond ou sa voisine immédiate**.

> Écarter les deux couleurs est le travail de l'éleveur — une cinquantaine de couvées pour atteindre quatre crans d'écart.

C'est le mécanisme qui garantit que **la collection passe par l'élevage, jamais par le filet** — l'équivalent exact de la règle d'or du loot ([[Loot — affixes, gemmes et rareté]] : *l'atelier améliore, le donjon transforme*).

## Élevage

Habitat : le **vivarium**, un meuble ([[Meubles]]) posé sur une case claim ([[Rôles de cases]]). **Quatre couvées par vivarium.**

```
durée = 1,1 jour / (1 + Élevage×0,02 + bonus de collection)
        × 1,6 hors de la zone de confort thermique [5, 30]

portée = 1 à 2
```

- Le facteur `1 + Élevage×0,02` **est** le `skill_factor` standard ([[Progression par l'usage]]) — aucune formule nouvelle.
- La zone de confort **[5, 30]** est exactement celle de la température ressentie ([[Météo]]) : chauffer un vivarium (cheminée, [[Meubles]]) devient un vrai geste d'éleveur.
- Les couvées avancent par **échéance en timer wheel**, jamais par tick ([[Simulation du monde — performance]] : *10 000 cultures plantées = coût nul entre deux échéances*).

## Commandes

Chaque semaine, un collectionneur demande une variété précise, tirée à **un ou deux pas** de ce que le joueur possède déjà. **Il ne peut donc pas l'attraper : il doit la fabriquer.**

```
or = (80 + rareté×70 + distance_en_pas×45) × (chatoyant ? 3 : 1) × multiplicateur
```

*Même cadence hebdomadaire que le reste du monde ([[Dérive de la corruption]], [[Économie — sources et puits]]) ; le multiplicateur vient des paliers de [[Vivarium — registre et paliers]]. Le portefeuille fini du PNJ s'applique ([[Barèmes économiques]]).*

> [!success] Codé le 2026-08-28 — les commandes
> Chaque semaine (`_semaine_elevage`), si le registre n'est pas vide, une **commande** est tirée : une variété possédée, décalée d'**un ou deux pas** de couleur sur l'anneau (le motif conservé) — `or = (80 + rareté × 70 + pas × 45) × multiplicateur` (rareté = `capture.rarete` de l'espèce ; multiplicateur = 2 au palier 3 000 variétés ; chatoyant non codé). La commande s'affiche dans l'écran K ; on la **livre à un marchand** (option *Livrer la commande* du dialogue, bourse finie : il refuse s'il n'a pas l'or) avec un spécimen exact du sac. Une commande non livrée est remplacée la semaine suivante.

## Liens
- **Dépend de** : [[Vivarium — loci et variétés]], [[Règle d'anneau]], [[Conditions de reproduction]]
- **Alimente** : [[Vivarium — registre et paliers]], [[Commerce et boutiques]]
- **Voir aussi** : [[Jet de compétence universel]], [[Météo]], [[Meubles]], [[Progression par l'usage]], [[Simulation du monde — performance]], [[Récolte]]
