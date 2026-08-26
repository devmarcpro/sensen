---
aliases: ["12.3", "12.3 Familles, statuts et succession", "Succession", "Familles", "Liens familiaux"]
tags: [êtres, société, décidé]
domaine: êtres
statut: décidé
etape: 10
---

Les liens familiaux ne sont pas décoratifs : ils pilotent la succession. Et tous les royaumes n'ont pas de roi.

**Liens familiaux :** au-delà des relations générales ([[Réputation et relations]]), un PNJ peut porter des liens de **famille** (parent/enfant/conjoint — champ `family` du schéma [[Schéma créature]]). Ces liens ne sont pas décoratifs : ils pilotent la succession — et la démographie ([[Âge des PNJ]]).

**Gouvernance et succession des PNJ uniques (rois, maîtres de guilde, prêtres...) :** leur mort est **définitive pour l'individu** (pas de résurrection façon compagnon, [[Compagnons]]) — mais le **rôle** qu'ils occupaient est repris selon la règle de succession propre à sa structure :
- **Monarchie héréditaire** ([[Gouvernance, lois et diplomatie]]) : l'héritier désigné (aîné des enfants, ou héritier explicitement nommé) monte sur le trône après un **délai de transition** (quelques semaines).
- **Conseil/démocratie** (autre type de gouvernance possible pour un royaume PNJ) : le second dans la hiérarchie (ex. premier ministre) prend la relève — même délai.
- **Guilde :** l'officier de plus haut rang après le maître devient le nouveau maître de guilde.
- **Règle générale :** tout PNJ avec un rôle de leadership porte un champ `succession_rule` (`heir` → PNJ désigné par lien familial, ou `next_in_rank` → PNJ de plus haut rang restant dans la même faction/lieu).
- **Vacance :** pendant le délai de transition, le poste est vide (conséquences visibles : pas de nouvelles quêtes de guilde, instabilité du royaume — fenêtre d'opportunité pour la diplomatie ou la conquête, [[Gouvernance, lois et diplomatie]]/[[Conquête de village]]).
- **Absence d'héritier ou de second** (lignée éteinte, guilde sans officier) : vacance prolongée, potentiel déclencheur narratif (crise de succession) — traité au cas par cas, pas de repeuplement magique automatique.
- **Tous les royaumes n'ont pas de roi** : le type de gouvernance (monarchie, conseil...) est une propriété du royaume (champ `government_type`, schéma [[Schéma royaume]]), pas une constante du jeu.

**Décisions :**
- **Délais de transition : résolu ([[Conquête de village]])** — guilde **2 semaines**, royaume **4 semaines**.
- **Données de royaume : résolu ([[Schéma royaume]])** — schéma complet (gouvernance, territoire, taxes, lois, diplomatie).
- **Crise de succession exploitable : oui** — pendant une vacance (héritier absent ou délai de transition en cours), une **conquête ([[Conquête de village]]) bénéficie d'un DD réduit de 25 %** sur le territoire concerné ; revendiquer un trône vacant soi-même passe par ce même pipeline. Soutenir un prétendant = extension future (contenu, pas système).

**Algorithme de résolution :** voir [[Conquête de village]] (bloc SUCCESSION de E.25) — déclenché par `creature_killed` sur une entité à `leadership_role != null`, timer wheel, émission de `EventBus.leadership_changed`.

**Titre attribué à l'obtention du rôle ([[Génération de noms]]) :** le nouveau titulaire reçoit le titre de sa culture selon le type de gouvernance.

## Liens
- **Dépend de** : [[Schéma créature]], [[Âge des PNJ]], [[Réputation et relations]]
- **Alimente** : [[Conquête de village]], [[Gouvernance, lois et diplomatie]], [[Génération de noms]], [[Quêtes et guildes]]
- **Voir aussi** : [[Schéma royaume]], [[Compagnons]], [[Astrologie — cycle sexagésimal]], [[EventBus]], [[Simulation du monde — performance]]
