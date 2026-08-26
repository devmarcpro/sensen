---
aliases: ["12", "12. Créatures et PNJ", "Système modulaire", "Unification monstre/PNJ", "Schéma unifié créature/PNJ"]
tags: [êtres, décidé]
domaine: êtres
statut: décidé
etape: 9
---

Il n'y a pas de distinction technique entre un monstre et un PNJ humain. C'est de là que vient l'implication gameplay majeure : n'importe quelle créature peut devenir un compagnon.

**Principe :** les PNJ (villageois, marchands, monstres...) sont tous construits de la **même manière**, à partir de parties de sprites assemblées de façon modulaire (pipeline hérité du `.vox`, [[Squelette modulaire et points d'attache]]) — il n'y a pas de distinction technique entre un "monstre" et un "PNJ humain".

**Squelette modulaire :** une créature humanoïde est composée de parties interchangeables :
- 1 tête (parmi une bibliothèque de variantes, ex : têtes n°1, 4, 18, 32...)
- 1 torse (ex : torse n°1, 42...)
- 2 bras (ex : bras n°1)
- 2 jambes (ex : jambe n°6)

Chaque créature du jeu est un assemblage choisi dans ces bibliothèques de parties.

**Unification monstre/PNJ :** tous les êtres vivants (monstres sauvages, villageois, marchands...) partagent la même structure de données : stats, inventaire, relations, etc. Un monstre est donc, techniquement, un PNJ comme un autre.

**Implication gameplay majeure :** grâce à cette unification, **n'importe quelle créature — un monstre sauvage aussi bien qu'un marchand — peut potentiellement devenir un compagnon**, via le même système sous-jacent de relations/réputation ([[Réputation et relations]]). Le fonctionnement complet des compagnons (capacité d'escorte par Charisme+Leadership, statuts permanent/suiveur territorial, ordres, mort et résurrection façon Elona) est spécifié en **[[Compagnons]]** ; l'IA de toutes les créatures en **[[IA des créatures]]**.

**Templates de morphologie :** les créatures non-humanoïdes utilisent des **templates de squelette différents** selon leur morphologie (quadrupède, volant, amorphe, etc.), plutôt que d'être forcées dans le squelette humanoïde tête/torse/2bras/2jambes.

**Parties du corps = cosmétiques :** les parties assemblées (tête, torse, bras, jambes, ou équivalents selon template) sont **purement visuelles**. Les stats de la créature viennent d'ailleurs (race, classe, niveau).

**Conditions de recrutement et apprivoisement :** voir [[Apprivoisement et recrutement]].

**Conséquence d'architecture ([[Décisions d'architecture]]) :** *une seule scène `creature.tscn` pour tout être vivant* — elle se configure entièrement depuis un JSON de créature au spawn. **Ne jamais créer une scène par type de monstre.**

**Même système pour le joueur :** le double niveau ([[Double niveau combat et général]]), le potentiel ([[Potentiel]]) et la progression par l'usage s'appliquent identiquement aux PNJ et compagnons.

## Liens
- **Dépend de** : [[Data-driven design]], [[Direction artistique]]
- **Alimente** : [[Squelette modulaire et points d'attache]], [[Schéma créature]], [[Compagnons]], [[IA des créatures]], [[Apprivoisement et recrutement]]
- **Voir aussi** : [[Réputation et relations]], [[Potentiel]], [[Double niveau combat et général]], [[Décisions d'architecture]], [[Agriculture et élevage]], [[Créatures]]
