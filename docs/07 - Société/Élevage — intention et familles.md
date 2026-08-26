---
aliases: ["H", "H.0", "H.4", "Annexe H", "Élevage", "Élevage — intention et familles", "Les six familles"]
tags: [société, élevage, décidé]
domaine: société
statut: décidé
etape: 10
---

> [!success] Annexe H — intégré le 2026-08-26
> La note d'entrée du système d'élevage. **L'Annexe H est intégrée en totalité dans le coffre** — tableaux, formules et blocs de code compris, répartis sur les 15 notes listées en bas. Il n'y a pas de version monolithique archivée : ces notes *sont* l'annexe.

Un jeu dans le jeu, avec trois verbes : **attraper, croiser, compléter**.

## L'intention

Il doit tenir sur les systèmes **déjà présents** — biomes ([[Biomes — schéma]]), saisons ([[Décision — Saisons activées à l'étape 10]]), heure ([[Cycle jour-nuit et sommeil]]), météo et température ressentie ([[Météo]]), bâtiments ([[Construction cadrée]]), compétences ([[Progression par l'usage]]), potentiel ([[Potentiel]]) — et **n'introduire aucun sous-moteur parallèle**.

> Un groupe d'animaux nouveau doit être une **fiche de données**, jamais un système à écrire.

**Règle d'or : aucun `if (espèce === 'x')` dans le code.** Si une espèce réclame une exception, c'est qu'il manque un **type de locus** ([[Loci — les dix types]]), une **condition** ([[Conditions de reproduction]]) ou un **crochet** ([[Intégration de l'élevage au moteur]]) — et c'est le registre qu'il faut étendre, pas le cas particulier. C'est [[Data-driven design]] appliqué au vivant, et [[Décision — Pipeline de contenu]] en donne le pipeline exact.

## Les six familles

Chaque groupe d'animaux doit apporter **un verbe que les autres n'ont pas**. *Ajouter un dixième groupe « croise et attends » n'ajoute pas une heure de jeu, il étale la même.*

| Famille | Ce qu'elle demande | Emblème |
|---|---|---|
| **grille à remplir** | patience, sélection dirigée | insectes, poissons |
| **trait caché** | déduire ce que la bête porte | serpents, chats |
| **coût par croisement** | arbitrer à chaque génération | vers à soie, huîtres |
| **population autonome** | régler puis laisser tourner | ruches, fourmilières |
| **individu qui évolue** | attendre et accompagner | tortues, cervidés |
| **le monde décide** | placer au bon endroit | phalènes, coraux |

**Recommandation de construction :** **six groupes, un par famille** — poissons, serpents, vers à soie, ruches, tortues, phalènes. Le reste vient ensuite en **pure donnée, une fiche à la fois** ([[Catalogue des groupes d'élevage]]).

## Où ça s'insère

Étape **10** de [[Ordre de construction]], avec l'agriculture et l'élevage ([[Agriculture et élevage]]) — c'est l'extension de `7.4` que le GDD annonçait sans la spécifier. Les habitats sont des meubles ([[Meubles]]) sur les cases claim de rôle *Champs* ou *Base* ([[Rôles de cases]]).

**Ce que ça raccorde :** la chasse et la capture ([[Apprivoisement et recrutement]]), la cuisine et le potentiel ([[Cuisine et alchimie]] — nourrir une lignée accélère sa croissance), l'abstraction hors-site ([[Abstraction hors-site]] — les colonies produisent en veille), et le commerce ([[Commerce et boutiques]] — les collectionneurs paient).

## Liens
- **Dépend de** : [[Agriculture et élevage]], [[Blocs de l'être]], [[Data-driven design]]
- **Alimente** : [[Règle d'anneau]], [[Loci — les dix types]], [[Conditions de reproduction]], [[Catalogue des groupes d'élevage]], [[Vivarium — loci et variétés]]
- **Voir aussi** : [[Décision — Saisons activées à l'étape 10]], [[Intégration de l'élevage au moteur]], [[Tests de conformité — élevage]], [[Ordre de construction]], [[Meubles]]
