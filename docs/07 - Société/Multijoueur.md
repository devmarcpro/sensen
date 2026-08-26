---
aliases: ["8", "8. Multijoueur", "Multijoueur", "Coop", "PvP"]
tags: [société, réseau, décidé]
domaine: société
statut: décidé
etape: 11
---

Coopératif host-and-join, 4 à 8 joueurs, PvP restreint au duel consenti.

- **Mode :** coopératif, groupes de **4 à 8 joueurs**.
- **Modèle réseau : host-and-join façon Terraria** — un joueur héberge la partie, les autres le rejoignent. Pas de serveur dédié requis, réaliste pour un développement solo.
- **Simplifié par l'abandon de la physique de destruction fine ([[Construction cadrée]])** : la destruction à la tuile se synchronise comme un événement discret (« cette tuile a été modifiée »), exactement comme Terraria/Minecraft — beaucoup plus simple qu'une simulation physique continue à synchroniser.
- Recommandation technique : s'appuyer sur l'**API multijoueur haut niveau de Godot** (moteur confirmé — voir [[Data-driven design]]) plutôt que développer le réseau from scratch.
- **PvP : restreint** — uniquement via duel accepté entre joueurs, pas de PvP ouvert/non consenti.

**Contrainte permanente ([[Contraintes permanentes]]) :** *une partie solo EST une partie multijoueur hébergée dont la porte est fermée.* Ce n'est pas du contenu réseau — c'est une discipline d'architecture, respectée dès la première ligne de code.

**Ce qui reste légitimement en étape 11 :** le transport réseau, la découverte de parties, la latence, la reconnexion, l'interpolation. Cela s'ajoute sans rien casser — à condition que les contraintes permanentes soient respectées.

**Temporalités parallèles ([[Temporalités parallèles]]) :** un joueur qui gère la base n'attend personne pendant que deux autres combattent.

**Spawn des invités ([[Début de partie]]) :** près du joueur host (ou à un point de ralliement défini par le host), avec leur propre personnage importé.

**Sauvegarde ([[Sauvegarde]]) :** seul le host possède la sauvegarde ; les invités gardent localement leur personnage (import à la connexion, exporté à la déconnexion).

**Partage :** modèles sculptés ([[Éditeur de sculpture]], catalogue de groupe sur action explicite) et informations débloquées ([[L'information comme récompense]]).

**Vote ([[Cycle jour-nuit et sommeil]]) :** saut de nuit — majorité simple, tous dans un lit ou hors combat.

**Guilde Gladiateurs ([[Quêtes et guildes]]) :** tournois, arène — lié au PvP en duel.

**Option de dialogue ([[Dialogue PNJ]]) :** `[Duel]` (autre joueur — PvP consenti).

**Détail technique :** [[Réseau]] et [[Réseau et sauvegarde — performance]].

## Liens
- **Dépend de** : [[Contraintes permanentes]], [[Construction cadrée]], [[Temporalités parallèles]]
- **Alimente** : [[Réseau]], [[Sauvegarde]], [[Début de partie]]
- **Voir aussi** : [[Quêtes et guildes]], [[Dialogue PNJ]], [[Éditeur de sculpture]], [[L'information comme récompense]], [[Cycle jour-nuit et sommeil]], [[Risques majeurs]], [[Réseau et sauvegarde — performance]], [[Public visé]]
