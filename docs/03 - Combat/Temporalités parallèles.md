---
aliases: ["Temporalités parallèles", "Horloges parallèles", "Coop temporalités"]
tags: [combat, temps, réseau, décidé]
domaine: combat
statut: décidé
etape: 0
---

Le monde a son horloge, chaque combat a la sienne, chaque donjon aussi. C'est ce qui permet à la coop de ne jamais bloquer personne — et c'est une notion du modèle dès le premier jour.

**TEMPORALITÉS PARALLÈLES (coop)** : le monde a son horloge (temps réel : exploration, cultures, économie), et **chaque combat en cours a la sienne**, qui n'avance qu'aux actions de ses participants. Un joueur qui gère la base n'attend personne pendant que deux autres combattent en réfléchissant autant qu'ils veulent. Les **donjons** ont également leur propre temporalité — une expédition de trois heures réelles ne doit pas faire passer trois mois de simulation dans le royaume.

- **Appartenance par la participation**, pas par une zone : être engagé (attaquer ou être attaqué) place dans l'horloge du combat ; s'en éloigner suffisamment en sort. Un joueur qui s'approche peut **rejoindre librement** — cohérent avec le combat in-situ, sans phase de placement ni instance fermée.
- **Le combat est hors du temps du monde** : on en ressort à l'instant où on y est entré. Petite incohérence assumée, en échange d'une coop qui ne bloque jamais personne.
- Une **horloge constante** (1 tick/s) reste disponible comme *option de partie*, jamais comme défaut : sous horloge, hésiter coûte, ce qui détruit le principe.

**Contrainte permanente ([[Contraintes permanentes]]) :** *Les temporalités parallèles sont une notion du modèle dès le départ : une horloge du monde, une par combat, une par donjon. Écrire une horloge unique globale en solo garantit de tout réécrire plus tard.*

> [!success] Codé depuis l'étape 0 — trace ajoutée le 2026-09-04
> L'horloge du monde et celle du combat sont deux objets ; un être appartient à l'une ou à l'autre (`e.horloge`, `horloge_de()`), le donjon vit en temps à l'action et le camp en exploration. Le monde ne tourne plus sans fin pendant un combat depuis le 2026-08-31 (voir [[Boucle de tick]]).

## Liens
- **Dépend de** : [[Action-time à ticks]], [[Contraintes permanentes]]
- **Alimente** : [[Multijoueur]], [[Décisions d'architecture]], [[Donjons — structure et intégration]]
- **Voir aussi** : [[Boucle de tick]], [[Réseau]], [[Simulation à ticks]]
