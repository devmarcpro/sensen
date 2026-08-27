---
aliases: ["14.4", "14.4 Statut de royaume", "Gouvernance", "Lois", "Diplomatie", "Types de gouvernance"]
tags: [société, endgame, décidé]
domaine: société
statut: décidé
etape: 10
---

Le territoire du joueur devient mécaniquement un royaume à part entière — avec sa gouvernance, ses lois (dont des lois absurdes assumées) et sa diplomatie.

- **Le territoire du joueur devient mécaniquement un royaume à part entière**, au même titre que les royaumes PNJ : il entre dans le système de réputation par royaume ([[Réputation et relations]]) et peut être perçu/traité comme tel par les autres.

**Répartition dans le monde :** les royaumes sont des **îlots de civilisation** séparés par de vastes terres sauvages **sans lois ni douanes** (la wilderness est l'anarchie de fait). Toutes les tailles existent, du hameau-État à la grande puissance dont la capitale s'étale sur plusieurs cellules ; chaque royaume a une **race dominante** (selon le biome de sa capitale — ~90 % de la population, et l'exclusivité des rôles de gouvernance), les autres races y étant présentes mais rares et jamais au pouvoir. Génération complète en [[Génération des royaumes PNJ]].

**Types de gouvernance (par royaume, y compris celui du joueur) :** chaque royaume a un **type de gouvernance** qui détermine sa règle de succession (déjà posée en [[Familles et succession]]), son niveau de taxes, ses politiques commerciales, et surtout **ses propres lois**. Types de départ :
- **Monarchie héréditaire** — succession par héritier.
- **République/démocratie élue** — succession par le second en rang ; taxes modérées, lois généralement stables.
- **Théocratie** — gouvernée par une figure religieuse ; lois souvent strictes, liées à un culte (interdits alimentaires, jours sacrés).
- **Ploutocratie / guilde marchande dirigeante** — le plus riche/la guilde de commerce gouverne ; taxes élevées mais commerce très favorisé, peu de lois hors affaires.
- **Dictature militaire** — taxes élevées (effort de guerre), lois strictes, défenses ([[Défense et raids]]) renforcées par défaut.
- **Anarchie** — **pas de gouvernement central, pas de leadership_role, pas de succession** ([[Familles et succession]] ne s'applique pas) : peu ou pas de lois, notamment **le meurtre y est légal** (aucune conséquence légale — voir plus bas). En contrepartie : pas de garde organisée, défenses de zone faibles par défaut, corruption locale ([[Dérive de la corruption]]) généralement plus haute.

**Lois propres à chaque royaume (`data/kingdoms/*.json`, [[Schéma royaume]]) :** chaque royaume définit sa propre liste de lois — comportements et objets légaux ou illégaux, **totalement indépendante des autres royaumes**. Deux catégories :
- **Lois cohérentes avec la gouvernance** : ex. vol illégal partout sauf en anarchie, port d'armes réglementé en théocratie.
- **Lois arbitraires/absurdes** (flavor assumé, dans l'esprit Elona/Elin) : un royaume peut interdire un objet sans raison apparente — ex. **la pomme est totalement illégale** dans tel royaume. Simple à générer (piocher un item courant + statut illégal), grande valeur comique et mémorable pour un coût de contenu quasi nul.

**Détection et conséquences :** une infraction n'a de conséquence que si elle est **repérée** (jet de Discrétion / cône de détection des PNJ à proximité, [[IA des créatures]] — cohérent avec le vol/la contrebande). Conséquences possibles par loi (`consequence` dans les données) : amende automatique, confiscation de l'objet, hostilité immédiate des gardes locaux, ou simple impact sur la réputation par royaume ([[Réputation et relations]]). Un royaume sans gardes (anarchie) ne peut mécaniquement pas faire appliquer ses lois — la loi y est décorative par construction. Détail : [[Lois et infractions]].

**Politiques commerciales (import/export) :** chaque royaume applique des **taxes douanières** par catégorie de matériau (au-delà des taxes de guilde/entretien déjà posées en [[Économie — sources et puits]]), pouvant aller jusqu'à l'**interdiction totale** d'un bien. Conséquences gameplay :
- Raccord avec la guilde **Transporteurs/Navigateurs** ([[Quêtes et guildes]]) : les routes commerciales inter-royaumes deviennent un vrai calcul économique (où vendre, où passer).
- **Contrebande** émergente : transporter un bien interdit à travers une frontière est risqué (détection = confiscation/hostilité) mais lucratif — sans système dédié, juste la combinaison des lois + Discrétion + commerce déjà posés.

- **Diplomatie :** le joueur peut passer des **accords avec les autres royaumes** (commerce, non-agression, alliance...) — la gouvernance du royaume visé influence ce qui est proposable (une dictature militaire négocie différemment d'une république).

**Décisions :**
- **Conséquences légales : résolu ([[Lois et infractions]])** — 3 types (`amende:N`, `confiscation`, `gardes_hostiles`) + impact de réputation systématique proportionnel à la sévérité. Sévérités par défaut : objet interdit → confiscation · vol → amende · violence/meurtre → gardes hostiles.
- **Accords diplomatiques (4 types, disponibilité selon gouvernance) :** *Accord commercial* (tarifs douaniers −50 % réciproques — favorisé par ploutocratie/république) · *Non-agression* (aucun raid entre les deux — accessible à tous sauf anarchie, qui ne peut rien garantir) · *Alliance défensive* (renforts PNJ lors des raids subis, [[Raids et menaces]] — république/monarchie) · *Tribut* (paiement hebdomadaire contre paix — exigé typiquement par dictature militaire ; le joueur peut aussi l'exiger d'un royaume faible).
- **Gouvernance du royaume du joueur : choisie par le joueur** à la fondation (seuil [[Défense et raids]]), **changeable** ensuite (délai de transition 4 semaines avec malus d'humeur temporaire −10 sur la population — les régimes ne changent pas sans friction).

**Fenêtre d'opportunité ([[Familles et succession]]) :** pendant une vacance de trône, une conquête bénéficie d'un DD réduit de 25 %.

> [!success] Codé le 2026-08-28 — étape 10.3, la gouvernance du joueur
> Les six types sont un catalogue `data/governments/` (`base_rate`, `defense_mult`, `succession`, `meurtre_legal`, `leadership`) — décision : un catalogue à part, les royaumes (`data/kingdoms/`) y font référence par `government_type`. Au seuil 8 cellules + 5 résidents, le territoire devient royaume en **monarchie héréditaire** par défaut ; changement dans l'écran de gestion (G) : **transition de 4 semaines**, **−10 d'humeur** immédiat ; l'entretien est multiplié par `base_rate / 0,08`. Lois, douanes, diplomatie : 10.4.

## Liens
- **Dépend de** : [[Expansion territoriale]], [[Schéma royaume]], [[Familles et succession]], [[Réputation et relations]]
- **Alimente** : [[Lois et infractions]], [[Défense et raids]], [[Génération des royaumes PNJ]], [[Raids et menaces]]
- **Voir aussi** : [[Conquête de village]], [[Économie — sources et puits]], [[Quêtes et guildes]], [[IA des créatures]], [[Dérive de la corruption]], [[Habitat des PNJ]], [[Dialogue PNJ]]
