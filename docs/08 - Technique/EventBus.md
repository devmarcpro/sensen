---
aliases: ["E.12", "Annexe E.12", "EventBus", "Signaux", "Signaux standards"]
tags: [technique, architecture, décidé]
domaine: technique
statut: décidé
etape: 0
---

La table des signaux standards — et la règle de couplage qui rend l'interaction inter-systèmes possible sans dépendances.

| Signal | Émis par | Écouté par (exemples) |
|---|---|---|
| `block_placed/destroyed` | monde | pièces ([[Détection de pièces]]), quêtes bâtisseur, réseau |
| `creature_killed` | combat | quêtes, XP, réputation, loot |
| `item_crafted` | craft | quêtes artisan, XP artisanat |
| `item_sold` | économie | or, réputation marchande |
| `skill_level_up` | skills | UI, niveaux dérivés ([[Double niveau combat et général]]), guildes |
| `creature_recruited` | relations | royaume (population), habitat |
| `book_read` | lecture | modules, effets d'échec |
| `raid_resolved` | [[Abstraction hors-site]]/[[Raids et menaces]] | journal, réputation |
| `cell_role_changed` | claims | régénération, restrictions |
| `locale_changed` | réglages | toute l'UI (rafraîchissement des textes) |
| `chunk_explored` | [[IA des créatures]] (détection) | minimap ([[Minimap et brouillard de guerre]]) |
| `dungeon_cleared` | [[Génération de donjon]] (mort du boss) | timer de disparition, quêtes de guilde ([[Quêtes et guildes]]) |

**Règle :** aucun système n'appelle directement un autre système de gameplay ; tout couplage passe par les données (tags) ou l'EventBus.

**Autres signaux cités ailleurs :** `damage_dealt` et `skill_xp_gained` ([[Pipeline de résolution du combat]], [[Décisions d'architecture]]), `leadership_changed` ([[Conquête de village]]), `item_possessed` et `border_crossed` ([[Lois et infractions]]).

**Dispatch ([[Boucle de tick]]) :** phase 3 d'un tick — dispatch des événements émis pendant les phases 1-2.

**Abonnements pour les affixes ([[Loot — affixes, gemmes et rareté]]) :** StatModifiers + compteurs par objet + abonnements EventBus — trois mécanismes existants.

**Onboarding ([[Tooltips contextuels]]) :** un système léger abonné à l'EventBus.

> [!success] Constaté le 2026-09-03 — les signaux ont été codés sous d'autres noms, ou pas comme des signaux
> Les noms proposés ici étaient des intentions. Dans `autoload/event_bus.gd` : `tile_destroyed` est devenu `tile_changed` (toute mutation de tuile) ; `border_crossed` est `fenetre_recentree` (la fenêtre du monde glisse) ; `item_crafted` et `item_possessed` **n'existent pas** — les quêtes de fabrication et de possession avancent par un appel direct, `_progresser_quetes`, pas par un signal, et rien ne le regrette. Les signaux qui existent vraiment : `damage_dealt`, `creature_killed`, `skill_xp_gained`, `skill_level_up`, `combat_started`, `combat_ended`, `expedition_terminee`, `chunk_explored`, `sauvegarde_faite`, `item_sold`, `dungeon_cleared`, `quest_completed`, `creature_recruited`, `cell_claimed`, `cell_role_changed`, `raid_resolved`, `leadership_changed`, `village_conquered`, `explosion`, `action_engaged`, `action_resolved`, `journal`, `book_read`, `controle_change`, `tile_changed`.

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Data-driven design]], [[Arborescence du projet]]
- **Alimente** : [[Détection de pièces]], [[Tooltips contextuels]], [[Gabarit de quête]], [[Minimap et brouillard de guerre]], [[Lois et infractions]], [[Résolveur de modificateurs]]
- **Voir aussi** : [[Boucle de tick]], [[Pipeline de résolution du combat]], [[Localisation]], [[Loot — affixes, gemmes et rareté]], [[Conquête de village]]
