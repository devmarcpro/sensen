---
aliases: ["Décision — Fuite et désengagement", "Ouvert — Fuite et désengagement", "Fuite", "Désengagement"]
tags: [combat, décidé]
domaine: combat
statut: décidé
etape: 0
---

> [!success] Décidé le 2026-08-26
> Tranché sur délégation du designer (« tout doit être rédigé et décidé avant production »). Le code s'appuie dessus ; révisable au playtest comme toute décision.

**La décision : trois seuils chiffrés — sortir, abandonner, semer.**

**Sortie de combat (côté joueur)** — on quitte l'horloge du combat ([[Temporalités parallèles]]) quand :
- on est à **plus de 12 tuiles** de tout ennemi engagé, **OU**
- la ligne de vue est rompue depuis **30 ticks** ([[Hauteur de terrain ±10]] : le relief coupe la vue — le dénivelé est l'outil de fuite).

**Perte d'intérêt (côté IA)** — une créature abandonne la poursuite quand :
- elle s'éloigne de **plus de 20 tuiles de son point d'ancrage** (tanière, point de spawn, poste de patrouille — champ `anchor` d'instance), **OU**
- elle n'a **plus de ligne de vue sur sa cible depuis 100 ticks**.
Elle retourne alors à son ancrage (action `retour` de son profil [[IA des créatures]]).

**Semer en Discrétion** — dès que la ligne de vue est rompue, le fuyard peut tenter un **jet opposé Discrétion vs Perception** ([[Jet de compétence universel]]) :
- **succès** → la créature perd la cible immédiatement (retour à l'ancrage) ;
- **échec** → elle se dirige vers la **dernière position connue** et reprend la poursuite si elle retrouve la ligne de vue.
La nuit donne +4 au jet de Discrétion ([[Cycle jour-nuit et sommeil]]).

**Cohérence :** les actions `fuir(...)` des profils utility ([[IA des créatures]]) utilisent les mêmes seuils en sens inverse — une bête qui fuit le joueur est semée par les mêmes règles.

> [!success] Codé — trace ajoutée le 2026-09-04
> Chaque être a un point d'ancrage (`e.ancre`) ; le désengagement rend la fin de combat (`fin_combat`), l'IA fuit sous son seuil (`fuite` dans les profils) et revient à l'ancre, l'aggro s'oublie avec le temps ([[IA des créatures]], 2026-09-03).

## Liens
- **Dépend de** : [[Temporalités parallèles]], [[IA des créatures]], [[Jet de compétence universel]], [[Trous connus du combat]]
- **Alimente** : [[Combat tactique sur grille]], [[Action-time à ticks]]
- **Voir aussi** : [[Hauteur de terrain ±10]], [[Cycle jour-nuit et sommeil]], [[Compétences — liste]]
