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

> [!success] Étape 11 — non commencé, trace ajoutée le 2026-09-04
> Rien du transport réseau n'est écrit, et c'est voulu : l'étape 11 attend le jugement humain du solo ([[Ordre de construction]]). Ce que la note range en « solo déjà compatible » (simulation déterministe, host autoritaire, mutations de tuiles discrètes — `tile_changed`) est en place.

> [!info] Décisions du designer, 2026-09-13 (« je veux que le jeu soit coop »)
> - **La coop est confirmée comme cible, mais elle reste à l'étape 11**, après le jugement du solo — pas de réseau maintenant.
> - **La pause n'existe qu'en solo.** Seul, un écran ouvert fige le monde comme aujourd'hui ; à plusieurs, rien ne se fige, et en donjon chacun agit à son tour de ticks — le monde attend celui qui doit jouer.
> - **En ligne, hôte + invités** (ENet, par IP), sans écran partagé et sans serveur dédié — la décision d'origine tient.
> *Conséquence pour tout le travail d'ici là* : ne rien écrire qui suppose un seul joueur (voir [[Contraintes permanentes]]) ; toute pause passe par une seule garde « partie solo ».

> [!warning] Audit du 2026-09-13 — ce qui casserait à deux joueurs sur un même hôte
> **Le verrou n'est pas le réseau, c'est le LIEU.** La simulation ne tient qu'**un lieu à la fois** (`sim.lieu`, `sim.grille`, `sim.donjon` uniques) : descendre un escalier (`charger_donjon`, `_reinitialiser`) décharge tous les autres êtres, les autres joueurs compris, et la fenêtre du monde se recentre sur chaque joueur tour à tour. ~60 lectures de `sim.lieu == "camp"` s'en servent d'interrupteur. **C'est le gros morceau de l'étape 11 : plusieurs lieux vivants à la fois** (grille, êtres et horloges par lieu) — estimé 1 500 à 3 000 lignes sur ~15 fichiers.
> **Autres points, du plus lourd au plus léger :**
> - *Un territoire et une fiche pour tous* : `SimTerritoire._joueur` prend le premier joueur, `territoires.joueur` est codé en dur, `fiche_joueur` est unique ; l'expédition, `camp_sauve` et la carte découverte sont globaux.
> - *Les horloges* : en donjon (mode action), le plus lent fait attendre tout le monde ; en temps réel, un joueur dû qui n'agit pas semble retenir la file (`simulation.gd:445,460`) — **à confirmer par un test à deux joueurs**. Les horloges de combat sont avancées par le client.
> - *Environ 40 gestes du client écrivent dans la simulation sans passer par une intention* (gestion, dialogue, voyage, triche, composition de sorts, hotbar, avance du temps) — ~25 types d'intention à créer.
> - *Les pauses* : écran principal, chargement, écran ouvert, et « dormir saute la nuit » avance l'horloge commune — à ranger sous une seule garde « partie solo » (décision du 2026-09-13).
> - *La sauvegarde* n'écrit qu'un joueur (`players/joueur.json`), `expedition.json` n'a qu'un lieu.
> **Déjà prêt** : ids en chaînes, intentions (86 appels), file d'attente par être, `EventBus` à événements discrets (`tile_changed`…), `sim.joueurs()`, client qui suit SON joueur par `joueur_id`. *Manque* : un destinataire sur `journal` et `expedition_terminee`.
> **Ordre proposé** : plusieurs lieux → les pauses → les intentions → la sauvegarde → puis le transport.

## Liens
- **Dépend de** : [[Contraintes permanentes]], [[Construction cadrée]], [[Temporalités parallèles]]
- **Alimente** : [[Réseau]], [[Sauvegarde]], [[Début de partie]]
- **Voir aussi** : [[Quêtes et guildes]], [[Dialogue PNJ]], [[Éditeur de sculpture]], [[L'information comme récompense]], [[Cycle jour-nuit et sommeil]], [[Risques majeurs]], [[Réseau et sauvegarde — performance]], [[Public visé]]
