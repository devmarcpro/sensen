---
aliases: ["Six types de modules", "Assemblage", "Noyau Forme Modificateur", "Types de modules"]
tags: [combat, build, décidé]
domaine: combat
statut: décidé
etape: 0
---

La décision structurante : la FORME est séparée de l'EFFET. C'est ce qui fait que chaque forme multiplie chaque effet gratuitement.

**La décision structurante : la FORME est séparée de l'EFFET.** Si « ligne de 4 » et « dégâts de feu » sont deux modules distincts, chaque forme multiplie chaque effet gratuitement. Cuire la forme dans l'effet obligerait à écrire « projectile de feu », « ligne de feu », « cône de feu » séparément — et le catalogue deviendrait du remplissage.

| Type | Rôle |
|---|---|
| **Noyau** | la charge utile : dégâts, soin, statut, déplacement, terrain, invocation |
| **Forme** | où la charge s'applique : cible unique, ligne, cône, croix, anneau, carré, diagonale, tuile au sol |
| **Modificateur** | altère les paramètres du noyau suivant : portée, taille, puissance, coût en ticks, élément |
| **Condition** | verrou ou bonus : si plus haut, si la cible est isolée, si de dos, si ligne de vue dégagée, si tel segment est en jauge |
| **Déclencheur** | diffère la charge : à l'impact, à l'entrée sur la tuile, après N ticks, sur événement — c'est ce qui permet l'imbrication façon Noita |
| **Liaison** | répéter, alterner, disperser sur plusieurs cibles, propager de proche en proche |

**Règles d'assemblage :** une **capacité** est une séquence ordonnée dans un contenant (grimoire ou manuel d'arme), lue de gauche à droite. Modificateurs et conditions s'accumulent sur le prochain noyau ; un déclencheur encapsule tout ce qui le suit comme charge utile. La séquence entière se résout comme **une seule action**, coûtant `ticks du noyau + surcoûts`. Les slots croissent avec le niveau de l'arme ([[Structure compétences-modules-slots]]).

- **L'élément de la capacité dérive du vecteur de ses modules** — le Wu Xing s'applique intégralement ([[Wu Xing — cycles et vecteurs]]).
- **Une capacité qui touche pose UN segment de chaîne**, quel que soit le nombre de cibles ([[Jauge de chaîne Wu Xing]]).

**Exemples :**
- `[Ligne 4] + [Dégâts Feu]` → jet de flammes droit devant
- `[Portée +2] + [Anneau r1] + [Poussée]` → repousse tout ce qui entoure une tuile distante, sans toucher le centre
- `[Si plus haut] + [Cible unique] + [Dégâts Métal] + [À l'impact] + [Croix] + [Saignement]` → frappe plongeante qui éclabousse de saignement
- `[Tuile] + [À l'entrée] + [Enracinement Bois]` → glyphe qui immobilise, et pose un segment Bois en se déclenchant

Le même vocabulaire produit une attaque, un contrôle de zone, un piège et un soutien.

