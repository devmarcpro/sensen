---
aliases: ["E.25", "Annexe E.25", "Conquête", "Conquête de village"]
tags: [monde, société, territoire, décidé]
domaine: monde
statut: décidé
etape: 10
---

Annexer un village sans exterminer sa population — et la spécification technique qui couvre repeuplement, décimation, conquête et succession.

**Conquête (distincte de la décimation — pas besoin de tuer pour conquérir) :** le joueur peut annexer un village à son royaume ([[Expansion territoriale]]) sans exterminer sa population :
- **Condition :** réduire les défenses du village (gardes vivants × leur niveau de combat) sous 25 % de leur valeur nominale.
- **Action :** revendiquer le village au bâtiment central (mairie/hall) — jet de compétence universel ([[Jet de compétence universel]]) : `1d20 + Leadership/2 + Charisme/4 vs DD = population du village * 2`.
- **Succès :** le village rejoint le royaume du joueur ; sa population existante devient gérable comme des PNJ recrutés (jobs [[Population et exploitation]], logements déjà en place). Impact de réputation fort et variable (positif si le village appartenait à un royaume hostile au joueur — perçu comme libération ; négatif si le royaume d'origine était neutre ou allié — perçu comme agression).
- **Échec :** réputation locale négative, les défenses se régénèrent partiellement.

**Décision :**
- **Reprise d'un village conquis : oui** — le royaume d'origine, s'il reste hostile et puissant, peut lancer un **raid de reconquête** (pipeline [[Raids et menaces]] standard, cible = le village annexé) ; en cas de victoire du raid non défendu, le village retourne à son royaume d'origine. La diplomatie ([[Gouvernance, lois et diplomatie]]) permet d'acheter la paix à la place.
- **Crise de succession exploitable : oui** ([[Familles et succession]]) — pendant une vacance (héritier absent ou délai de transition en cours), une **conquête bénéficie d'un DD réduit de 25 %** sur le territoire concerné ; revendiquer un trône vacant soi-même passe par ce même pipeline. Soutenir un prétendant = extension future (contenu, pas système).

**Spécification technique complète (E.25) :**

```
CAPACITÉ DE VILLAGE — même détection de pièces que l'habitat (E.5),
  appliquée à tous les bâtiments du village au chargement/à la
  construction ; capacité = Σ pièces habitables valides.

REPEUPLEMENT — passage hebdomadaire (même liste que E.20/3.3/7.6) sur
  les villages sous capacité :
    chance_repop = 0.15 * (1 - population/capacite)
                   * (1 - corruption_locale_effective/100)   (E.20)
  Succès : instancie un PNJ générique depuis le pool du village
  (F.3-like), assigné à un job vacant (14.2) ou "villageois" par défaut.

DÉCIMATION — population atteint 0 : le village passe en état ABANDONNÉ
  (flag sur le POI) — bâtiments/meubles conservés (persistants, comme
  un claim), plus aucun PNJ, plus de génération de repop tant qu'un
  résident (joueur-assigné ou repop naturelle très lente) ne s'y
  réinstalle. Réutilisable directement par le joueur (7.5 : logements
  déjà valides).

CONQUÊTE — condition : Σ(niveau_combat des gardes vivants) < 25 % de
  la valeur nominale du village. Action au bâtiment central : jet
  universel (E.3) 1d20 + Leadership/2 + Charisme/4 vs DD = population*2.
  Succès : le village change d'allégeance (champ `royaume_id` du POI
  → royaume du joueur, 14.4) ; sa population reste en place, devient
  gérable (jobs 14.2). Réputation : delta fort sur la réputation par
  royaume ET par race concernées (7.2), signe dépendant de la relation
  préalable joueur/royaume d'origine (libération vs agression).
  Échec : réputation locale -X, défenses régénèrent +50 % sur 2 semaines.

SUCCESSION (PNJ à `leadership_role` non nul, mort) :
  Déclenché par l'événement `creature_killed` (E.12) sur une entité à
  leadership_role != null → programme un événement à délai (timer wheel,
  G.6) de durée `transition_semaines` (donnée du rôle : 2 pour une
  guilde, 4 pour un royaume) :
    succession_rule = "heir"      → cherche family.parent_of trié par
       âge/ancienneté, sinon fallback "next_in_rank"
    succession_rule = "next_in_rank" → PNJ de plus haut niveau général
       (6.0) parmi ceux partageant le même royaume_id/guild_id
    Aucun candidat → vacance prolongée (flag narratif, pas de reroll
       automatique — laissé à disposition du joueur/futur contenu)
  À la résolution : le nouveau titulaire hérite de `leadership_role`,
  `EventBus.leadership_changed` émis (quêtes de guilde débloquées à
  nouveau, diplomatie 14.4 mise à jour).
Coût : ces trois systèmes ne tournent que sur des POI/entités
  concernés, cadence hebdomadaire — négligeable (cohérent avec G.6).
```

## Liens
- **Dépend de** : [[Villages PNJ — repeuplement et décimation]], [[Jet de compétence universel]], [[Détection de pièces]]
- **Alimente** : [[Expansion territoriale]], [[Familles et succession]], [[Réputation et relations]]
- **Voir aussi** : [[Raids et menaces]], [[Gouvernance, lois et diplomatie]], [[Simulation du monde — performance]], [[EventBus]]
