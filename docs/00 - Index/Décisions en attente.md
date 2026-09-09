---
aliases: ["Décisions en attente", "Ce que je dois trancher", "Décisions bloquantes"]
tags: [index, production, ouvert]
domaine: index
statut: ouvert
etape: 12
---

**Tout ce qui attend une décision du designer et qui bloque du code.** Une seule liste, tenue à jour à chaque fois
qu'une question sort d'un chantier.

Cette note est née le 2026-09-08 d'une question du designer — « tu notes toujours toutes les décisions à prendre, n'est-ce
pas ? ». La vérification a répondu **oui, mais mal** : 56 questions dormaient dans **20 notes différentes**, chacune à
l'endroit où elle était née. Elles étaient traçables et personne ne pouvait les lire d'un coup.

**Ce que cette note NE contient pas** : ce qui se juge **à l'œil, en jouant** — la lisibilité, le rythme, le plaisir,
la difficulté ressentie. Ça a déjà son parcours d'une heure dans [[À juger — parcours de jeu]] (22 questions). Ici, il
n'y a que ce dont j'ai besoin **pour écrire du code juste**.

**Comment répondre** : une phrase suffit. J'écris le callout daté dans la note concernée et je code derrière.

---

## Ce qui bloque un chantier en cours

| # | La question | Ce qu'elle bloque | Où elle est née |
|---|---|---|---|
| 1 | **Le grain de la vitesse.** Une grille à ticks n'a pas de vélocité continue : un corps avance de N tuiles par tick, ou d'une tuile toutes les N ticks. Combien de crans entre la flèche et le rocher ? | L'**inertie mécanique** (ligne 27 bis de l'[[Ordre de travail]]), donc la réécriture des modules qui en dépend | [[Émergence — les champs partagés]] |
| 2 | **Jusqu'où va le recul.** Un corps poussé pousse-t-il à son tour ce qu'il heurte (chaîne de collisions), ou s'arrête-t-il au premier obstacle ? | idem | [[Émergence — les champs partagés]] |
| 3 | **Le joueur est-il un corps ?** Une charge qui emporte au-delà de la cible, un personnage lourd plus lent à changer de direction. **C'est le plus intrusif : ça touche les contrôles.** | idem, et le ressenti du déplacement | [[Émergence — les champs partagés]] |
| 4 | **Le grain des membres.** Une intégrité par zone (0-100), ou des blessures nommées qu'on accumule (entaille, fracture, brûlure, hémorragie) ? | Les **membres simulés** | [[Combat tactique sur grille]] |
| 5 | **Jusqu'où va l'irréversible.** Un membre peut-il être perdu pour de bon — le joueur peut-il finir manchot pour le reste de la partie ? | idem | [[Combat tactique sur grille]] |
| 6 | ~~Est-ce que ça vaut pour tout le monde ?~~ **TRANCHÉ le 2026-09-08 par l'élargissement du designer** : le corps devient un **plan de parties en données**, un par créature — `silhouette` en devient l'ancêtre. | — | [[Combat tactique sur grille]] |
| 6 bis | **Les emplacements d'équipement doivent dériver du corps.** C'est le point structurel de l'anatomie : `e.equipement` a des clés **fixes** aujourd'hui. Perdre un bras doit retirer un emplacement, en gagner un doit en ajouter. Faut-il y aller, sachant que c'est le chantier le plus intrusif en file (le paperdoll dessine par emplacement, et la suite entière suppose des emplacements fixes) ? | Toute l'anatomie | [[Combat tactique sur grille]] |
| 6 ter | **Le budget de place interne.** « Plusieurs estomacs = manger plus mais demande plus de place » introduit une **contenance du corps** qui n'existe nulle part. Quelle en est l'unité, et qu'est-ce qui la consomme — les organes seuls, ou aussi les greffes et les membres surnuméraires ? | Les organes | [[Combat tactique sur grille]] |
| 7 | **Le sens de la vérité des catalogues.** La note redevient-elle la source (il faut alors valider à la main les lignes reversées et les chiffres étirés), ou la donnée devient-elle la source et la note son reflet ? **Tant que ce n'est pas tranché, les tables réalignées rederiveront au prochain équilibrage.** | Tout chantier matériaux durable | [[Matériaux — 13 stats]] |
| 8 | **Les champs avant ou après le jeu fini ?** Le designer a tranché l'ordre *des six champs entre eux*, pas leur place par rapport à la pause, la mort et les touches — celles-ci sont faites depuis, la question porte donc maintenant sur la suite du palier 3 et la sauvegarde. | L'ordre des paliers 5 à 7 | [[Émergence — les champs partagés]] |
| 10 | **Faut-il une relève de garnison ?** Un repeuplement qui puisse rendre un garde. **Sans elle, l'équipement qui suit le stock d'une ville ne peut mordre sur personne** — un garde n'est jamais ré-équipé. | La ligne 32 bis, déjà réfutée sous sa forme initiale | [[Ordre de travail]] |