> [!success] Décidé et codé le 2026-08-29 — **aucune limite d'assemblage** : le prix et le résultat sont les seules bornes
> **Instruction du designer** : « tous les modules devraient pouvoir s'assembler entre eux, no limit ; la seule limite c'est le **résultat** (soigner les ennemis, se suicider) et les **stats** — certains sorts sont si ridicules qu'ils demandent une quantité de mana astronomique ». L'exemple donné fait loi : *une invocation portée par une forme large invoque **une créature par tuile**, et coûte donc plusieurs fois le prix — on peut remplir une salle de bombes d'un seul geste, à condition d'en avoir le mana.*
> **Ce qui disparaît.** Les deux refus d'assemblage — « deux noyaux dans la même séquence » et « deux formes » — n'existent plus. **Plusieurs noyaux** : chacun applique sa charge, avec ses dés, ses effets et **son coût**, dans l'ordre de la séquence (*Alternance* garde son rôle : elle fait alterner les noyaux d'un emploi à l'autre au lieu de les cumuler). **Plusieurs formes** : les tuiles s'**additionnent** (union), et la portée retenue est la plus longue. Il ne reste que deux erreurs, structurelles : un module **inconnu**, et une séquence **sans aucun noyau** (il n'y aurait rien à exécuter).
> **Le prix suit la surface.** Un effet qui s'instancie **par tuile** — invocation, zone au sol, remodelage du terrain — multiplie la ressource du sort par le **nombre de tuiles de la forme** (`Simulation._facteur_surface`). Poser une bombe sur une tuile coûte son prix ; en poser vingt en coûte vingt fois. Les effets qui frappent des **êtres** (dégâts, soin, statuts) gardent le prix de leur noyau : la forme les fait payer par son propre surcoût, et la cible n'est pas garantie. **Le prix se voit avant de payer** (2026-08-30) : l'écran Composer affiche, pour un plan par tuile, le nombre de tuiles d'une visée nominale (portée maximale) et le total ; à la visée, l'en-tête donne les tuiles **réellement** couvertes par ce clic et le coût correspondant (`Simulation.surface_nominale`, `plan_par_tuile`). **Un même module peut entrer plusieurs fois** (2026-08-30) : l'assembleur cumulait déjà (deux Bombes = deux charges par tuile et le double du prix, deux Concentrations = +2 dés), mais le composeur cochait / décochait — Entrée ajoute désormais une occurrence de plus, Suppr retire la dernière, et chaque module affiche `[n]` son nombre d'occurrences ; chaque lancer consomme autant de charges que d'occurrences.
> **Le résultat est la seule morale.** Le soin ne vérifie plus le camp — un sort mal composé **soigne l'ennemi**, et c'est au joueur de le voir. Les dégâts n'épargnent plus le lanceur quand la forme le couvre : on peut **se tuer soi-même**. Décision assumée : ces deux garde-fous étaient un jugement de goût du code sur ce que le joueur a le droit de fabriquer, et la note dit l'inverse.
> **Ce que ça ouvre** : une séquence *Carré + Bombe + Bombe* pose deux charges sur chaque tuile du carré ; *Nuée + Écho de chair* peuple une salle ; *Soi + Cataclysme + Baume* se soigne au centre de son propre cratère. Le mana décide, pas l'assembleur.

> [!success] Corrigé le 2026-08-30 — cinq formes sur seize n'avaient pas de géométrie dans le code
> Trouvé en poussant le « no limit » : *Nuée + Écho de chair* n'invoquait qu'une créature. `Capacites.tuiles_de_forme` ne connaissait que onze géométries ; **Chemin**, **Colonne**, **Horizon**, **Nuée** et **Sillage** — déclarées en données depuis le catalogue — tombaient dans le défaut « visée au point ». Cinq formes qui coûtaient leur surcoût pour se comporter comme *Point*. Codées selon leur description : *Sillage* = les N tuiles derrière la cible dans l'axe du lanceur ; *Chemin* = le trajet du lanceur vers la cible ; *Colonne* = la tuile visée (volants et contrebas y sont déjà : la hauteur n'exclut personne de `_entites_dans`) ; *Horizon* = toutes les tuiles en vue dans le rayon, plafonné à 12 ; *Nuée* = N tuiles tirées autour de la cible, **reproductibles pour une même visée** (l'aléa est semé par la position — deux lancers identiques donnent la même nuée, ce qui rend l'aperçu honnête). L'audit tient la liste des géométries gérées en miroir du code, comme pour les prédicats.

