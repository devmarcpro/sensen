---
aliases: ["Rôles de cases", "Zonage", "Zonage des claims"]
tags: [monde, territoire, décidé]
domaine: monde
statut: décidé
etape: 7
---

Le zonage : quatre rôles mécaniques assignables à chaque case revendiquée, changeables à tout moment.

Le joueur peut assigner un **rôle** à chaque case revendiquée ([[Claims et persistance]]), et en **changer librement à tout moment**. Le rôle est **mécanique et porte des restrictions** — il change le comportement de la case, pas juste son étiquette :

| Rôle | Comportement |
|---|---|
| **Base** | Cœur du territoire — constructions persistantes, toutes activités autorisées |
| **Habitation** | Logements des PNJ résidents (voir [[Habitat des PNJ]]) |
| **Champs** | Agriculture/élevage (voir [[Agriculture et élevage]]), assignation de PNJ fermiers |
| **Ressources naturelles** | La case **garde la régénération hebdomadaire des cases sauvages** malgré le claim — réserve d'exploitation renouvelable (récoltable en boucle, notamment par les PNJ assignés, [[Population et exploitation]]). Restriction : pas de construction lourde (elle serait effacée par la régénération). |

**Décisions :**
- **Restrictions par rôle :** Base = tout autorisé · Habitation = tout autorisé, seules les pièces de ce rôle comptent pour la capacité de logement ([[Habitat des PNJ]]) · Champs = constructions légères uniquement (pas de station lourde), parcelles agricoles actives · Ressources naturelles = **aucune construction** (tout bâti y est effacé à la régénération), récolte et assignation de PNJ uniquement.
- **Changement de rôle vers "ressources naturelles" sur case construite :** dialogue de confirmation explicite listant ce qui sera effacé — obligatoire, pas contournable.
- **Autres rôles :** non au lancement — les quatre couvrent les usages (la défense et le commerce vivent sur les cases Base/Habitation) ; le champ `role` en données reste extensible.

**Signal :** `cell_role_changed` sur l'EventBus, écouté par la régénération et les restrictions ([[EventBus]]).

## Liens
- **Dépend de** : [[Claims et persistance]]
- **Alimente** : [[Habitat des PNJ]], [[Agriculture et élevage]], [[Population et exploitation]], [[Expansion territoriale]]
- **Voir aussi** : [[EventBus]], [[Écrans d'interface]], [[Tooltips contextuels]]
