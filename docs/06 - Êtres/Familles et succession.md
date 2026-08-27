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

> [!success] Codé le 2026-08-28 — étape 10.5, la succession sans famille
> La capitale d'un royaume à `leadership` accueille un PNJ **dirigeant** (fonction `dirigeant`, portefeuille 2 000) près de la place. Sa mort (`creature_killed`) ouvre une **vacance** de 4 semaines (`Monde.vacances[royaume]`) ; à l'échéance, le successeur est le PNJ vivant du même royaume au **niveau général le plus haut** parmi ceux instanciés (« next_in_rank » — l'héritier familial attend les familles) ; sans candidat la vacance se prolonge. Signal `leadership_changed`. Pendant la vacance : DD de conquête −25 %, aucun raid de ce royaume. Le nommage est unifié : **la fonction `dirigeant` est `leadership_role`**.

> [!success] Codé le 2026-08-28 — les familles, l'héritier, les maîtres de guilde, les titres
> **Familles** (`family` : `parent_of`, `child_of`, `spouse`) formées à l'instanciation d'un village, **par bâtiment** : le plus âgé est le parent, le second adulte son conjoint, les autres deviennent des **enfants** (âge tiré entre 5 et 17 ans). Le **repeuplement** est désormais une **naissance** : le nouveau-né est l'enfant d'un couple du village. **Succession** : la mort d'un dirigeant mémorise l'**héritier** (`Monde.heritiers` : l'aîné vivant de ses enfants) si la gouvernance a `succession: heritier` ; à l'échéance il monte, sinon `next_in_rank` (le plus haut niveau général du royaume) ; **maître de guilde** mort → vacance de **2 semaines** (`Monde.vacances_guildes`, clé `guilde|village`), puis le plus haut niveau général du village reprend le hall. Le nouveau titulaire reçoit le **titre de sa culture** selon la gouvernance (`name_cultures.titres`, m/f) — affiché dans le dialogue. Prêtres : pas encore de rôle.

## Liens
- **Dépend de** : [[Schéma créature]], [[Âge des PNJ]], [[Réputation et relations]]
- **Alimente** : [[Conquête de village]], [[Gouvernance, lois et diplomatie]], [[Génération de noms]], [[Quêtes et guildes]]
- **Voir aussi** : [[Schéma royaume]], [[Compagnons]], [[Astrologie — cycle sexagésimal]], [[EventBus]], [[Simulation du monde — performance]]