> [!success] Décidé et codé le 2026-08-30 — deux familles de formes : **à distance** et **depuis soi**
> **Demande du designer** : « bien différencier les sorts qui se lancent à distance et ceux qui se lancent à partir du joueur ». Le catalogue mélangeait les deux dans un seul type *forme*, et le code les traitait pareil : une portée `[min, max]` mesurée à la **tuile cliquée** — ce qui n'a pas de sens pour un Cône, dont la tuile cliquée n'est qu'une **direction**. Résultat : cliquer à 5 tuiles avec un cône de portée 3 était **refusé**, alors que le cône part du lanceur et ne vise rien.
> **Décision** : plutôt qu'un septième type de module, chaque forme porte un champ **`origine`** — `"cible"` (la forme est **projetée** sur la tuile visée : Point, Carré, Anneau, Croix, Diagonale, Tuile, Mur, Sillage, Nuée, Colonne) ou `"lanceur"` (la forme **part du lanceur**, le clic ne donne qu'une direction : Ligne, Cône, Vague, Chemin, Horizon ; Soi est un cas de `lanceur` sans direction). Un type de plus aurait dupliqué toute la logique d'assemblage pour une seule différence de visée. **Conséquences** : une forme `lanceur` accepte **n'importe quelle tuile** comme direction (sauf la sienne), sa `portee_base` devient sa **longueur** ; une forme `cible` garde sa portée et sa ligne de vue. L'écran *Composer* sépare les deux familles en deux blocs (**Formes — à distance** / **Formes — depuis soi**), et l'aperçu dit laquelle. L'audit exige le champ sur toute forme, avec l'une des deux valeurs.

> [!success] Décidé et codé le 2026-08-30 — un noyau **répété** est un noyau **plus puissant**
> **Instruction du designer** : « bombe + bombe devrait faire des bombes plus puissantes, comme pour les autres assemblages du genre : un noyau doublé est doublé, donc deux fois plus puissant, pareil si c'est triplé ». Jusqu'ici deux Bombes posaient deux bombes par tuile (deux explosions séparées) ; désormais un noyau présent **n fois** dans la séquence est **un seul** noyau à `fois = n` (`Capacites.appliquer_fois`) : ses **dés sont multipliés** (`3d6` → `6d6`, `1d4+1` → `2d4+2` ; un noyau « arme » ou à formule prend `mult × n`), et ses paramètres numériques aussi — durée d'un statut ou d'une zone, delta de terrain, montant d'une ressource (mana rendu, PV transférés, sang), distance d'un déplacement, tempo volé, points d'armure ignorés ; la bombe a `puissance × n` et `dégâts × n`, la tourelle `dégâts × n`, l'Écho de chair pose `n` créatures par tuile. Les identités (cible, mode, statut, zone, drapeaux) ne changent pas. **Le prix suit** : ticks et ressource comptés n fois, n charges consommées — c'est la même règle que pour deux noyaux différents, qui restent deux charges séparées (Bombe + Étincelle). **Décision** : le multiplicateur est linéaire (×2, ×3…), sans plafond — c'est le prix qui borne ; un mur qui résiste à une bombe tombe sous deux. **La même forme répétée** suit la même logique (détail manquant, option la plus simple) : une forme plus **grande** — taille et portée additionnées (Carré + Carré = un carré de taille double, Ligne + Ligne = une ligne deux fois plus longue), le surcoût de ticks payé une fois de plus ; deux formes différentes restent une union. **Les monnaies** (2026-08-30) : un sort a une seule monnaie, celle de son premier noyau ; un noyau de l'autre monnaie ajouté ensuite paie **dans la monnaie du sort, 1 pour 1** (Bombe [endurance] + Baume [10 mana] = +10 d'endurance) — avant cela, il était gratuit, une faille du « no limit ». Et l'**endurance** a désormais son épuisement, comme le mana sa surchauffe : le déficit se paie en PV ([[Mana]]).

## Liens
- **Dépend de** : [[Vocabulaire des modules — six axes]], [[Structure compétences-modules-slots]]
- **Alimente** : [[Familles de capacités de la grille]], [[Modules]], [[Jauge de chaîne Wu Xing]]
- **Voir aussi** : [[Le vocabulaire des modules et l'absence d'arbre de talents]], [[Wu Xing — cycles et vecteurs]], [[Grimoires et manuels]], [[Sorts cataclysmiques]]
