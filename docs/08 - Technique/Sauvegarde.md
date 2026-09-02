---
aliases: ["E.10", "Annexe E.10", "Sauvegarde", "Save", "Sauvegarde différentielle"]
tags: [technique, architecture, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!note] Adapté au pivot tactique
> Le format voxel (`chunks/x_y_z.bin`, octree sérialisé) est retiré — archivé dans le GDD source. Le format du diff de tuiles proposé : [[Décision — Structure de données de la grille]] ). Le principe est inchangé.

Le format de sauvegarde : un dossier par monde, seuls les chunks modifiés écrits.

```
Format : un dossier par monde.
  world.json          : seed, temps (ticks), réglages
  chunks/cx_cz.bin    : uniquement chunks modifiés — liste
                        (index_tuile, champs modifiés : hauteur/sol/contenu)
  dungeons/{id}/floor_n.bin : même format, par étage de donjon
  entities.json       : instances de créatures (état complet, cf. fiche §B.5)
  players/*.json      : inventaire, compétences+XP, position, modèles sculptés,
                        claims (rôles de cases), rangs de guilde, réputations
  abstract.json       : états abstraits hors-site (E.6), boutiques, royaume
Écriture : autosave toutes les 5 min réelles + sur événements clés,
écriture atomique (tmp + rename). Le multi : seul le host possède la
sauvegarde ; les invités gardent localement leur personnage (import à la
connexion, exporté à la déconnexion).
```

**Contrainte permanente ([[Contraintes permanentes]]) :** *l'état du monde est sérialisable en permanence — même exigence que la sauvegarde, payée une fois pour deux usages.*

**Principe général ([[Optimisation — principes]]) :** *tout est SEEDÉ et déterministe → jamais besoin de stocker ce qui est regénérable.*

**Stockages spécifiques :** delta de corruption par cellule ([[Dérive de la corruption]]), bitmask d'exploration par joueur ([[Minimap et brouillard de guerre]]), modèles sculptés ([[Éditeur de sculpture]]), état « vu » des tooltips ([[Tooltips contextuels]]), noms générés ([[Génération de noms]]), compétences d'instance des PNJ ([[Schéma créature]]).

**Donjons ([[Donjons — structure et intégration]]) :** les changements (morts, butin pris, tuiles détruites) suivent exactement la sauvegarde différentielle standard — *rien de nouveau à construire*.

**Performance ([[Réseau et sauvegarde — performance]]) :** sérialisation en thread, écriture atomique, l'autosave ne bloque jamais le jeu (copie-sur-écriture).

> [!success] Codé le 2026-08-28 — étape 8.2c, `systems/sauvegarde.gd`, `Simulation.sauvegarder / charger_sauvegarde`
> Le principe tel quel : **seed + liste des modifications**, un dossier par monde (`user://sauvegardes/<nom>/`), écriture atomique (tmp + rename). Fichiers : `world.json` (graine, temps en ticks, compteurs, cellule du camp), `surface.json` (par cellule : modifications de tuiles, tuiles découvertes, contenants, êtres endormis, chunks explorés — jamais ce qui se regénère), `entities.json` (les êtres et contenants de la fenêtre courante), `items.json` (les instances d'objets), `players/joueur.json` (fiche et être du joueur). **Décisions** : JSON lisible plutôt que `.bin` tant qu'on prototype (les Vector2i et clés non textuelles sont encodés explicitement) ; on ne sauvegarde **qu'en surface** (au camp ou à pied) — un donjon en cours n'est pas persisté, l'expédition reprend au camp ; **autosave toutes les 5 minutes réelles** et à chaque retour d'expédition ; F6 sauvegarde, F7 charge. Le profil multi-joueurs et les modèles sculptés n'existent pas.

> [!success] Complété le 2026-08-29 — ce qui est persisté, et ce qui ne l'est délibérément pas
> Ajoutés à `world.json` : **`modifs_terrain`** (ce que le monde doit rendre hors claim) et **`portails`** (les brèches du Passeur), tous deux indexés par **position monde** — un index de grille n'aurait aucun sens d'une session à l'autre, la fenêtre glisse. Ils sont relus **après** la réinitialisation, qui les vide (l'ordre a coûté un test rouge).
> Le test de sauvegarde fait désormais **un tour complet de l'état du camp** : trésor, stocks, registre d'élevage, claims, dérive de corruption, nombre d'êtres et compagnons attachés — tout est comparé après rechargement dans une simulation neuve.
> **Ce qui n'est volontairement pas sauvegardé**, et pourquoi : les **feux** et l'**automate d'eau en cours** (ils s'éteignent en quittant la cellule — les persister demanderait de les stocker par cellule dans `Monde`, or le hors-champ se résout par formules, [[Abstraction hors-site]]) ; les **glyphes**, **bombes en vol**, **affûts déployés** et **invocations temporaires** (couches d'overlay de combat, et on ne sauvegarde pas en combat) ; l'**état d'un donjon en cours** (on ne sauvegarde qu'en surface). Si l'un de ces choix se révèle gênant au playtest, c'est une décision de design, pas un oubli.

