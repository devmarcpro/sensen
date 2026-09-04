---
aliases: ["Grille de composition", "Grille de sort"]
tags: [décidé, combat, codé]
domaine: combat
statut: décidé
etape: 11
---

# Décision — Grille de composition des sorts

> [!success] Décidé et codé le 2026-09-03, la nuit même
> Les trois questions ci-dessous ont été tranchées et le tout est codé — voir les trois callouts du 2026-09-03 dans [[Six types de modules et assemblage]]. En bref : **la grille vient de l'arme tenue** (une silhouette par voie, qui grandit avec le niveau de la compétence d'arme) ; **elle s'ajoute au coût** (la grille borne ce qu'on compose, la monnaie ce qu'on lance) ; **la forme d'un module vient de ce qu'il fait** (type et prix en ticks, `combat_rules.grille.formes_par_type`). Et, sur instruction du designer une heure plus tard, **la grille a remplacé l'assembleur** : on fait son Tetris, l'ordre de lecture est l'ordre du sort. Le reste de cette note est l'état de la réflexion avant le code, gardé tel quel.


> [!important] L'idée du designer, 2026-09-03
> « J'ai eu une idée qui permettrait de rendre la composition de capacités plus ludique et
> d'**interdire des combinaisons sans l'expliciter** : en gros chaque sort est composé sur une grille
> qui a une forme particulière et chaque module a une forme, le but est d'embarquer ce que le joueur
> veut mettre dans la forme (comme la grille de personnage dans *Jump Ultimate Stars* sur DS). »
>
> « Note pour plus tard la grille de sort. »

**Rien n'est engagé.** Cette note existe pour que l'idée ne se perde pas et pour poser ce qu'il
faudra trancher avant d'écrire une ligne.

## Pourquoi c'est la bonne cible

L'assemblage n'a **aucune tension** aujourd'hui. Un sort est une liste de modules et une addition de
coûts ; le seul frein est le prix en monnaie — donc **plus on monte en niveau, moins il y a de choix
à faire**. Le « no limit » décidé par le designer est bon pour la liberté, mais il a un effet de
bord : rien ne se refuse jamais, donc rien ne se choisit vraiment.

Une grille change la nature de la question. Ce n'est plus « est-ce que je peux payer ? » mais
**« est-ce que ça rentre ? »** — spatiale, immédiate, lisible d'un coup d'œil, sans connaître un seul
chiffre.

Trois choses qu'elle règle et que rien d'autre ne réglait :

- **Interdire sans écrire d'interdit.** C'est le cœur de l'idée. Aujourd'hui, deux modules qui ne
  doivent pas aller ensemble demandent une règle explicite — liste noire ou condition — à écrire, à
  lire et à maintenir. Avec des formes, l'incompatibilité **se voit** : deux grosses pièces ne
  rentrent pas ensemble, point.
- **Un budget qui ne se dévalue pas.** La monnaie s'inflate avec le niveau ; une grille, non. Elle
  contraint encore à l'étage 40.
- **Un support pour les six voies.** Si la forme de la grille vient de la classe ou de l'arme tenue,
  alors les mêmes modules **ne rentrent pas dans les mêmes grilles** — et les voies cessent de ne
  différer que par des chiffres.

## Ce qu'il faut trancher avant de coder

1. **Qui donne la grille ?** Le sort, l'arme tenue, la classe, ou un objet équipé (un grimoire qui
   *est* la grille) ? C'est la différence entre un puzzle **par sort** et un puzzle **par build**.
2. **La grille remplace-t-elle le coût, ou s'y ajoute-t-elle ?** Si elle remplace, on retire une
   couche et le jeu gagne en lisibilité. Si elle s'ajoute, c'est plus riche et bien plus dur à régler.
3. **La forme d'un module vient-elle de ce qu'il fait ?** Noyau lourd = grosse pièce, forme = pièce
   longue, liaison = pièce fine qui se faufile. Si oui, la forme devient une **lecture** du module et
   non une décoration.

## Ce qu'il faudra mesurer le jour où on s'y met

- Combien de modules le catalogue compte (119 slots de noyaux aujourd'hui) et quelle taille de grille
  laisse les capacités actuelles constructibles.
- Ce que ça casse des kits de classes déjà écrits — le designer a dit le 2026-09-03 n'avoir « rien à
  foutre des 19 sous-classes », donc cette contrainte-là est levée.

## Liens

- [[Six types de modules et assemblage]] — le modèle actuel, celui que la grille remplacerait
- [[Structure compétences-modules-slots]] — les voies, les monnaies, les noyaux
- [[Le vocabulaire des modules et l'absence d'arbre de talents]]

## Correction du designer (2026-09-04)

> « Une grille n'est pas forcément 3×3, tu l'as compris ça n'est-ce pas ? Pas de sens de lecture dans la grille ; pour les étapes, c'est une forme de grille par étape. »

Trois réponses : les dix-neuf fiches ont chacune leur silhouette (le 3×3 n'est que le bloc du guerrier au palier 0) ; **le sens de lecture est retiré** — la grille est un sac de pièces, la séquence en est dérivée dans un ordre canonique par type, sans effet sur le plan ; et **chaque étape du sort a sa grille** — la ligne des étapes du 1er septembre revient, une grille par étape. Codé le jour même : callout dans [[Six types de modules et assemblage]].
