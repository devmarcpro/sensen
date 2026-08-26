---
aliases: ["Les trois axes", "Race classe fonction", "Trois axes", "Les trois axes — race, classe, fonction"]
tags: [progression, êtres, architecture, décidé]
domaine: progression
statut: décidé
etape: 4
---

> [!success] Décidé le 2026-08-26
> **Tout être du jeu — joueur, PNJ, bête — se décrit par trois axes.** C'est l'aboutissement de [[Blocs de l'être]] : *le même schéma décrit un mouton, un bandit, un roi* — et désormais, **tu peux jouer n'importe lequel**.

Trois questions, trois catalogues, aucun recouvrement.

| Axe | La question | Exemples | Ce qu'il porte |
|---|---|---|---|
| **Race** | qui tu **es** | humain, elfe, nain · loup, mouton, corbeau · vampire, spectre | talent **passif**, réputation, hérédité, morphologie, `lifespan` |
| **Classe** | ce que tu **sais** | guerrier, mage, forgeron, marchand · éliotrope, nécromancien | talent **actif** (capacité hors slots), kit de départ |
| **Fonction** | ce que tu **fais** | aventurier, artisan, commerçant, garde, roi | agenda, routine horaire, rendement, place sociale |

**Exemples canoniques :** un *elfe · éliotrope · aventurier* · un *humain · forgeron · artisan* (il craft et vend sa production) · un *humain · marchand · commerçant* (il achète et revend) · un *mouton · —— · bétail*.

## Les trois règles qui empêchent les axes de se confondre

1. **La race est subie, la classe est agie.** On n'active pas « brûler au soleil » ; on active un portail.
2. **La race, le monde la voit ; la classe, toi seul.** La [[Réputation et relations|réputation par race]] existe déjà : devenir vampire change la façon dont les villageois te traitent, sans une ligne de code nouvelle.
3. **Tout être a une race. Seuls les êtres pensants ont une classe. Tous ceux qui occupent le monde ont une fonction.**

## Ce que ça fusionne et ce que ça absorbe

**La race absorbe l'espèce.** Deux champs faisaient le même travail — `race` ([[Schéma créature]]) et `espece` ([[Blocs de l'être]]). Ils n'en font plus qu'un. Un loup a pour race « loup », et la réputation par race se met à valoir pour les bêtes : *les loups se souviennent de toi*. Gratuit.

**La classe devient un bloc, présent ou absent.** Un mouton n'en a pas — **jusqu'à ce qu'il en ait**. Si sa lignée sélectionnée ([[Règle d'anneau]]) monte assez d'Intelligence (`esprit.intelligence ≥ 8`), il peut en apprendre une. C'est exactement le mouton ultime de [[Blocs de l'être]] : *une conséquence atteinte, jamais une permission accordée*.

**La fonction absorbe `agenda.métier`, les 11 postes de travail et `leadership_role`.** La fonction d'un roi, c'est « roi ». Un seul catalogue. Voir [[Fonctions]].

> **Attention à ne pas confondre `role` et `fonction`.** Le `role` ([[Rôles de l'être]] : sauvage → apprivoisé → résident → garde → bétail) dit ta **place vis-à-vis du joueur** ; la fonction dit ton **occupation dans le monde**. Un forgeron peut être `résident` ou `sauvage` sans changer de fonction.

## Le corollaire : le joueur n'est pas spécial

Si chaque PNJ porte les trois axes, alors **rien ne distingue structurellement le personnage joueur d'un PNJ** — sinon un drapeau de contrôle. C'est ce qui rend possible, plus tard, de **changer de personnage principal** ([[Ouvert — Changer de personnage]]), et c'est désormais une contrainte d'architecture permanente ([[Contraintes permanentes]], règle 5).

## Liens
- **Dépend de** : [[Blocs de l'être]], [[Schéma unifié créature-PNJ]]
- **Alimente** : [[Talents de race]], [[Talents de classe]], [[Fonctions]], [[Schéma créature]], [[Contraintes permanentes]]
- **Voir aussi** : [[Races]], [[Classes]], [[Rôles de l'être]], [[Réputation et relations]], [[Ouvert — Changer de personnage]]
