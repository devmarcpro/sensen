---
aliases: ["Vers la production", "Roadmap de pré-production", "Ce qui manque"]
tags: [index, production, décidé]
domaine: index
statut: décidé
etape: 0
---

**Le design est complet et décidé.** Il ne reste ni question bloquante ni valeur à inventer : tout ce qui était ouvert porte une décision ou un défaut chiffré. Ce qui suit est l'état de production — ce qui est fait, et ce qui reste à *produire* (assets, code).

> [!important] Étape 0 — les 12 jalons sont codés, reste le jugement (2026-08-26, soir)
> La démo 0 est devenue le **prototype de combat** : `godot/scenes/demo/main.tscn` charge les **3 arènes** depuis `data/prototype_arenas/` (Tab pour changer), avec autoloads GameData/EventBus/TickManager, grille SoA + A* 8 directions + ligne de vue, simulation autoritaire (intentions → résolution), une horloge par combat, mêlée avec zones par dénivelé et armure plate, garde frontale, attaque lourde télégraphée, endurance, attendre, chute, IA utility en données et les 24 actions de créatures ; **Wu Xing** (vecteurs, domination, jauge de chaîne avec décroissance et résolveur, prévisualisation au survol), **râtelier** (1-7) et **bouclier** ; **modules assemblés** (F1-F3 : trois capacités, mana, surchauffe, friendly fire des zones, conditions) ; **projectiles** (arc, munitions, trajectoire), **statuts** (14, anti-stunlock, interruption de la jauge des élites), **écran de fin** (durée en ticks, XP des pistes). Tests headless : `scenes/tests/test_combat.tscn`. Détail et jalons restants : [[Prototype de combat — spécification]].
>
> **À juger à l'œil (ouvrir `godot/` dans l'éditeur, F5) — questions à trancher :**
> 1. *Lisibilité de l'iso 32×32 à 40×20 px par tuile* : le relief se lit-il ? Faut-il des ombres de flanc plus marquées ou une grille ? (molette : zoom, clic milieu : déplacer la vue)
> 2. *Rythme des horloges de combat* : `DELAI_PAS = 0.12 s` entre deux pas — trop lent ? trop rapide pour suivre les loups ?
> 3. *Le télégraphe* (« ! » + tuiles rouges pendant une lourde ou une charge) : est-il vu à temps ?
> 4. *Les coûts sur les tuiles* (jaune, budget 12 ticks) : utiles ou bruit ?
> 6. *Les capacités* (F1 puis clic) : la forme bleue prévisualisée et l'infobulle suffisent-elles à comprendre ce qui va partir, pour qui, à quel prix ?
> 7. *Les critères mesurables* : la durée d'une rencontre s'affiche à l'écran de fin (cible 60-200 ticks). Les deux autres sont **calculés** par `scenes/tests/test_criteres.tscn` (dégâts moyens, vraies règles, vraies données — relancer après chaque retouche de JSON) :
>    - **Deux voies de chaîne** (cible ±15 %) : rotation parfaite lance→Étincelle→masse→épée→Gel = **68.8** dégâts en 43 ticks ; construction/détonation dague×4→Gel = **44.4** en 24 ticks ; masse×4→épée lourde = **108.8** en 46 ticks ; épée×5 = 80.0 en 30 ticks. **Écart 36 % : hors cible.** Cause visible : les charges légères (Étincelle 1d4) et le coût des deux swaps pèsent sur la rotation, la lourde ×2.2 pèse lourd dans la détonation. La spec dit *« retoucher les bonus de transition, pas le système »* — décision de chiffres à prendre par le designer (pistes : +0.35 → +0.45 sur l'engendrement, ou une charge moyenne dans la rotation).
>    - **Swap rentable dans certains cas seulement** : par tick, le swap ne paie **jamais** dans les quatre séquences testées (épée×5 : 2.39/tick contre 1.94 avec deux swaps ; dague×5 : 2.59 contre 2.50 dague→épée lourde). **Hors cible** : *« si la réponse est toujours la même, les chiffres sont à revoir »* — 4 ticks de swap contre +0.25 de différence de transition, c'est trop cher ou trop peu payé.
> **Tranché le 2026-08-27 par le designer** (notes datées) : pas de rotation de caméra, ZQSD 8 directions, joueur centré ([[Écrans d'interface]]) · terrain plat, reliefs en exception ([[Génération par couches de bruit]]) · exploration en temps réel conservée · vitesse de déplacement = Athlétisme + modificateur de race, jamais une stat fixe ([[Boucle de tick]]) · dégâts d'arme × skill_factor(arme) × skill_factor(type) × niveaux d'élément pondérés ([[Pipeline de résolution du combat]]) · niveau de module → ticks / skill_factor, plancher 50 % ([[Structure compétences-modules-slots]]). Tout est codé (crochets de niveaux à 0 jusqu'à l'étape 4).
> [!important] Fuzz, graines 77 et 88 : deux robustesses de plus (2026-08-28)
> `en_combat` vérifie que le combat existe encore (sinon l'être revient sur le monde) ; descendre en donjon depuis le camp sans passer par l'expédition met quand même le camp de côté (`charger_donjon` → `_sauver_camp`), sinon le retour plantait.
> [!important] Fuzz de la sauvegarde : un combat qui survivait au rechargement (2026-08-28)
> Sauvegarder en plein combat puis recharger laissait les êtres sur une horloge de combat disparue (`horloge_de` → null, des centaines d'erreurs). Corrigé : au rechargement tout le monde revient sur l'horloge du monde et les combats sont vidés ; `horloge_de` se rabat sur le monde si le combat n'existe plus.
> [!important] Fuzz du voyage : un combat qui suivait le joueur d'une cellule à l'autre (2026-08-28)
> Voyager en plein combat laissait le combat vivant avec des participants déchargés par la fenêtre glissante → 959 erreurs par run. Corrigé : `voyager` quitte le combat, `_verifier_desengagements` ignore les participants déchargés.
> [!important] Menu de triche (2026-08-29)
> **V** ouvre *Triche* : tout obtenir (objets exceptionnels, matériaux, compétences, talents, modules, recettes), tout déclencher (météo, statuts, races cachées, créatures, semaine, révélation de la carte, invincibilité). De quoi juger le parcours sans farmer.
> [!important] Les loups repéraient à travers la nuit et la Discrétion (bug, 2026-08-29)
> L'acquisition de cible lisait la Perception brute : nuit, torche, Discrétion, L'Ombre n'y changeaient rien. Corrigé ; semer une créature en se cachant 100 ticks marche désormais.
> [!important] L'embuscade (2026-08-29)
> Lynx, crocodile et serpent : +2 dés sur la frappe qui ouvre le combat contre une proie qui ne se bat pas encore. **À juger** : assez pour rendre les bêtes d'affût redoutées, ou invisible dans le bruit des dés ?
> [!important] Deux noms que le code citait dans le vide (bug, 2026-08-29)
> `"melee"` (les gardes défendaient tous au niveau 0) et le tag `plat` (le Vampire mangeait tout). Le contrôle inverse — noms cités par le code vs données — est dans l'audit.
> [!important] Fin du chantier « des catégories, pas des choses » (2026-08-29)
> Boutiques, loot, marchands, distillation, meubles, livraison : plus aucune liste d'ids là où le design veut une catégorie. Restent, à dessein, le coffre de départ, les plans de bâtiments et les faunes de biome.
> [!important] Le coût d'un meuble est sur le meuble (2026-08-29)
> 33 recettes « meuble_x → meuble_x » supprimées : la fiche de l'objet porte `recipe.inputs`, la recette en est dérivée au boot. Un meuble neuf est constructible sans fichier de plus.
> [!important] La distillation : deux recettes au lieu de quatorze (2026-08-29)
> La sortie d'une recette peut se lire sur l'ingrédient (`depuis_entree`/`champ`) : une plante neuve devient distillable en portant un `distillat`, sans écrire de recette.
> [!important] Boutiques et loot : des catégories, plus des listes d'objets (2026-08-29)
> Le designer avait raison : `shop_types.inventaire`, `creatures.inventaire_marchand` et les huit `loot_rules.bases_*` étaient des listes d'ids écrites à la main — un objet neuf n'apparaissait ni en boutique ni en coffre. Tout passe par un **filtre de catégorie** (`GameData.filtrer`), et l'audit refuse un filtre qui ne matche rien. **Reste à faire dans le même esprit** : les recettes plates (une par plante à distiller, une par meuble) et les listes d'ids qui traînent encore dans `camp.json`, `village_buildings` et les gabarits de quête `items_any`.
> [!important] Ni pelle ni seau (bug, 2026-08-29)
> Dix-sept matériaux (terre, sable, eau, os…) demandaient un outil qui n'existait pas : on creusait sans jamais rien récolter. Pelle et seau ajoutés, la dague récolte les os.
> [!important] `rank_min` ne servait à rien (bug, 2026-08-29)
> Les quêtes ignoraient le rang de guilde : un novice pouvait prendre la purge de donjon dès son inscription. Filtre posé, `donjon` et `purge` demandent Compagnon.
> [!important] « Agilité » n'existe pas (bug, 2026-08-29)
> Deux classes, une tomate et le Masque du Renard donnaient des points dans une stat inexistante — perdus. Reversés sur Dextérité, et l'audit vérifie désormais les noms de stats.
> [!important] Deux modules qui ne partaient jamais (2026-08-29)
> Dérobade et Meute n'avaient pas de champ `effet` : l'assembleur les ignorait en silence. Corrigé, et le test assemble désormais une vraie séquence au lieu d'un plan fabriqué à la main.
> [!important] Alternance, le dernier module non résolu (2026-08-29)
> Une séquence peut porter deux noyaux si elle porte Alternance : un emploi sur deux part avec l'un, puis avec l'autre. **À juger** : deux capacités en un slot, au prix de +2 ticks — trop fort, ou juste assez pour valoir le détour ?
> [!important] La mémoire du terrain se décalait (bug, 2026-08-29)
> `modifs_terrain` et `portails` étaient indexés par la grille glissante : après une traversée de cellule, la régénération réécrivait le terrain **au mauvais endroit**. Indexés par position monde depuis.
> [!important] Les feux traversaient les cellules (bug, 2026-08-29)
> `feux` et `eau_active` indexent des tuiles ; rien ne les vidait au changement de grille — un incendie continuait dans la cellule d'arrivée, sur des index sans rapport. Corrigé et testé.
> [!important] Les glyphes se voient — sauf ceux de L'Ombre (2026-08-29)
> L'IA contourne les glyphes comme le feu, sauf ceux posés sous Dissimulation. Le talent de L'Ombre a enfin un effet. **À juger** : un piège visible qu'on doit forcer l'ennemi à traverser — meilleur jeu qu'un piège gratuit ?
> [!important] L'arrachage de la tempête (2026-08-29)
> Une tempête emporte jusqu'à trois tuiles très fragiles et exposées par heure (chaume, paille) ; la pierre et le bois ne bougent pas. **À juger** : est-ce qu'on le remarque, ou est-ce trop discret pour valoir la peur d'une tempête ?
> [!important] Les anneaux de transmutation (2026-08-29)
> Le quatrième des cinq accès au cycle existe : amplification et transmutation du vecteur, sur les anneaux et les amulettes, dans l'ordre de résolution de la note. **À juger** : fermer un élément pour concentrer sa chaîne — est-ce un vrai choix face au râtelier ?
> [!important] Le suiveur territorial (2026-08-29)
> Un résident peut suivre chez toi sans occuper une place d'escorte, et rentre à son poste dès que tu sors du territoire. **À juger** : est-ce que ça sert vraiment (escorter un chantier, un raid), ou est-ce un ordre de plus dans un menu déjà long ?
> [!important] Les deux voies manquantes des races cachées (2026-08-29)
> Source maudite (vampire) et autel du rituel (lycanthrope) dans les étages profonds — jusqu'ici seules la morsure et la mort en corruption ouvraient ces races. **À juger** : une transformation irréversible sans avertissement, au clic droit — audacieux ou cruel ?
> [!important] Le registre d'élevage suivait mal ses espèces (2026-08-29)
> La clé de variété était figée à couleur|motif : luciole, coquillage et truite confondaient leurs variétés. Elle suit les loci de l'espèce, et l'écran rend les six modes de la note. **À juger** : 96 variétés de lucioles — la profondeur est-elle lisible, ou faut-il moins de combinatoire ?
> [!important] Les tooltips manquants (2026-08-29)
> Douze tooltips contextuels au lieu de quatre : récolte, cueillette, lecture, capacités, faim, claim, recrutement, construction, nage, feu, couvée, raid. **À juger** : arrivent-ils au bon moment, et le journal est-il le bon endroit pour les montrer ?
> [!important] Les routes entre royaumes (2026-08-29)
> Deux capitales voisines et non hostiles sont reliées par une route ; les royaumes en froid restent isolés. **À juger** : la carte se lit-elle mieux avec ces liens (qui est ami avec qui se voit d'un coup d'œil) ?
> [!important] La Discrétion sert enfin (2026-08-29)
> La compétence réduit la portée à laquelle on est repéré (2 %/niveau, plafond 60 %, +4 niveaux la nuit). **À juger** : un rôdeur peut-il traverser un camp de bandits sans être vu, et est-ce que ça doit être possible ?
> [!important] La traduction anglaise avait 4 % de couverture (2026-08-29)
> Le pipeline `tr()` était en place, mais `en.csv` n'avait pas suivi le contenu depuis l'étape 1 : 80 clés sur 1 983. Outil de mesure + première passe (options, tuiles, statuts, compétences, classes, races). **À juger** : les noms de classes en anglais (The Ferryman, The Hourglass…) sonnent-ils juste ?
> [!important] Compétences fantômes des classes cachées (2026-08-29)
> Cinq classes cachées donnaient des points dans des compétences inexistantes (`arcanes`, `tir`, `artisanat`, `perception`) : corrigé, et l'audit des données le vérifie.
> [!important] L'huile d'arme (2026-08-29)
> Elle ne faisait rien : le bonus de feu était écrit mais jamais lu. Corrigé, et consommé à la fin du combat.
> [!important] Le tannage, et le trophée qui se mérite (2026-08-29)
> La famille de matériaux `cuir` n'avait aucune source : deux peaux tannées la produisent désormais. Le trophée et le tapis demandent une peau. **À juger** : deux peaux pour un cuir — est-ce le bon prix pour une armure légère ?
> [!important] Dix espèces d'élevage (2026-08-29)
> Luciole (séquence de rythme, colonie de 6) et truite d'étang (records de taille, eau tempérée) portent les deux derniers types de loci. **À juger** : dix espèces suffisent-elles à faire sentir la collection, ou faut-il pousser vers les trente-cinq groupes ?
> [!important] Les paliers d'élevage (2026-08-29)
> Les neuf paliers du registre rendent leur effet : potentiel, capture, éclosion, chatoyants, prix des collectionneurs. **À juger** : les deux premiers paliers (25 et 75 variétés) arrivent-ils assez tôt pour donner envie de continuer ?
> [!important] Les IA empruntent les portails (2026-08-29)
> Une brèche ouverte sert à tout le monde : poursuivants, bêtes, assaillants. **À juger** : laisser un portail près du camp devient-il un piège intéressant, ou une punition qu'on n'avait pas vue venir ?
> [!important] Le courant (2026-08-28)
> Ce qui flotte descend : un être léger dans un écoulement dérive d'une tuile par pas, les objets au sol aussi. **À juger** : perdre son butin au fil de l'eau — péripétie mémorable, ou frustration ?
> [!important] La lave (2026-08-28)
> Des mares de lave dès l'étage 5 : 3d6 au contact, elles enflamment autour et se figent en obsidienne au contact de l'eau. **À juger** : une mare de lave dans un couloir de donjon — obstacle lisible, ou mort injuste quand on recule en combat ?
> [!important] Le feu de tuile (2026-08-28)
> Foudre, canicule et bombes enflamment ; le feu court d'arbre en arbre (×2 sous le vent), brûle qui s'y tient, la pluie l'éteint. **À juger** : une forêt qui part en fumée à cause d'une bombe — spectaculaire, ou punitif (la cueillette et le bois s'en vont) ?
> [!important] Affixes réveillés (2026-08-28)
> Nocturne, du danger, des sources, du porteur : quatre affixes qui attendaient leurs systèmes sont actifs. **À juger** : une arme « du danger » qui ne mord que dans les cellules corrompues — une raison d'y aller, ou un objet qu'on oublie ?
> [!important] La cueillette sauvage (2026-08-28)
> Des plantes sauvages par biome, cueillies d'un E, qui repoussent hors des claims. **À juger** : la moitié d'une récolte cultivée par plante sauvage — la cueillette vaut-elle le détour, ou rend-elle le champ inutile ?
> [!important] Postures et échange des compagnons (2026-08-28)
> Trois postures (défensive, agressive, évite), retour à la base, écran d'échange où le compagnon s'équipe de ce qu'on lui donne. **À juger** : un compagnon en posture défensive qui refuse de poursuivre au-delà de 6 tuiles — protecteur ou passif ?
> [!important] Le retrait de l'eau (2026-08-28)
> Une nappe qui n'est plus alimentée se rétracte, la canicule assèche les flaques, une source élevée disparaît. **À juger** : combler la source d'un ennemi pour assécher sa tranchée — manœuvre lisible, ou exploit ?
> [!important] La foudre de l'orage (2026-08-28)
> Une heure d'orage, un impact pondéré par hauteur et conductivité, 3d8 en zone et dans l'eau connexe. **À juger** : un impact par heure est-il assez pour qu'on pense à s'abriter, sans que l'orage devienne une loterie ?
> [!important] L'automate d'eau (2026-08-28)
> Creuser au bord d'un lac inonde la tranchée, un talus endigue, la pluie remplit les creux d'un niveau ; l'eau ne se retire pas encore. **À juger** : l'inondation d'une tranchée de siège — arme tactique lisible, ou piège agaçant ?
> [!important] Coordonnées : la simulation parle en monde, l'écran et le joueur en local (2026-08-28)
> Le designer a vu « case (65879, …) » : la fenêtre glissante place les tuiles en coordonnées monde (cellule × 128 + tuile). C'est voulu côté simulation (une seule grille continue, aucune conversion dans la logique), mais **jamais côté rendu ni côté affichage** : `_ecran` soustrait désormais l'origine de la fenêtre (les pixels restent petits — c'était la vraie cause des polygones dégénérés et du risque de jitter), et le HUD comme le journal parlent en **tuiles locales à la cellule (0-127)**.
> [!important] « Invalid polygon data » : plus aucun draw_colored_polygon en coordonnées monde (2026-08-28)
> Le designer a vu l'erreur revenir dans le brouillard (`_dessiner_brouillard`). Tous les polygones du client (sol, blocs, brouillard, mer, glyphes) passent désormais par `_poly` : un éventail de triangles `draw_primitive`, que la triangulation float32 ne peut plus juger dégénéré.
> [!important] Le raid se lit (2026-08-28)
> Capture `--raid` : un raid réel en cours n'apparaissait nulle part à l'écran (assaillants à 60 tuiles, journal seul). Le HUD affiche désormais « RAID : n assaillant(s) · le plus proche à d tuiles · t ticks avant leur retrait », et une **flèche rouge** près du personnage pointe vers l'assaillant le plus proche tant qu'il est à plus de 6 tuiles. L'atelier affiche le niveau de recette (≥ 2).
> [!important] Fuzz : deux bugs de grille trouvés et corrigés (2026-08-28)
> `scenes/tests/fuzz.tscn -- --pas N --graine G` : 1 500 intentions au hasard (camp puis donjon, bêtes ajoutées, horloges avancées) ; a trouvé un respawn sur le spawn du camp depuis le donjon (index hors grille) et une ligne de vue vers une position d'une autre grille — corrigés (`Grille.ligne_de_vue` refuse une position hors grille, `_respawn` ignore un spawn hors grille).
> [!important] Création : les talents se lisent ; nuit : Discrétion +4 (2026-08-28)
> L'écran de création décrit les talents de classe et de race ; les infractions de nuit sont plus faciles à cacher.
> [!important] Poches de strates (2026-08-28)
> Des taches d'une strate plus dure ou plus tendre dans les murs des étages profonds. **À juger** : la tache se lit-elle (teinte) assez pour guider la pioche ?
> [!important] Effets uniques d'artefacts (2026-08-28)
> Second souffle, vol de mana, chaîne éternelle — réservés à la rareté artefact. **À juger** : trois uniques suffisent-ils à rendre le boss d'un donjon majeur désirable ?
> [!important] Neige et gel (2026-08-28)
> Sous la neige chaque pas coûte un tick de plus ; sous 0 °C la mer gèle et se traverse à pied. **À juger** : un hiver qui gèle la baie ouvre-t-il des raids (et des fuites) intéressants ?
> [!important] La nage (2026-08-28)
> L'eau se traverse à la nage (coût double, Athlétisme), le souffle est une jauge (30 s + Endurance × 2), on coule si on est en surcharge — refus —, mêlée −2 dés et pas de Feu dans l'eau. **À juger** : la mer ouverte à la nage — le monde devient-il trop facile à traverser, ou la jauge de souffle suffit-elle à faire respecter les rives ?
> [!important] Treize potions (2026-08-28)
> Résistances, vision nocturne, antipoison, poison de lame — les statuts savent accorder un tag et empoisonner une lame. Le poison de lame est illégal dans 80 % des royaumes (loi générée, usage = infraction). **À juger** : la confiscation suffit-elle comme peine ?
> [!important] Les 17 statuts (2026-08-28)
> Gel, Confusion, Régénération, Peau de pierre, Béni rejoignent les données ; l'eau éteint la brûlure. **À juger** : 30 % de pas au hasard sous Confusion — drôle ou rageant ?
> [!important] Le bestiaire complet (2026-08-28)
> 19 races animales, réparties par biome. **À juger** : un ours polaire à nv 18 sur la toundra de départ — danger lisible ou mur ?
> [!important] Les 22 plantes et trois potions (2026-08-28)
> Buissons, herbes, champignons, décoratives : plantables au champ ; amanite et belladone empoisonnent ; achillée, sauge et fleurs distillent soin, mana, charisme. **À juger** : sans cueillette sauvage, les herbes ne se trouvent qu'en les plantant — d'où viennent les premières graines ?
> [!important] Le lieu se lit, le personnage reste net (2026-08-28)
> Le HUD affiche les deux éléments dominants du lieu (« lieu : Feu 34 % · Eau 28 % ») ; en donjon, le personnage et les tuiles adjacentes ne sont plus voilés (capture vérifiée) — deux points d'À juger réglés par la lisibilité.
> [!important] Bouclier : la compétence réduit le coût (2026-08-28)
> Esquive active et Boucliers vérifiés codés ; seul manquait le `/ skill_factor(N_bouclier)` sur l'endurance à l'impact. **À juger** : un bouclier de haut niveau rend-il la garde trop gratuite ?
> [!important] Niveaux de recette (2026-08-28)
> Relire un plan connu monte la recette (1 → 5, 10 doublons en tout) et resserre l'aléa de qualité. **À juger** : un doublon de parchemin est-il perçu comme un gain, ou reste-t-il du loot mort ?
> [!important] L'arme mixte choisit son segment (2026-08-28)
> Le vecteur complet des armes assemblées compte enfin ; une arme à deux éléments (≥ 25 %) pose le segment de l'un ou l'autre, au choix. **À juger** : ce choix rend-il le mixte désirable, ou le mono-élément reste-t-il roi ?
> [!important] Le voile du donjon, vérifié en capture (2026-08-28)
> Le voile était dessiné sur la couche additive des halos — un noir additif n'assombrit rien : il vit désormais sur sa propre couche (`voiles`). Capture `--donjon` ajoutée. **À juger** : le voile couvre aussi le personnage — le garder net dans le noir, ou le laisser s'y fondre ?
> [!important] Palette de sol par étage (2026-08-28)
> Calcaire, ardoise, basalte, granit, granit noir : la dureté du mur monte avec l'étage. **À juger** : le changement de matériau se lit-il à l'écran (teinte) et à la pioche ?
> [!important] Effets d'équipement (2026-08-28)
> Vitesse, régénération, surchauffe, poids, faim, pas silencieux, immunité au poison, détection des trésors : tous branchés. **À juger** : 1 PV / 200 ticks hors combat, est-ce une régénération qui se sent ?
> [!important] Le lieu (Wu Xing hors combat) (2026-08-28)
> Le mana coûte 15 % de moins quand le lieu porte ton élément, 15 % de plus quand il le domine ; Terroir lit le lieu. **À juger** : sans affichage du vecteur du lieu, le joueur peut-il le sentir ? (à mettre dans la fiche du lieu de la carte)
> [!important] Cataclysme (2026-08-28)
> Un cratère de 7 × 7 pour 60 ticks, 40 de mana, toute l'endurance, une fois par combat. **À juger** : le pari des 60 ticks se lit-il sur la timeline, et le cratère réécrit-il vraiment le champ de bataille ?
> [!important] Armes fantomatiques (2026-08-28)
> Une lame pure invoquée pour 10 de mana et 1 de mana / 10 ticks, ×0,7. **À juger** : la pureté vaut-elle 30 % de dégâts et l'entretien pour un mage qui tourne les cinq éléments ?
> [!important] Empoigne (2026-08-28)
> L'effet `saisie` des modules est câblé : tout le monde peut saisir et lancer par capacité, le Porteur le fait gratuitement. **À juger** : 12 d'endurance pour une saisie — est-ce que ça vaut un coup ?
> [!important] Terrasser et régénération (2026-08-28)
> Tranchée à mains nues, talus à la pioche ; hors claim, le monde efface tes traces chaque semaine. **À juger** : la régénération hebdomadaire est-elle trop rapide pour qu'une tranchée de siège serve ?
> [!important] Incarnation (2026-08-28)
> Prendre le contrôle d'un compagnon — jouer le loup, le cerf, le mouton ultime ; l'ancien corps te suit. **À juger** : perdre les mains, la lecture et la parole — c'est un défi ou une impasse ?
> [!important] Le Lycanthrope (2026-08-28)
> Forme bestiale à volonté (×1,5, griffes et crocs, ni capacité ni dialogue), forcée une nuit sur trente ; transmis par morsure. **À juger** : la nuit forcée tombe-t-elle au mauvais moment assez souvent pour être une vraie malédiction ?
> [!important] Le Spectre (2026-08-28)
> Mourir en zone corrompue sans Renaissance → spectre : ×0,3 physique, murs traversés, sans armure ni soins de bouche, les civils fuient. **À juger** : un état qu'on ne choisit pas et qui ferme le commerce — assez de compensation ?
> [!important] Le Vampire (2026-08-28)
> Mordu → vampire à l'aube ; +3 la nuit, brûle au jour, jauge pleine d'une morsure, plus de plats. **À juger** : être transformé sans l'avoir choisi — malédiction jouable ou punition ?
> [!important] Aciers alliés et caoutchouc (2026-08-28)
> Trois recettes industrielles de plus à la forge. **À juger** : un acier inox sans élément — muet mais dur — vaut-il le détour face à un acier trempé qui parle Métal ?
> [!important] Propagation de la lumière (2026-08-28)
> Carte 0-15 par flood fill, murs opaques, voile par tuile en donjon. **À juger** : le donjon sans torche est-il oppressant ou seulement illisible ?
> [!important] Le Fossoyeur et L'Engrenage (2026-08-28)
> Relever les cadavres 60 ticks (réputation −10 par relève) ; une tourelle portative qui mange le carquois. **À juger** : la cadence de 4 ticks de l'affût — trop rapide pour le carquois, trop lente pour peser ?
> [!important] Le Masque et Le Sceau (2026-08-28)
> Masques = statuts cumulables par deux, à 0 tick, garde refusée ; glyphes permanents à 2× mana, déclenchés à distance. **À juger** : trois masques suffisent-ils à faire sentir une classe ?
> [!important] Le Passeur et Le Sablier (2026-08-28)
> Deux portails repositionnables (mana max −30 %) ; voler du tempo contre de la santé. **À juger** : les portails valent-ils leur mana pour un combattant, ou seulement pour un bâtisseur ?
> [!important] L'Écarlate et Le Porteur (2026-08-28)
> Jauge de sang (dégâts subis → jusqu'à ×1,8, vidée par tout soin) ; saisir et lancer un être adjacent. **À juger** : vider la jauge d'un coup au moindre soin est-il trop punitif ?
> [!important] L'Ombre, Le Rieur, le jet de coup (2026-08-28)
> Critiques ×1,5 sur 20 et coups ratés sur 1 pour tous ; le Rieur élargit les deux queues et relance une fois par combat ; l'Ombre se dissimule après une mise à mort et frappe moins bien de face. **À juger** : 5 % de coups ratés — frustrant en début de partie ?
> [!important] Statut bétail (2026-08-28)
> Résident ou bétail, au choix du joueur ; l'abri = enclos ou pièce ; rétrograder un PNJ coûte −30 de relation. **À juger** : traiter un roi en bétail — le prix se sent-il ?
> [!important] Palier industriel (2026-08-28)
> Recettes industrielles cachées, apprises par des plans (ruines profondes, forgerons) ; verre trempé, brique réfractaire, béton. **À juger** : 8 % de plans en profondeur — trop rare, trop fréquent ?
> [!important] Lumière locale (2026-08-28)
> Torche en main = vue la nuit mais détection accrue ; cible dans le noir vue de moins loin. **À juger** : la nuit devient-elle un vrai enjeu d'éclairage de la base (torchères, lanternes) ?
> [!important] Communion des cinq (2026-08-28)
> L'élément de l'arme du Souffle tourne seul (2 mana par cran). **À juger** : la rotation automatique rend-elle la chaîne lisible ou incontrôlable ?
> [!important] Assemblage de capacités et Renaissance (2026-08-28)
> Composer ses capacités depuis les modules appris (menu Capacités), slots par niveau d'arme ; module Renaissance du domaine Vie. **À juger** : la composition en liste (séquence ordonnée) se comprend-elle sans schéma ?
> [!important] La Mèche — chaîne d'amorces (2026-08-28)
> Première classe cachée en données ; une explosion amorce les bombes dans son rayon. **Manque identifié** : pas d'écran pour assembler une capacité depuis les modules appris — prochain chantier.
> [!important] Bombes et explosions (2026-08-28)
> Une bombe à l'établi, lancée depuis la hotbar, détruit les murs selon `durete < P × (1 − d/R)` et blesse tout le monde dans le rayon. **À juger** : P = 40 / R = 2 / 3d6 — assez pour ouvrir un mur de labyrinthe (dureté ~20-30 ?), pas assez pour raser une pièce ?
> [!important] Main du métal et Fiole vive (2026-08-28)
> Reforger un composant sans perdre les affixes ; potions partagées aux alliés adjacents au double d'ingrédients. **À juger** : la reforge sans écran dédié (inventaire, deux sélections) est-elle compréhensible ?
> [!important] Main du métal et Fiole vive (2026-08-28)
> Reforger un composant sans perdre les affixes ; potions partagées aux alliés adjacents au double d'ingrédients. **À juger** : la reforge sans écran dédié (inventaire, deux sélections) est-elle compréhensible ?
> [!important] Talents de classe et de race (2026-08-28)
> Cadre des talents, cinq talents de classe visibles et les trois de race, apprentissage auprès d'un PNJ (Le Vent, l'Humain). **À juger** : le Sabre sent-il sa rotation gratuite ? la Paume tisse-t-elle vraiment la chaîne d'un groupe ?
> [!important] Trésors et artefacts (2026-08-28)
> Rareté artefact au-dessus des fourchettes, garantie sur le boss d'un donjon majeur (≥ 4 étages). **À juger** : un artefact se sent-il « fini par nature » sans effets uniques hors pools ?
> [!important] Habitat et faim des PNJ (2026-08-28)
> Détection de pièces 2D (portes, murs, ≥ 6 tuiles, ≥ 1 meuble), humeur recalculée chaque semaine (logement, meilleure chambre, co-occupants, faim au garde-manger, dette). **À juger** : les −15 / −10 se voient-ils dans la production ? Bâtir une chambre de 6 tuiles avec une porte est-il compris sans aide ?
> [!important] La tourelle tire (2026-08-28)
> 1d6 toutes les 20 ticks à 6 tuiles pendant un raid réel. **À juger** : assez pour se sentir défendu, trop pour rendre les raids inoffensifs ?
> [!important] Routes (2026-08-28)
> Routes de royaume entre villages et capitale, tracées au sol dans les cellules, dessinées sur la carte, voyage ×0,6, boutiques ×1,3. **À juger** : le chemin de sol se lit-il comme une route ? faut-il des routes entre royaumes ?
> [!important] Le chatoyant (2026-08-28)
> 1,5 % à la naissance, ×6 par un parent, ×3 au palier 500, commandes chatoyantes ×3. **À juger** : 1,5 % se voit-il jamais sans un parent chatoyant ?
> [!important] Fiche de royaume et mesure de la Règle d'anneau (2026-08-28)
> Le détail d'un royaume voisin (écran K) donne peuple, culture, capitale, taxes, dirigeant ou vacance, villages connus, diplomatie, lois, douanes. La Règle d'anneau est **mesurée** : ×5,7 au lieu de ×15 (voir [[Règle d'anneau]]) — **à trancher** : 40/40/20 ou une autre définition du hasard.
> [!important] Prêtres et tourelles (2026-08-28)
> Chapelle et prêtre dans les villages (résurrection payante, Affaibli au retour), recette de la tourelle. **À juger** : la tourelle tire depuis (1d6 toutes les 20 ticks, portée 6) — assez pour changer un raid, ou décorative ?
> [!important] Gabarits de quêtes pour les douze guildes (2026-08-28)
> Livrer, construire, fabriquer, vendre, explorer : chaque hall a désormais quelque chose à offrir. **À juger** : les textes de quête et leur rythme (3-6 cibles).
> [!important] Entraîneurs et commandes de collectionneurs (2026-08-28)
> Deux débouchés économiques : payer un entraîneur (+10 de potentiel), livrer une variété demandée à un marchand. **À juger** : 20 or × niveau est-il un vrai puits ? la commande à un ou deux pas donne-t-elle envie de croiser ?
> [!important] Composition des plats (2026-08-28)
> Ingrédients optionnels à cocher dans l'atelier, harmonie prévue affichée avant de cuisiner. Le point « pris d'office » du parcours de jugement est fermé.
> [!important] Familles et succession, complétées (2026-08-28)
> Familles par bâtiment, naissances, héritier familial pour les monarchies, succession des maîtres de guilde à 2 semaines, titres culturels. **À juger** : la mort d'un roi se lit-elle (une ligne de journal, un titre qui change) sans écran de royaume ?
> [!important] Registre d'élevage et paliers (2026-08-28)
> Écran B, variétés / possibles, records, paliers captures et couvées. Correction au passage : planter une culture est sur **H** (L lisait déjà). **À juger** : le registre en lignes de texte suffit-il avant les silhouettes ?
> [!important] Harmonie Wu Xing des plats (2026-08-28)
> Vecteurs élémentaires des ingrédients, entrées optionnelles des recettes de plats, ×1,2 à cinq éléments. **À juger** : prendre les ingrédients optionnels d'office rend-il le puzzle lisible, ou faut-il l'écran de composition ?
> [!important] Élevage — les dix loci, filage de la soie (2026-08-28)
> `lie_au_sexe`, `carte`, `automate` codés (chat, taches de carpe, coquillage) ; la soie se file à l'atelier de tissage. L'Annexe H est couverte côté moteur ; restent l'écran de registre par groupe et les silhouettes 13×13 (sprites — plus tard, décision du designer).
> [!important] Viandes et parties paramétriques (2026-08-28)
> Les dépouilles portent les stats de la créature (potentiel de la viande, puissance de la partie), les plats somment leurs ingrédients, les potions multiplient par la puissance. **À juger** : une griffe de loup (Force 11 → ×1,1) contre une griffe de chef de bande — la différence se sent-elle ? Voir [[À juger — parcours de jeu]].
> [!important] Le parcours de jugement (2026-08-28)
> Toutes les questions « à juger » des incréments 0 → 10 sont regroupées dans [[À juger — parcours de jeu]] — un parcours d'une heure, dans l'ordre où on rencontre les choses en jouant. C'est le seul verrou avant l'étape 11.
> [!important] Élevage — les six familles (2026-08-28)
> Serpent, ver à soie, ruche, tortue, phalène en pure donnée : capture par milieu (eau, plante, arbre, appât, nuit), coûts, production de colonie, loci d'âge et acquis. **À juger** : une espèce par famille suffit-elle à sentir les six verbes ? le miel de ruche (1 par 4 abeilles) est-il trop lent ?
> [!important] Saisons et élevage, première brique (2026-08-28)
> Saisons avec écart de température, carpes capturées au filet, vivarium, couvée hebdomadaire par conditions et hérédité d'anneau, registre des variétés. **À juger** : le facteur « qui sélectionne contre qui laisse faire » (Règle d'anneau : ×15 attendu) — à mesurer en jouant ; le nom des spécimens (indices d'anneau bruts pour l'instant).
> [!important] Villes, boutiques et halls (2026-08-28)
> Capitales dimensionnées par la taille du royaume, boutiques typées sans doublon, halls de guilde tenus par un maître qui n'offre que sa guilde, hall constructible sur son territoire au rang Adepte. **À juger** : une capitale de grand royaume (9-12 bâtiments) tient-elle dans la cellule sans se marcher dessus ? l'information « quelle ville a quel hall » se lit-elle (pas encore sur la carte) ?
> [!important] Alchimie — parties de créatures, Alambic, potions de stats (2026-08-28)
> Cinq parties, cinq recettes, dix statuts (normal / fort), durée × qualité. **À juger** : +3 / +6 sur une stat pour 3 000 ticks est-il sensible ? faut-il porter la valeur de la créature source (matériaux paramétriques) ?
> [!important] Étape 10.5 — conquérir, succéder, repeupler (2026-08-28)
> Conquête de village sans massacre (gardes < 25 %, jet de Leadership/Charisme contre 2 × population, vacance −25 %, réputation à signe variable, reconquête), dirigeants en capitale et succession par vacance de 4 semaines, repeuplement hebdomadaire et villages abandonnés. **Restent** : villes/halls/boutiques par taille, familles, POI « passage ». **À juger** : la conquête est-elle lisible (un jet, un message) ? la vacance se remarque-t-elle ?
> [!important] Étape 10.4 — le monde politique, première passe (2026-08-28)
> Royaumes PNJ déterministes par secteur (capitales-villages, territoires par coût, identité, lois dont absurdes, diplomatie initiale), carte teintée, lois et infractions (détection par témoin, amende/confiscation/gardes), douanes, accords avec les voisins depuis l'écran de gestion, raids des royaumes hostiles. **Restent pour 10.5** : conquête de village, succession, repeuplement et décimation, villes et halls. **À juger** : la loi absurde fait-elle rire ? la carte politique se lit-elle ? les tarifs sont-ils lisibles dans l'écran de commerce ?
> [!important] Étape 10.3 — un royaume qu'on attaque (2026-08-28)
> Défense totale (gardes, tourelles, murs, gouvernance), jet hebdomadaire de raid, raid réel au camp (assaillants au bord de la cellule, profil `assaillant`) ou abstrait (un jet), pertes proportionnelles jamais totales, réveil du dormeur, seuil de royaume et gouvernance (6 types, transition 4 semaines). **À juger** : la probabilité de raid (0,05 de base) et l'échelle `valeur/20`, la lisibilité d'un raid qui arrive pendant la nuit, la tourelle sans recette.
> [!important] Étape 10.2 — le territoire produit tout seul (2026-08-28)
> Parcelles (8 cultures, échéances, biome × fertilité, pluie, canicule, engrais), boutique passive (étal, trafic horaire, marge, caisse), troc des marchands à sec, rattrapage horaire hors-site et rapport d'absence au retour d'expédition. **À juger** : le troc d'office, un jour de pousse à 24 000 ticks (long ?), la récolte à la main en clic, la caisse séparée du trésor.
> [!important] Étape 10.1 — un territoire qui produit (2026-08-28)
> Revendiquer des cellules contiguës depuis la carte (50 or × cellules possédées), rôles de cases, assigner un compagnon à une fonction, humeur et logement, production et entretien hebdomadaires par formules, dette et paliers, trésor et rapport, écran Territoire (Tab → Territoire, anciennement K). **À juger** : le coût du claim, le rythme (une semaine = 21 nuits) qui rend la production lente à voir, l'écran de gestion en liste.
> [!important] Étape 9.D — recruter, apprivoiser, compagnonner (2026-08-28) : l'étape 9 est fonctionnellement complète
> Recrutement par relation (places d'escorte), ordres suis-moi / attends ici, apprivoisement des bêtes au jet universel (V), âme et résurrection à l'autel domestique, âge et vieillesse des PNJ. **À juger** : le compagnon qui suit sans postures (il attaque tout ennemi à portée), le coût de résurrection (20 or × niveau × 1,5), la fréquence des morts de vieillesse. Restent pour l'étape 10 : royaumes, villes, économie, claims, lois.
> [!important] Étape 9.C — l'information et la réputation valent quelque chose (2026-08-28)
> Relations par PNJ / village / globale avec les paliers de la note (hostile à vue, prix, quêtes refusées, confidences), fiche PNJ à révélation progressive, rumeurs qui révèlent des POI, dérive de rédemption, quêtes procédurales du garde (chasse, bêtes, donjon) avec XP et rangs de guilde. **À juger** : le rythme (une quête = 3-8 cibles, 15 or × niveau), la lisibilité des paliers dans l'écran de dialogue, frapper un civil qui rend tout le village hostile après deux coups.
> [!important] Étape 9.B — un village vivant (2026-08-28)
> Routines horaires (poste / place / lit), gardes en patrouille, faune de surface par biome (cerf, renard, loup, sanglier, aigle, scorpion), loups en meute la nuit, spawn/despawn hors de vue. **À juger** : le mouvement des PNJ (pas glouton : ils peuvent buter sur un mur), la densité de faune (12 bêtes), la nuit qui devient vraiment dangereuse.
> [!important] Étape 9.A — un village visitable avec un marchand et un dialogue (2026-08-28)
> Hameaux à 4 % des cellules (place, 3-5 bâtiments, chemins, meubles), PNJ nommés par culture, dialogue contextuel (Parler / Commercer / Partir, répliques conditionnées sans répétition), or et commerce (prix suggéré détaillé, marchand qui refuse à sec). **À juger** : la lisibilité du hameau en blocs, les noms générés (sonorité), le rythme des prix (un lingot de fer vaut 12 or : trop ? trop peu ?). Routines horaires, faune, réputation, quêtes, compagnons suivent (9.B-9.D).
> [!important] Étape 8.4 — jour-nuit et météo (2026-08-28) : l'étape 8 est fonctionnellement complète
> Heure et météo dans l'en-tête, nuit qui assombrit l'écran et réduit la vue, halos des lumières, saut de nuit, 10 états météo en données avec température ressentie et ses effets. **À juger** : l'obscurité de la nuit (trop ? pas assez ?), la fréquence des pluies/orages, la sévérité du froid/chaud sans vêtements. Reste hors périmètre pour l'instant : l'automate d'eau, la faune de surface (étape 9), les claims au-delà du camp (étape 10).
> [!important] Étape 8.3b — la dérive de la corruption (2026-08-28) : l'étape 8.3 est complète
> Delta par cellule, passage hebdomadaire (infection, nettoyage, décroissance, civilisation), donjons majeurs en zone mortelle, nettoyage → grâce 1,5 jour → l'entrée disparaît, réapparition ∝ corruption. La carte lit la corruption effective. **À juger** : on ne verra la dérive qu'en dormant beaucoup (une semaine = 21 nuits) — faut-il un affichage du delta ? La règle LOD « explorées + voisines ».
> [!important] Étape 8.3a — carte du monde, POI, donjons de surface, voyage rapide, case de départ (2026-08-28)
> M ouvre la carte (33×33 cellules, biomes, danger en 3 niveaux, POI, flèches pour défiler) ; clic sur une cellule explorée : voyage rapide (384 ticks par cellule) ; les donjons sont posés à 6 % des cellules avec une entrée scellée ; à la création, on choisit sa case sur la carte. **À juger** : la lisibilité de la carte (une couleur par biome), la règle « voyage seulement vers l'exploré », le coût en temps du voyage. Corruption hebdomadaire, nettoyage/réapparition des donjons, villages : 8.3b et étape 9.
> [!important] Étape 8.2c — minimap et sauvegarde (2026-08-28)
> Minimap 256×256 en haut à droite (N : zoom, ⇧N : masquer), chunks explorés en teinte dominante ; F6 sauvegarde, F7 charge, autosave 5 min, un dossier `user://sauvegardes/monde/` en JSON. **À juger** : la lisibilité de la minimap (teintes par matériau), la place qu'elle prend, le fait qu'on ne sauvegarde qu'en surface.
> [!important] Étape 8.2b — tectonique, mer, 12 biomes (2026-08-28)
> Plaques, continentalité warpée, seuil calibré à 35 % de terres, chaînes sur les sutures, mer en tuiles d'eau (hauteur 8), les 12 biomes. La cellule de départ reste au centre du monde : elle peut tomber en mer — `planete.cellule_depart` est alors déplacée au premier point de terre trouvé en spirale (garde-fou de [[Début de partie]], < 200 tuiles marchables). **À juger** : la forme des côtes, la part de mer visible depuis le camp, la lisibilité des biomes par la couleur du sol et les arbres.
> [!important] Étape 8.2a — un monde continu qu'on traverse à pied (2026-08-28)
> Fenêtre glissante de 3×3 cellules, coordonnées monde, recentrage au changement de cellule, cache + pré-génération en thread, modifications et découvertes capturées par cellule (un mur posé dans une cellule qu'on quitte y est encore au retour). **À juger** : le recentrage (un à-coup au passage d'une cellule ? mesuré ~150-300 ms quand la cellule n'est pas pré-générée), la continuité visuelle entre cellules. Tectonique, eau, autres biomes, minimap et sauvegarde sur disque suivent (8.2b-c).
> [!important] Végétaux en billboards (2026-08-28)
> Instruction du designer : arbres et plantes sont des sprites billboard dessinés par code (silhouettes feuillu/conifère/palme/buisson/herbe, teinte de l'essence), plus des blocs. Plantes sauvages récoltables à la faucille. **À juger** : les silhouettes (assez lisibles ? assez variées ?), la taille des arbres par rapport aux personnages, l'occultation d'un être derrière un arbre.
> [!important] Fluidité des déplacements (2026-08-28)
> Retour du designer : « les déplacements ne sont pas fluides ». Causes : le terrain statique était **entièrement redessiné à chaque pas** (le champ de vue change à chaque pas → 1 700 tuiles), et les êtres comme la caméra **sautaient** de tuile en tuile. Corrigé : le brouillard est une **couche à part** (opaque sur le jamais-vu, translucide sur le mémorisé) redessinée seule ; le terrain ne se redessine que quand la fenêtre se décale ; les paperdolls et la caméra **glissent** vers leur tuile (interpolation exponentielle, ≈ 0,2 s) ; les touches ZQSD sont relues toutes les 50 ms. **À juger** : la vitesse du glissement, le rendu translucide du mémorisé.
> [!important] Étape 8.1 — une cellule de surface générée (2026-08-28)
> Le camp est désormais une cellule du monde : 8 couches de bruit, 4 biomes, sol coloré par son matériau, arbres/rochers/filons selon le biome, relief plat avec 2-5 accidents posés (talus, estrade, piton, cratère, gorge). **À juger — c'est ici que se valide la décision « plat + exceptions »** : le camp a-t-il l'air d'un lieu ? Les accidents sont-ils assez nombreux/visibles ? La couleur de sol par biome (terre, herbe, sable) suffit-elle à lire le biome ? Tectonique, eau, streaming et carte suivent (8.2-8.3).
> [!important] Étape 7.2 — faim, nourriture, cuisine, poids porté (2026-08-28) : l'étape 7 est complète
> Jauge de faim dans l'en-tête, 18 consommables, viande des animaux, plats à la Cuisine avec potentiel, manger (inventaire : G ou bouton), poids porté avec surcharge. **À juger** : la vitesse de la faim (2 h 30 de jeu actif), le −10 % de stats sous 25, la capacité (un humain Force 5 : 55 — une forge de 80 ne se porte pas, c'est voulu), la lisibilité du poids dans l'en-tête.
> [!important] Étape 7.1 — le camp de base (2026-08-28)
> Une cellule de camp plate (arbres, rochers, filons de surface, coffre de départ avec hache, pioche et lit de paille), l'entrée du donjon (E), retour au camp en sortant. Poser meubles et stations (inventaire : P), murs (M) et portes (O) à la tuile, démonter au clic, coffres (ranger/prendre), dormir sur un lit (Reposé, potentiel, respawn). **À juger** : le camp vide au départ est-il assez lisible ; le rythme (récolter du bois à la hache, scier, poser) ; la mort en donjon qui renvoie au camp. Faim, nourriture, cuisine et poids porté suivent (7.2).
> [!important] Écrans : inventaire, atelier, feuille (2026-08-28)
> Demande du designer (« tu as pu faire tous les menus, l'inventaire ? » — non, tout était en texte). Trois panneaux en Control nodes, l'infobulle exhaustive, la navigation récursive des recettes, desequiper/jeter. **À juger** : la lisibilité des panneaux (police 13, fond sombre), le fait que le jeu continue de tourner derrière un écran ouvert (temps réel d'exploration : un ennemi peut arriver), l'absence de glisser-déposer (liste + boutons seulement).
> [!important] Étape 6.4 — composants et assemblage (2026-08-28) : la boucle de craft est complète
> Pioche → filon → fondre → façonner un composant (Enclume) → assembler à l'Établi une « Dague en fer » avec sa qualité, son vecteur Wu Xing, sa vitesse de manche ; l'objet s'équipe et frappe. **À juger** : l'atelier texte devient long (plates + composants + objets) ; la qualité aléatoire (0,85-1,15) est-elle lisible ; le poids 0,70 de la tête suffit-il à ce que le manche compte.
> [!important] Étape 6.3 — stations et transformations plates (2026-08-28)
> F ouvre l'atelier : les recettes des stations du sac (l'établi de départ, les stations trouvées en coffre). Fondre, scier, tailler, tisser. **À juger** : l'atelier en liste texte (chiffre = fabriquer), le fait de porter une forge dans le sac sans poids porté, les 20 ticks de base.
> [!important] Tables de sculpture abandonnées (2026-08-28)
> Instruction du designer : plus d'éditeur, plus de modèles sculptés, plus d'accès par rang de guilde. Callouts posés sur les trois notes de sculpture et sur celles qui y renvoyaient.
> [!important] Étape 6.2 — récolte en donjon (2026-08-28)
> Filons colorés dans les murs, pioche dans les coffres, clic sur un mur avec la pioche en main : récolte selon la formule de la note (Fer sur pierre : 6 ticks), matériaux empilés dans le sac. **À juger** : la lisibilité des filons (la couleur de la palette suffit-elle ?), la densité (8-16 par étage), le fait que creuser sans outil détruise le matériau.
> [!important] Étape 6 ouverte — matériaux en données (2026-08-28)
> Le designer a relancé sans juger le jalon 5 : l'étape 6 s'ouvre. Premier incrément : les **155 matériaux** des catalogues en données, validés au boot (couleur unique, tags dérivés, Wu Xing). Rien de visible encore ; la récolte en donjon vient ensuite.
> [!important] Brouillard de guerre (2026-08-28)
> Le joueur découvre l'étage avec sa vision (Perception, ligne de vue) ; les tuiles vues restent en grisé, les êtres hors de vue disparaissent. **À juger** : la portée (Perception 5-10 tuiles, est-ce trop court dans des salles de 16 ?), le grisé des tuiles mémorisées, l'absence d'indice pour un ennemi qui s'approche hors de vue (un son ? une ombre ?).
> [!important] Cellule 128×128, réseau maillé (2026-08-28)
> Sur instruction du designer : retour à 128×128, 14-24 salles, chaque salle reliée à ses 3 voisines les plus proches + boucles + impasses longues, virages plus fréquents. **À juger** : la densité (trop de couloirs ?), la longueur d'une expédition sur un étage de 128×128, le temps de trame avec un étage plus grand.
> [!important] Donjon façon Elin / ToME, faces des murs corrigées (2026-08-27, nuit)
> Salles de trois tailles + couloirs sinueux, boucles et impasses (plus de labyrinthe sur trame). Les blocs de mur dessinaient leurs **faces arrière** (d'où les « triangles ») : ce sont maintenant le dessus et les deux faces avant, sans grille. Couloirs de 2 à 3 tuiles et blocs de 2 niveaux (`hauteur_vue`) : en iso, un couloir d'une tuile disparaissait derrière les blocs devant lui. Les êtres hors de la fenêtre de vue ne sont plus redessinés : 5 ms par image dans le donjon (contre 20). **À juger** : la proportion petites/grandes salles, la sinuosité des couloirs, la hauteur des blocs (2 niveaux) ; si les couloirs restent trop cachés, l'alternative est un rendu « en coupe » (murs devant un sol visible dessinés plus bas ou translucides).
> [!important] Cellule 64×64, salles procédurales, murs en blocs (2026-08-27, soir)
> Sur instruction du designer : cellule de 64×64, salles rectangulaires tirées au hasard (façon Elin, 4-8 par étage, 4-9 de côté, 1-3 portes), tous les murs de la fenêtre dessinés en blocs pleins. **À juger** : la taille des salles et la densité du labyrinthe dans 64×64 ; le relief des blocs (3 niveaux de hauteur vue, arête dessinée) ; 16 ms par image en moyenne dans le donjon avec tous les blocs (pire 25 ms), à surveiller.
> [!important] Donjon refait en labyrinthe (2026-08-27)
> Sur instruction du designer : un étage = une cellule de 128×128, labyrinthe + salles, murs destructibles (clic sur un mur adjacent, 10 ticks), deux escaliers par étage, bord en roche. Le dessin du terrain est **fenêtré** autour du joueur (rayon 24 tuiles) : 13 ms par image en moyenne dans le donjon (6 ms en arène), pire 21 ms — au-dessus de la cible de 16,7 ms en pointe, à surveiller (`capture.tscn -- --arene 3`). **À juger** : la lisibilité du labyrinthe en iso (couloirs de 3 tuiles), le coût de creuser (10 ticks / 6 d'endurance : trop bon marché ?), la taille de la cellule pour une expédition (8 à 14 salles par étage).
> [!important] ⭐ Étape 5 — le jalon est atteignable : entrer, combattre, looter, progresser, ressortir (2026-08-27)
> Tab jusqu'au donjon (ou création puis Tab ×3) : descendre par la cage dorée, remonter et sortir par l'entrée verte ; les étages restent dans l'état où on les laisse ; l'écran d'expédition récapitule et une nouvelle expédition enchaîne avec le même personnage. **C'est le jalon « à juger honnêtement avant toute suite »** ([[Ordre de construction]]) — le code s'arrête ici en attendant ce jugement : jouer trois expéditions, remplir la grille qualitative de [[Prototype de combat — spécification]] § 5, et dire si l'étape 6 (matériaux, craft) s'ouvre ou si on itère.
> [!important] Étape 4 codée — progression (2026-08-27)
> Progression par l'usage réelle (courbe, potentiel, 58 compétences en données, stats qui montent par la moitié de l'XP), création de personnage au lancement (race, classe, 30 points, signe), potentiels de base race + classe + astrologie, niveaux dérivés, feuille (C), mort et respawn. **À juger** : l'écran de création texte (R/C/↑↓/+−/←→/Entrée) est-il assez clair ? Le rythme des niveaux en combat (Épée 1 après ~100 dégâts) ? Les talents de race/classe actifs attendent leurs systèmes (ne sont que des tags).
> [!important] Étape 3 codée — loot (2026-08-27)
> Affixes générateurs (36 gabarits, budget de rareté), grille de rareté par étage, effets passifs et stats effectives, coffres dans les salles, butin à la mort, monstres rares (2 %, ×2.5, drop garanti), sac (⇧chiffre pour équiper, R pour ramasser). Gemmes taillées et serties (T, plafond +15), grimoires et manuels lus (L, jet de Lecture, échecs à effet). **À juger** : les noms générés (« Épée de braise (une attaque sur 2 porte Feu) [rare] ») sont-ils lisibles ou trop bavards ? Les coffres (caisses brunes) se voient-ils ?
> [!important] Étape 2 codée — génération de donjon (2026-08-27)
> Tab après les trois arènes : un **donjon « ruine »** généré (12 salles + 8 connecteurs en JSON, graphe façon Daggerfall, 2-3 étages, escalier = E sur la cage dorée, boss au fond). Peuplé par le thème, joué avec le même combat. **À juger à l'œil** : la lisibilité des salles murées de roche, la variété des étages, la densité des créatures. Détail : [[Génération de donjon]], [[Décision — Prefabs de donjon en tuiles]].
> [!important] Étape 1 codée — rig, paperdoll, tooltips, locale (2026-08-27)
> Le combat est le vrai projet (même scène, `scenes/demo/main.tscn`) ; s'y ajoutent **`creature.tscn`**, la scène unique de tout être ([[Squelette modulaire et points d'attache]] : rigs JSON des 4 templates, équipement visible par slot, teinte par matériau, animation par pivots — en rectangles procéduraux, sans asset), les **tooltips contextuels** en données ([[Tooltips contextuels]]), `locale/en.csv` pour l'interface. **À juger à l'œil** : la lisibilité des silhouettes (humanoïde 14 segments, loup, aigle, scorpion), l'équipement visible, la frappe animée — capture `capture.tscn --arene 2`.
> **Réglage du 2026-08-27** (« propose un jeu de valeurs, on ajustera plus tard ») : engendrement +0.45, swap 3 ticks — voir [[Jauge de chaîne Wu Xing]]. Le swap est désormais mixte ✓ ; l'écart des deux voies reste hors cible (rotation entre −40 % et +30 % selon la construction comparée) : le critère est à préciser, pas les bonus. **Le designer a choisi de passer à l'étape 1** sans le « oui » formel sur le combat — le jugement d'œil reste dû, sur le vrai projet.
> 9. *Critère de perf É0* ([[Décision — Budgets et critères de performance tactiques]] : 32×32 + 10 entités, 60 fps) : mesuré par `capture.tscn --frames 120` avec `--disable-vsync` sur la machine de développement — **3,5 ms par image en moyenne, 12,5 ms au pire** (avant optimisation : 44 ms, le terrain était redessiné à chaque image ; il est désormais une couche statique, les tuiles hautes devant une entité sont redessinées par-dessus pour garder l'occultation). Reste à mesurer sur la machine de référence (PC 2020, GPU intégré).
> 8. *Rendu vérifié par capture automatique* (`scenes/tests/capture.tscn`, fenêtré) : les trois arènes se dessinent, murs et estrades lisibles, panneaux de texte à gauche/droite. Le panneau gauche recouvre le coin nord-ouest de la carte — à juger (le déplacer, ou déplacer la vue au clic milieu).
> 5. *La jauge de chaîne* (pastilles sous le personnage + ligne « chaîne : Métal → Métal ») : lit-on d'un coup d'œil où l'on en est et ce que le prochain coup fera ? Le swap d'arme (4 ticks pour +0.35) donne-t-il envie ?
>
> [!note] Démo 0 (2026-08-26, matin)
> `godot/scenes/demo/main.tscn` : grille iso 24×24 générée (hauteurs 0-20, continentalité + crête ridged), tri de profondeur, déplacement au clic par A* qui applique les **coûts de pente** de [[Hauteur de terrain ±10]] (3/5/8/∞, descente 2), et l'**horloge à ticks** de [[Boucle de tick]] : 10 ticks/s en exploration, **0 tick sans action** en combat, chaque entité agit quand son compteur est le plus bas. Un loup chasse et mord (aggro à 6 tuiles). Aucun asset — tout est polygones. Validée en headless (Godot 4.6.3). **À juger à l'œil : ouvrir `godot/` dans l'éditeur et lancer.**

> [!success] Bloquant levé le 2026-08-26
> Le catalogue [[Modules]] est **transcrit dans son schéma** — `cout_ticks` sur les 61 entrées, durées en ticks, économies séparées (mana pour les grimoires, **endurance** pour les manuels). Les 61 JSON sont écrits dans `godot/data/modules/`. Audit : [[Décision — Transcription du catalogue de modules]].

## 1. ✅ Validé — les 8 décisions post-pivot (2026-08-26, sur délégation)

- [x] [[Décision — Structure de données de la grille]] · [[Décision — Budgets et critères de performance tactiques]] · [[Décision — Sculpture en pixel art]] · [[Décision — Prefabs de donjon en tuiles]] · [[Décision — Pièces en 2D]] · [[Décision — Altitude sur 21 niveaux]] · [[Décision — Minerais et strates après le pivot]] · [[Décision — Minimap en 2D]]

## 2. Le document du prototype de combat (étape 0)

[[Ordre de construction]] : *« Prototype de combat isolé (**document séparé**) — le combat est-il bon ? Rien ne démarre avant un oui. »*
- [x] **Les sept trous du combat sont tranchés** (2026-08-26) : [[Décision — Multi-ennemis et jauge]], [[Décision — Vocabulaire d'attaque des créatures]], [[Décision — Fuite et désengagement]], [[Décision — Chaîne côté ennemis]], [[Décision — Boucliers]], [[Décision — Projectiles]], [[Décision — Esquive active]].
- [x] **Le document est rédigé** : [[Prototype de combat — spécification]] — périmètre, contenu exact, 12 jalons d'implémentation, critère de « oui » mesurable et qualitatif.

## 3. ✅ Défauts fixés pour toutes les questions de playtest

Chacune porte désormais une **valeur chiffrée implémentable** — le code ne se pose aucune question, le playtest ajuste ([[Carte — Ouvert]]) :
- [x] [[Ouvert — Axe des niveaux de recette]] (stabilité du jet) · [[Ouvert — Compensation de l'arme mixte]] (choix du segment) · [[Ouvert — Répartitions Arcane Espace Corruption]] (vecteurs A.4.6) · [[Ouvert — Fourchettes des gemmes]] (A.12 + 36 gabarits) · [[Ouvert — Saisons]] (non incluses)
- [x] [[Ouvert — Taille des salles de donjon]] (24 prefabs) · [[Ouvert — Réapparition d'un donjon]] (règle des foyers) · [[Ouvert — Tiers de monstres rares]] (un tier) · [[Ouvert — Interprétation dureté et qualité]] (clos)

## 4. Contenu à produire (données — nécessaire par étape, pas au jour 1)

- [x] **5 modules du domaine Métal** — au catalogue [[Modules]] (2026-08-26).
- [x] **Catalogue des actions de créatures** : 24 actions + 2 règles, affectations pour les 19 races animales ([[Actions des créatures]], 2026-08-26).
- [x] **Onyx** ajouté au catalogue des gemmes et à la palette (2026-08-26).
- [x] **Recettes de composants** : matrice complète bases/exotiques/sources ([[Recettes de composants]], 2026-08-26).
- [x] **Affinités de cuisine** : table complète, le Feu vient de la cuisson et le Métal du sel ([[Décision — Affinités de cuisine]], 2026-08-26).
- [x] **Surcharges Wu Xing** : les 154 matériaux passés en revue, table complète ([[Décision — Surcharges Wu Xing des matériaux]], 2026-08-26).
- [x] **Pools de noms** : les 9 cultures restantes écrites ([[Pools de noms des cultures]], 2026-08-26).
- [ ] Traductions en/ja/zh — les clés `tr()` existent dès le jour 1, les textes peuvent suivre ([[Localisation]]).

## 4 bis. Annexe H — élevage, génétique et collection *(intégrée le 2026-08-26)*

- [x] **15 notes** : mécanismes ([[Règle d'anneau]], [[Loci — les dix types]], [[Conditions de reproduction]]), contenu ([[Catalogue des groupes d'élevage]], vivarium ×3), moteur ([[Intégration de l'élevage au moteur]], [[Tests de conformité — élevage]]), et le socle des êtres ([[Blocs de l'être]], [[Apparence — données et équipement]], [[Rôles de l'être]]).
- [x] **Catalogue `species/`** squeletté avec son template ([[Décision — Pipeline de contenu]]).
- [x] **Saisons activées** à l'étape 10 — [[Décision — Saisons activées à l'étape 10]] renverse [[Ouvert — Saisons]].
- [ ] **Assets d'élevage** (étape 10) : silhouettes 13×13 des 32 espèces d'insectes, 20 motifs procéduraux, écran de registre.
- [ ] Fiches `species/` des 6 groupes recommandés au lancement (un par famille).

## 4 ter. Les trois axes et les talents *(décidé le 2026-08-26)*

- [x] [[Les trois axes — race, classe, fonction]], [[Talents de race]], [[Talents de classe]], [[Fonctions]], [[Ouvert — Changer de personnage]] + 5ᵉ contrainte permanente.
- [x] **19 classes nommées et dotées d'un talent** ([[Classes]], [[Talents de classe]]) — 8 visibles en français évocateur, 11 cachées dont 2 technologiques.
- [x] **Bestiaire restructuré** : [[Créatures]] = 19 races animales, [[Profils de PNJ]] = combinaisons tirées.
- [ ] **Modules signature** de chaque classe cachée (au-delà du talent) — contenu, étape 4+.
- [ ] **Fiches de races cachées** : Vampire, Spectre, Lycanthrope (`data/races/`) — étape 4+.
- [ ] **Pools de classes par fonction** pour la génération de PNJ ([[Talents de classe]] : classes cachées ≈ 2 %) — étape 9.

## 5. Assets à produire (aucun n'existe)

- [ ] **Étape 0-1 :** une silhouette paperdoll + quelques pièces d'équipement visibles ; les teintes des cinq éléments (jauge, effets — [[Direction artistique]]) ; l'UI de lisibilité (timeline, prévisualisations, journal — c'est LE game feel).
- [ ] **Étape 1 :** bibliothèque du **rig humanoïde 14 segments** ([[Squelette modulaire et points d'attache]]) ≈ **92 sprites** (12 têtes ×3 vues, torses, bras haut/bas, mains, jambes haut/bas, pieds) + **40 sprites d'armure** (5 constructions × 8 segments) = **≈ 130 sprites pour tous les humains du jeu**. Puis quadrupède/volant/amorphe.
- [ ] **Étape 1 :** la table `data/rigs/humanoide.json` — ordre de calque et décalages d'ancrage pour 5 orientations (3 obtenues par miroir).
- [ ] **Étape 2 :** premiers prefabs de donjon (2-3 salles + connecteurs suffisent pour valider le pipeline).
- [ ] Police UI à couverture CJK (type Noto Sans CJK) testée dans les 4 langues ([[Localisation]]).

## 6. Chantier technique (le squelette existe, le code non)

- [x] **Pipeline de contenu décidé et squeletté** ([[Décision — Pipeline de contenu]]) : `godot/data/` contient les 24 catalogues avec leurs `_template.json` et son README — ajouter du contenu = ajouter un fichier JSON.

- [x] Projet Godot 4.6 : autoloads **GameData/EventBus/TickManager** en place ([[Décisions d'architecture]], [[Simulation à ticks]]), validation de schémas au boot (bloquante en debug, F5 recharge), `tr()` sur toute chaîne affichée (`locale/fr.csv`, `en.csv`) — 2026-08-26.
- [x] Les [[Contraintes permanentes]] tiennent dès la première ligne : `Simulation` autoritaire et `main.gd` client dans le même processus mais pas le même code ; aucune logique dans `_process` (le seul `delta` est converti en ticks par le TickManager) ; une horloge par combat ; le joueur est une fiche `creatures/aventurier.json` comme les autres.
- [ ] Critère de perf avant chaque étape ([[Ordre de vérification]]).

## 7. Gouvernance du design

- [x] Le coffre `docs/` est la **source de vérité** ; `archive/SENSEN_GDD.md` est figé (il contient encore le texte voxel — c'est voulu, c'est une archive).
- [ ] À chaque décision prise (propositions, playtest) : mettre à jour la note concernée, retirer la mention « proposé », passer le `statut` à `décidé`.

## Le chemin critique, en une ligne

**~~Valider P2 + P7~~ ✅ → ~~écrire le document du prototype de combat~~ ✅ → ~~produire les 5 modules Métal + le catalogue d'actions~~ ✅ → ~~les 12 jalons de l'étape 0~~ ✅ → **juger le combat** ([[Prototype de combat — spécification]] § 5 : 10 combats par arène, critères mesurables et grille qualitative) → itérer sur les chiffres (JSON + F5) → étape 1 → juger le combat. Tout le reste peut suivre la cadence des 11 étapes.

## Liens
- **Dépend de** : [[Ordre de construction]], [[Héritage voxel — audit]], [[Trous connus du combat]]
- **Alimente** : [[Ordre de vérification]], [[Carte — Ouvert]]
- **Voir aussi** : [[Contraintes permanentes]], [[Décisions fondatrices]], [[Arborescence du projet]]
