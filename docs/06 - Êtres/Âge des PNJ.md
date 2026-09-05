---
aliases: ["12.2", "12.2 Âge des PNJ", "Âge", "Vieillesse", "Naissances", "Démographie"]
tags: [êtres, simulation, décidé]
domaine: êtres
statut: décidé
etape: 9
---

La population du monde est un flux, pas un stock : les PNJ vieillissent, meurent, naissent — les rois aussi.

- Chaque PNJ a un **âge** (champ d'instance, en années in-game), qui avance avec le calendrier : **1 an in-game = 120 jours in-game** (soit 80 heures de temps réel à 40 min/jour, [[Boucle de tick]]) — **valeur fixée**.
- **Catégories d'âge** (modulent l'apparence via les parties de sprites et les stats) : jeune → adulte → âgé. Les PNJ âgés perdent progressivement en stats physiques (**−10 % par tranche au-delà du seuil**) mais leurs compétences acquises restent — un vieux forgeron reste un maître.
- **Mort de vieillesse :** au-delà de l'espérance de vie de sa race (donnée `lifespan` par race, avec variance **±15 %**), un PNJ a une chance croissante par semaine de mourir naturellement (hors écran : résolu à l'échéance, timer wheel [[Simulation du monde — performance]]). Sa mort déclenche la **succession** ([[Familles et succession]]) s'il portait un rôle, et l'héritage familial de ses biens.
- **Naissances :** les couples de PNJ (champ `spouse`) peuvent avoir des enfants (nouvelle instance liée par `family`, catégorie jeune), qui grandissent et prennent des jobs à l'âge adulte — c'est le moteur démographique interne des villages, complémentaire de l'immigration ([[Conquête de village]]). Les jeunes PNJ ne sont ni recrutables ni assignables.
- **Conséquence design :** la population du monde est un flux, pas un stock — les rois meurent aussi de vieillesse (la succession n'est pas qu'une affaire d'assassinat), les lignées existent réellement, et un compagnon mortel vieillit (son espérance de vie raciale s'applique — attachement et renouvellement).

**Signe astrologique dérivé gratuitement ([[Astrologie — cycle sexagésimal]]) :** les PNJ ayant déjà un âge, leur signe (élément + animal) en dérive sans donnée supplémentaire.

**Mariages et rivalités ([[Astrologie — cycle sexagésimal]]) :** les compatibilités s'appliquent **entre PNJ** — les mariages suivent statistiquement les trines, les rivalités les oppositions.

**Nom de famille hérité ([[Génération de noms]]) :** un PNJ avec un parent hérite du nom de famille de celui-ci.

**Information visible ([[L'information comme récompense]]) :** l'âge d'un PNJ se révèle au palier de relation 20-49 ; les liens familiaux à 50-74.

> [!success] Codé le 2026-08-28 — étape 9.D
> `age` (années) et `lifespan` (espérance raciale ±15 %) tirés à l'instanciation des PNJ civils (`combat_rules.age` : humain 80, adulte à 18, âgé à 60 ; âge de départ 18-60), **1 an = 120 jours** ; le passage hebdomadaire fait vieillir (+7/120 an) ; au-delà de l'espérance, **chance croissante par semaine** de mourir de vieillesse (5 % par an d'écart) ; les âgés perdent **10 % de stats physiques par tranche de 10 ans** au-delà du seuil, leurs compétences restent. L'âge et la catégorie s'affichent au palier 20-49. Naissances, mariages et succession attendent l'étape 10.

> [!success] Mis à jour le 2026-08-31 — l'étape 10 est passée par là
> Les **naissances** (le repeuplement d'un village est l'enfant d'un couple) et la **succession** (héritier, vacances de trône et de hall) sont codées — callouts de [[Familles et succession]]. Seuls les mariages en cours de partie attendent encore.

> [!success] Codé le 2026-09-05, 15 h — le signe et l'anniversaire des PNJ (Calendrier)
> Le signe promis « gratuitement » n'était pas calculé : à l'instanciation, un PNJ sans signe de fiche reçoit celui de son année de naissance (l'année courante du calendrier moins son âge, `Progression.signe`), et un anniversaire (mois et jour tirés de son identifiant). L'âge continue d'avancer par semaine (7/120 d'année) : l'anniversaire est un jour du calendrier, pas le compteur de l'âge. [[Un monde réel — villes, PNJ, royaumes et calendrier]].

## Liens
- **Dépend de** : [[Schéma créature]], [[Races]], [[Boucle de tick]]
- **Alimente** : [[Familles et succession]], [[Villages PNJ — repeuplement et décimation]], [[Génération de noms]], [[Compagnons]]
- **Voir aussi** : [[Astrologie — cycle sexagésimal]], [[Squelette modulaire et points d'attache]], [[Simulation du monde — performance]], [[L'information comme récompense]], [[Population et exploitation]]