| 10 bis | ~~Le champ de vue du joueur doit-il être séparé de la portée de détection d'une IA ?~~ **FAIT le 2026-09-08 sur carte blanche du designer** : `vision.joueur_base` = 18 + Perception. A/B à graine fixe : la pire image passe de 46,1 à 36,6 ms. | — | [[Budgets de performance]] |
| 10 ter | **L'intensité du grain du décor.** Posée à 0,26 / 0,15 le 2026-09-08 (elle était à 0,12 / 0,07, donc invisible ; un essai à 0,38 / 0,22 grouillait). C'est de la **direction artistique** et une ligne de données — deux captures de comparaison ont été envoyées au designer. | La lisibilité du décor | [[Budgets de performance]] |

| 11 | **Un tick à 10 ms — DÉCIDÉ le 2026-09-08 (« je te fais confiance »), la classification est faite, la migration reste à passer.** *Pourquoi* : le temps à l'action ne sait pas exprimer une différence de vitesse plus fine que 10 % — une frappe coûte 5 ticks, deux combattants dont l'un est 10 % plus rapide se départagent sur **0,5 tick**, arrondi à 0 ou 1. À 100 ticks/s la frappe vaut 50 ticks et les 10 % se disent exactement. *Ce n'est pas un changement de rythme mais d'**unité***. Le coût processeur ne bouge pas (la file des compteurs ne réveille que ce qui est dû). **Voir la classification ci-dessous : c'est elle le travail, pas le ×10.** | Le temps à l'action, toute la donnée de combat | [[Simulation à ticks]] |
| 12 | ~~La hache de départ ne peut pas abattre un chêne~~ **TRANCHÉ le 2026-09-08 : il n'y a rien à corriger, et c'est moi qui ai crié trop vite.** Le chêne (dureté 16, palier 3) résiste à une hache de départ (~7) — mais la forêt tempérée est **mixte** : chêne 0,06, hêtre 0,04, **pin 0,02, bouleau 0,02**, et le pin comme le bouleau tombent sous cette hache. Le joueur n'est donc jamais bloqué, et le journal lui dit pourquoi quand il s'y casse les dents (« l'outil rebondit : {matériau} est trop dur pour lui »). **Le palier est une porte de progression qui fonctionne** ; ce que j'avais pris pour un défaut de contenu était un test qui abattait le plus dur des arbres avec l'outil le plus faible, et qui passait par chance. | — | [[Récolte]] |


> [!warning] **La classification du tick à 10 ms** (2026-09-08) — établie avant la migration, parce qu'un ×10 aveugle serait FAUX
> Un balayage sur les noms de champs trouve **942 champs** qui parlent de temps. Trois pièges rendent le balayage inutilisable, et je les ai trouvés en les lisant un par un :
> - **Des multiplicateurs portent le mot « ticks »** : `actions.lourde_mult_ticks` (×2 sur le coût), `paliers_materiaux.*.extraction_ticks` (1,0 à 3,0), `echec_ticks_rendus` (0,5 — lu comme `1 − x`, une **fraction**, pas des ticks). Les multiplier casserait l'équilibre sans qu'aucun test ne le voie.
> - **Des coûts en ticks ne portent PAS le mot** : `actions.attaque_base`, `changer_arme`, `objet`, `garde`, `attendre` ; `deplacement.cout_base`, `montee_1`, `montee_2`, `descente`, `nage`. Et juste à côté, dans le même bloc, `falaise_delta`, `chute_delta`, `chute_franchise` sont des **hauteurs**, `chute_degats_par_niveau` des **dégâts**, `creuser.xp` de l'**XP**, `creuser.vigueur` de la **vigueur**. Le nom ne dit rien : il faut lire le bloc.
> - **Des débits par tick doivent être DIVISÉS** : `vigueur.regen_par_tick` (2), `sang_froid.regen_par_tick` (1), `conditions.cout_par_tick_rendu` (1). *Vérifié* : les trois passent par des flottants avec un seul arrondi (`round(ecoules × regen)`), donc 0,2 et 0,1 se comportent correctement — la division est sûre.
> **Les familles des catalogues** (15 noms de clé, 950 occurrences) : **×10** pour `statut_ticks` (191), `cout_ticks` (184), `duree_ticks` (173), `surcout_ticks` (116), `periode_ticks` (85), `delay_ticks` (34), `ticks`, `retard_ticks`, `apres_ticks`, et le `duree` de `lame_empoisonnee` ; **inchangés** `duree_jours` (105 — des jours), `echec_ticks_rendus` (une fraction), `durees_mult`, et les deux champs **dérivés par les générateurs** (`vitesse_att_par_10_ticks`, `ticks_par_attaque`) que **rien ne lit dans le jeu** — les toucher ferait rougir `verif_generateurs.py` sans rien apporter.
> **Ce qui reste à faire, dans cet ordre** : (1) le script de migration, qui **imprime chaque champ touché** avec son avant/après ; (2) `ticks_par_seconde_exploration` 10 → 100 et `recolte.ticks_par_seconde` 10 → 100 ; (3) ~~`tempo.ticks_max_par_image` ×10~~ — **cette étape du plan était FAUSSE, et c'est son nom qui la rendait plausible** : le champ ne compte pas des ticks mais des **actions** (`while garde_pas > 0 and sim.pas("monde")` — des êtres qui agissent). Le multiplier aurait fait résoudre dix fois plus d'actions par image. Il n'a pas été touché, ce qui était juste, et il s'appelle `actions_max_par_image` depuis le 2026-09-09 — une sonde s'en était servie comme d'une avance en ticks, précisément à cause du nom ;  (4) les tests qui affirment des valeurs exactes (« le monde a avancé de 8 000 ticks ») ; (5) un **garde-fou** : un jour dure toujours un jour, et une frappe toujours le même temps réel ; (6) les **sauvegardes** existantes portent des compteurs en ticks — à l'échelle au chargement, ou à déclarer incompatibles.
| 13 | **Que voit-on du niveau du dessous depuis un étage ?** *(soulevé par la demande du 2026-09-08 : « seulement rendu ce qu'il y a à ce niveau Z », ligne 26 quater.)* **Ne rien montrer** rend un étage aveugle — on ne voit plus la rue qu'on surplombe, ni ce qui attend au pied de l'escalier. **Tout montrer**, c'est l'état actuel, celui que le designer veut justement quitter. Entre les deux : ne montrer le dessous **que par une ouverture** — une cage d'escalier, un trou, un balcon —, ce qui demande de savoir ce qu'est une ouverture dans les données. | Le rendu des étages, la vision | [[Grille continue]] |
| ~~14~~ | **TRANCHÉE ET FAITE le 2026-09-08 au soir** — le designer : « on peut s'en occuper maintenant ? ». Codée : le lacet continu, la projection, le tri par profondeur, les huit angles ; il ne reste qu'un `ordre` par rig pour départager les ex æquo, et les rigs animaux attendent leur réécriture (ligne 26 septies). *Question d'origine :* **Donner de la PROFONDEUR au squelette ?** *(designer 2026-09-08 : « rajouter la profondeur, comme ça on pourrait avoir les personnages dans les 8 angles et faire des poses plus complexes, t'en penses quoi ? »)* **Mon avis : oui, et pas pour la raison qu'on croit.** L'argument fort n'est pas « plus d'angles » : c'est que la profondeur **SUPPRIME** ce qu'on écrit à la main. Un rig porte aujourd'hui, par facing, un **ordre de dessin** et des **décalages d'ancrage** — **247 entrées** écrites à la main sur les six rigs, qui ne sont rien d'autre que de la profondeur *simulée*. Un segment orienté en 3D, projeté par l'isométrie que le jeu applique déjà au monde (`(x−y)·tw/2, (x+y)·th/2 − z·hstep`), **calcule** l'ordre et les décalages : huit vues d'une seule source. C'est la même forme de gain que les champs qui remplacent les règles ad hoc. **Et une pose s'écrit alors UNE fois** au lieu d'une par angle. **Ce que ça ne résout PAS, et il faut le savoir avant** : la profondeur donne le bon **placement** et le bon **ordre**, pas le bon **dessin**. Un sprite de 64 × 64 posé sur un membre en raccourci est *écrasé* — pour les angles éloignés de celui qu'on a dessiné, il faudra soit un sprite par angle, soit accepter l'écrasement. **Et une dépendance d'ordre** : à faire **avant** d'écrire les poses (ligne 26 quinquies), sinon chaque pose écrite en 2D pour un facing est à jeter. | Le paperdoll, les 8 angles, l'écran de pose | [[Squelette modulaire et points d'attache]] |

## Ce que le designer a réservé pour plus tard

| # | La question | État |
|---|---|---|
| 11 | **Refondre l'exploration et la génération du monde** — « plus Caves of Qud / Dwarf Fortress que JRPG classique / Elin / Elona ». | **Réservé le 2026-09-08** : « on en reparle plus tard ». Rien n'est engagé. Observation gardée pour ce moment-là : le substrat est déjà de ce côté (grille continue, tectonique à plaques, seuil de mer calibré) ; c'est la **couche d'exploration** qui est Elona, et six des huit couches de bruit qui restent libres. |
| 12 | **Le voyage à la Fallout 1** : que voit-on pendant le trajet (la carte du monde, ou le terrain qui défile) ? Qu'est-ce qui interrompt ? Reprend-on un trajet interrompu, à quel prix ? Les rencontres se tirent-elles par cellule ou se pondèrent-elles par le champ de danger ? | **Suspendu à la question 11** : un trajet cellule par cellule sur un écran de carte est une amélioration *dans* le modèle Elona ; si le modèle change, elle devient sans objet. |

## Ce qui dormait dans le coffre, parfois depuis longtemps

| # | La question | Où elle est née |
|---|---|---|
| 13 | **La résolution interne du pixel art.** Le designer aime le rendu pixelisé des captures — mais ces images sont des agrandissements au plus proche voisin, pas le rendu du jeu. L'obtenir vraiment demande un `SubViewport` à 480 × 270 ou 640 × 360 agrandi au plein écran : **tout devient du pixel art, l'interface comprise**, et le texte du HUD devient illisible sous 480 de large. | [[Vers la production]] (2026-09-01) |
| 14 | **La matrice 5 × 3 des noyaux de dégâts** : la garder (chaque case est une munition à collectionner), la réduire à trois noyaux paramétrés par l'élément, ou différencier les paliers autrement que par le dé ? *(À revoir avec la réécriture des modules, qui la rend peut-être caduque.)* | [[Modules]] |
| 15 | **La Règle d'anneau** : 40/40/20, ou une autre définition du hasard ? Elle est mesurée à ×5,7 au lieu de ×15. | [[Règle d'anneau]] |
| 16 | **Tuer une bête paisible a-t-il un prix ?** (réputation, raréfaction, faim des prédateurs) Et la faune **se reproduit**-elle, ou repeuple-t-elle par génération comme les villages ? | [[Vers la production]] |
| 17 | **L'IA des créatures** : l'aggro se transmet-elle entre êtres du même camp (une meute réagit ensemble) ou reste-t-elle individuelle ? Un être désengage-t-il quand le joueur s'éloigne, ou poursuit-il indéfiniment ? Le roam suit-il une patrouille fixe ou une marche au hasard ? | [[Vers la production]] |
| 18 | **Le sac du joueur pourrit-il ?** Décision de confort : une horloge de péremption par objet porté. | [[Économie — sources et puits]] |
| 19 bis | **`sous_sol.json` : collection ou configuration ?** Eau, géodes, magma — trois *sortes de poche* avec leur réglage. Les gaz, eux, sont passés en catalogue le 2026-09-08 (un fichier par entrée) parce que ce sont clairement quinze contenus ; celui-ci est à la frontière. | [[Décision — Pipeline de contenu]] |
| 19 | **Les arbres fruitiers hauts** : un verger est un buisson aujourd'hui ; un pommier devrait-il bloquer la vue, et passe-t-on dessous ? | [[Agriculture et élevage]] |

## Ce qui n'est pas une décision mais un choix de contenu

| # | | |
|---|---|---|
| 20 | **Le son.** Zéro fichier audio, zéro `AudioStreamPlayer` dans tout le projet. Je peux poser l'architecture (bus, événements → sons, ambiance par biome et par heure) ; **les sons eux-mêmes sont un choix du designer**. C'est l'absence la plus criante à l'écran. | [[Ordre de travail]], palier 13 |
| 21 | **La difficulté de départ** : le robot meurt aux étages 1 et 2 avec le kit complet. **Jugeable dès maintenant** — la pause et l'écran de mort existent depuis le 2026-09-08. | [[À juger — parcours de jeu]] |

## Liens
- **Dépend de** : [[Vers la production]], [[Ordre de travail]]
- **Voir aussi** : [[À juger — parcours de jeu]] (ce qui se juge à l'œil, en jouant), [[Émergence — les champs partagés]], [[Émergence — le monde vivant]]