> [!success] Décidé et codé le 2026-08-31 — la sauvegarde est possible partout, à n'importe quel moment
> **Instruction du designer** : « sauvegarde possible partout à n'importe quel moment » — remplace le « on ne sauvegarde qu'en surface » du callout précédent. En expédition, `expedition.json` s'ajoute aux fichiers : le descripteur du donjon (thème, graine, id, étage, profondeur, cellule), les compteurs d'expédition, et les PNJ du camp mis de côté (le camp lui-même se régénère du monde à la sortie, ses PNJ et contenants sont réinjectés). L'étage courant se **régénère de sa graine** au chargement, puis les êtres et contenants sauvés remplacent les frais ; les étages déjà visités ne sont pas persistés (ils se régénèrent — mobs et loot re-tirés, seule entorse au « fixe » des donjons, notée ici). Comme à l'atelier, **aucun combat ne survit** : à l'écriture, tout le monde repasse sur l'horloge du monde. L'arène de test reste hors sauvegarde. F6 marche donc en plein donjon ; l'autosave de 5 minutes aussi.

> [!success] Corrigé le 2026-08-30 — « Continuer » à froid : le joueur reprend où il a sauvé, avec son brouillard
> Le chemin **écran principal → Continuer** après une sauvegarde en donjon, joué pour la première fois (`capture.tscn -- --sauvegarder` puis `-- --charger`), révélait deux entorses au « l'expédition reprend où elle était » : `_reprendre` replaçait le joueur **à l'entrée de l'étage** (et effaçait ses statuts), et le **brouillard de l'étage courant** repartait de zéro. Corrigé : `expedition.json` emporte `grille.decouvert`, et le chargement rend au joueur sa position (si la tuile est libre — sinon l'entrée), ses statuts et ses tuiles vues. Vérifié à l'écran : la capture d'avant-sauvegarde et celle d'après-rechargement sont identiques (case, PV, minimap). Régression : `test_sauvegarde_partout`.

> [!success] Corrigé le 2026-08-31 — les outils n'écrasent plus « monde », et nettoient derrière eux
> L'écran **Charger** (vérifié à l'écran contre le disque) listait huit emplacements fantômes `test_*` / `scratch_*` écrits par la suite et les sondes ; pire, l'**autosave du retour d'expédition** et le cycle du fuzz écrivaient dans **« monde »** — un outil pouvait écraser une vraie partie. Corrigé : `Simulation.slot_autosave` (par défaut « monde ») est détourné par la suite (« test_auto »), le fuzz (« essai_fuzz », effacé à sa sortie), le robot de parcours (« essai_parcours ») et la sonde de capture (« essai_capture ») ; `Sauvegarde.effacer(nom)` existe et la suite efface ses sept emplacements en fin de passe (les `test_*` du disque disparaissent à la prochaine passe verte). **À savoir** : le « monde » présent sur ce disque a été écrasé par les outils d'avant le correctif (autosave de la suite du 2026-08-31, 0 h) — ce n'est plus une vraie partie ; `scratch_partout` / `scratch_retour` sont d'anciens artefacts de sonde. Les supprimer à la main est sans risque, l'outillage n'y touche plus.

> [!success] Tranché le 2026-09-02 — **plusieurs parties, une sauvegarde par partie** (designer)
> « Qu'une seule sauvegarde, et elle se fait automatiquement ou si le joueur sauvegarde manuellement », puis, en précision : « on peut avoir plusieurs parties mais c'est une sauvegarde par partie ; sélectionner une partie devrait afficher le portrait de personnage et toutes les stats du monde. »
> **Un dossier par partie**, nommé d'après le personnage (`aldric`, `aldric_2`…), et **une seule sauvegarde dedans** : l'autosave et la sauvegarde manuelle écrivent au même endroit, il n'y a pas d'instantané auquel revenir. On peut donc mener plusieurs vies de front sans qu'aucune serve de filet à l'autre — ce qui garde son prix au jet de dé de [[Mort et pénalité]] : dans une partie donnée, le sac perdu est perdu.
> L'écran principal offre **Nouvelle partie**, **Continuer** (la partie touchée le plus récemment), **Charger**, **Options**, **Quitter**. Le menu en jeu n'a plus d'entrée « Charger » : on passe par l'écran principal, on ne recharge pas sa propre partie d'un coup de menu.
> **L'écran Charger montre la partie avant de l'ouvrir** : le personnage dessiné en pied et en portrait, ses trois jauges, puis race, classe, niveau, PV, or, sac, jour, heure, saison, où l'on était (surface ou étage de donjon), le biome du camp, la graine du monde, les cellules parcourues, les cellules revendiquées, les villages connus, la corruption au camp et la date d'écriture. Tout cela vient d'un bloc `resume` écrit dans `world.json` à chaque sauvegarde : charger un monde entier par ligne de liste coûterait des secondes, et l'écran doit s'ouvrir tout de suite. Les parties d'avant ce bloc se listent sous leur seul nom de dossier plutôt que de disparaître.

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Arborescence du projet]]
- **Alimente** : [[Multijoueur]], [[Abstraction hors-site]], [[Minimap et brouillard de guerre]], [[Donjons — structure et intégration]]
- **Voir aussi** : [[Décision — Structure de données de la grille]], [[Réseau]], [[Réseau et sauvegarde — performance]], [[Optimisation — principes]], [[Contraintes permanentes]], [[Schéma créature]], [[Éditeur de sculpture]]
