---
aliases: ["Ouvert — Changer de personnage", "Changer de personnage", "Contrôle", "Incarnation"]
tags: [ouvert, êtres, architecture, à-trancher]
domaine: êtres
statut: à-trancher
etape: 11
---

> [!question] Feature future — mais contrainte d'architecture **immédiate**
> Le jeu ne construit pas ça maintenant. Mais **la 5ᵉ contrainte permanente** ([[Contraintes permanentes]]) existe pour que ce soit trivial le jour venu, au lieu d'être une réécriture.

Prendre le contrôle d'un autre être — un compagnon, un PNJ recruté, un mouton élevé.

## Pourquoi c'est déjà possible sur le papier

Tout est en place : [[Blocs de l'être]] fait de chaque être la même fiche, [[Les trois axes — race, classe, fonction]] donne à chacun une identité complète, et *rien n'est réservé* — un être porte une arme s'il a un slot de main, des modules s'il a l'intelligence.

**Il ne manque qu'un drapeau de contrôle.** C'est exactement ce que dit la contrainte : *le personnage joueur est une entité comme une autre ; le contrôle est un attribut, pas un type.*

## Ce que ça débloque

- **Jouer n'importe quelle espèce** ([[Talents de race]]) — non pas en la choisissant dans un menu, mais en **l'élevant** ([[Élevage — intention et familles]]) puis en l'incarnant. Le mouton jouable *est* le mouton ultime.
- **Continuer après une mort** autrement que par le respawn ([[Mort et pénalité]]).
- **Coop asymétrique** : un joueur mène l'aventurier, un autre gère la base par un résident ([[Multijoueur]]).

## Ce qui reste à trancher

**L'ancien corps.** Il continue de vivre comme PNJ (niveau logique du [[LOD de simulation]]) ? Il attend, inerte ? Il peut mourir en ton absence ?

**Ce qui est lié au joueur et non au corps.** Aujourd'hui, `players/*.json` ([[Sauvegarde]]) porte inventaire, compétences, claims, rangs de guilde, réputations. Certains suivent le **corps** (compétences, inventaire, réputation personnelle), d'autres le **compte** (claims, rangs de guilde ?). C'est la vraie question de conception — et c'est elle qui doit être tranchée **avant** d'écrire le format de sauvegarde, pas après.

**Le coût.** Gratuit ? Un rituel ? Une relation au plafond avec la cible ? Un mouton n'a pas d'avis ; un roi en a un ([[Rôles de l'être]] : *il part, ou il se retourne*).

**Les limitations comme contenu.** Incarner un quadrupède, c'est perdre les mains, la lecture et le dialogue. Il faut que l'interface le dise proprement plutôt que de griser dix boutons sans explication ([[Conditions de reproduction]] pose déjà la règle : *afficher la raison, jamais un bouton grisé muet*).

> [!success] Codé le 2026-08-28 — l'incarnation, tranchée au plus simple (réversible)
> Dialogue d'un **compagnon** (`maitre` = toi) → *Prendre le contrôle* : `Simulation._incarner` échange le drapeau `controle` — le nouveau corps devient `joueur`, **l'ancien corps devient un compagnon IA** (`maitre` = le nouveau corps, ordre *suivre*) qui vit, suit et peut mourir en ton absence (LOD logique, comme tout compagnon). **Ce qui suit le corps** : tout ce qui est sur l'entité (inventaire, compétences, réputations, talents) ; **ce qui reste au compte** : les claims, le territoire, les rangs de guilde — ils sont sur `Simulation.territoire`/`monde`, pas sur l'être, donc rien à déplacer. **Coût** : gratuit pour une bête (elle n'a pas d'avis), **relation ≥ 75** pour un humanoïde (il consent, c'est le seuil de l'enseignement). Le client suit le signal `controle_change`. **Les limitations comme contenu** : une silhouette non humanoïde n'équipe que `talents.incarnation.slots_bete` (amulette, anneaux, cuirasse = la barde), **ne lit pas** et **ne parle pas** — chaque refus a son message de journal (jamais un bouton grisé muet). Point de respawn : le nouveau corps hérite du `spawn` de l'ancien s'il n'en a pas.

## Liens
- **Dépend de** : [[Contraintes permanentes]], [[Blocs de l'être]], [[Les trois axes — race, classe, fonction]]
- **Alimente** : [[Talents de race]], [[Sauvegarde]], [[Multijoueur]]
- **Voir aussi** : [[Compagnons]], [[Rôles de l'être]], [[Élevage — intention et familles]], [[LOD de simulation]], [[Mort et pénalité]]
