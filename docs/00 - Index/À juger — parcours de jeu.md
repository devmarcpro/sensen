---
aliases: ["À juger", "Parcours de jeu", "Session de jugement"]
tags: [index, production, ouvert]
domaine: index
statut: ouvert
etape: 10
---

**Tout ce qui attend un œil humain, dans l'ordre où on le rencontre en jouant.** Chaque incrément a laissé ses questions dans [[Vers la production]] ; cette note les regroupe en un **parcours d'une heure** (`godot/` dans l'éditeur, F5, ou `main.tscn`). Répondre = écrire un callout daté dans la note concernée ; le code suit.

> [!important] Ce que la boucle autonome ne peut pas juger (2026-08-28)
> **Remis dans l'ordre du parcours le 2026-08-29** : à force d'ajouts en tête de note, la première section avait absorbé 28 questions dont la moitié se rencontrent en donjon, au village ou au vivarium. Elle lance les tests, la scène headless et des captures ; elle ne ressent ni le rythme, ni la lisibilité, ni le plaisir. Les questions ci-dessous sont **les seules** qui bloquent : le solo doit être « bon » avant la coop ([[Ordre de construction]], étape 11).

## 1. Arriver — le camp, l'iso, le corps (10 min)

- **Lisibilité de l'iso** 32×32 : le relief se lit-il, faut-il des ombres de flanc ou une grille ? (molette : zoom, clic milieu : déplacer) — [[Prototype de combat — spécification]]
- **Fluidité** : vitesse du glissement, rendu translucide du mémorisé ; **recentrage** au passage d'une cellule (~150-300 ms si non pré-générée) — [[Boucle de tick]]
- **Le camp a-t-il l'air d'un lieu ?** Les accidents de relief sont-ils assez nombreux, la couleur de sol par biome suffit-elle ? Le camp vide au départ est-il lisible (récolter à la hache, scier, poser) ? — [[Génération par couches de bruit]], [[Claims et persistance]]
- **Végétaux en billboards** : silhouettes assez lisibles et variées, taille des arbres vs personnages, occultation d'un être derrière un arbre (les sprites définitifs sont pour plus tard, décision du designer) — [[Direction artistique]]
- **Faim et poids** : vitesse de la faim (2 h 30 de jeu actif), −10 % de stats sous 25, capacité de charge — [[Faim]], [[Armures et poids porté]]
- **La cueillette sauvage** : moitié d'une récolte cultivée par plante sauvage, qui repousse — vaut-elle le détour, ou rend-elle le champ inutile ? — [[Plantes]]
- **Les tooltips** : douze bulles d'information (récolte, lecture, faim, claim, feu, nage…) — arrivent-elles au bon moment, et le journal est-il le bon endroit pour les montrer ? — [[Tooltips contextuels]]

## 2. Le monde — carte, biomes, voyage (10 min)

- **Carte du monde (Tab → Carte du monde)** : une couleur par biome suffit-elle ? La règle « voyage seulement vers l'exploré » ? Le coût en temps du voyage ? Les **territoires teintés** des royaumes, le nom sur la capitale et la ligne de survol se lisent-ils ? — [[Carte du monde]], [[Génération des royaumes PNJ]]
- **Routes** : le chemin de sol tracé dans les cellules se lit-il comme une route ? Les traits ocre sur la carte ? — [[Unification macro-micro]]
- **Côtes et mer** : forme des côtes, part de mer visible depuis le camp, lisibilité des 12 biomes par le sol et les arbres — [[Biomes — schéma]]
- **Minimap** : teintes par matériau, place à l'écran ; on ne sauvegarde qu'en surface — [[Sauvegarde]]
- **Dérive de la corruption** : on ne la voit qu'en dormant beaucoup (une semaine = 21 nuits) — la carte affiche désormais « dérive +n » sur la cellule survolée ; suffit-il ? — [[Dérive de la corruption]]
- **Nuit et météo** : obscurité de la nuit (trop ? pas assez ?), fréquence des pluies et orages, sévérité du froid/chaud sans vêtements — [[Cycle jour-nuit et sommeil]], [[Météo]]
- **L'automate d'eau** : creuser au bord de la mer inonde la tranchée, le talus endigue, la pluie remplit les creux — arme tactique lisible, ou piège agaçant ? — [[Eau et liquides]]
- **Le retrait de l'eau** : combler la source pour assécher la tranchée d'en face — manœuvre lisible, ou exploit ? — [[Eau et liquides]]
- **Le courant** : un objet tombé dans une rivière part au fil de l'eau, un personnage léger dérive — péripétie ou frustration ? — [[Eau et liquides]]
- **La nage** : traverser une baie à la nage avec 30 s de souffle — frisson ou raccourci qui vide la carte ? — [[Eau et liquides]]
- **La foudre** : un impact par heure d'orage, pondéré par hauteur et métal, qui court dans l'eau — assez pour s'abriter, pas une loterie ? — [[Météo]]
- **Le feu** : une bombe ou la foudre qui embrase une forêt (35 % par voisine et par pas, ×2 sous le vent) — spectaculaire ou punitif ? faut-il un outil pour couper un pare-feu ? — [[Météo]]
- **La Discrétion** : à 2 % de portée de détection par niveau (plafond 60 %, +4 niveaux la nuit), passer un camp sans être vu — trop facile, trop dur ? — [[IA des créatures]]
- **Les affixes conditionnels au monde** : nocturne, du danger (corruption ≥ seuil), des sources (densité de mana) — des raisons d'aller quelque part, ou des objets qu'on oublie ? — [[Loot — affixes, gemmes et rareté]]
- **Les routes entre royaumes** : deux capitales voisines et non hostiles sont reliées, les royaumes en froid restent isolés — la carte se lit-elle mieux ainsi ? — [[Unification macro-micro]]
- **L'arrachage de la tempête** : trois tuiles très fragiles et exposées par heure (chaume, paille) — le remarque-t-on, ou est-ce trop discret pour faire peur ? — [[Météo]]

## 3. Le donjon — combat, loot, étages (10 min)

- **Difficulté et équipement** (mesuré le 2026-08-31, graine 73) : le robot **équipé** (3 objets assemblés + 3 sorts composés) descend **4 étages sans mourir** — 18 combats, 41 kills, 210 coups portés / 58 reçus, 10 soins, PV 37/44 à l'étage 5 — quand les profils nus ou fragiles meurent en boucle à l'étage 1. L'écart nu/équipé est-il la courbe voulue (l'équipement comme réponse au mur), ou le premier étage doit-il pardonner davantage ? **Complément (même graine, 7 étages)** : le même robot équipé finit par mourir à l'**étage 6/7** — essaim de deux chamans (feux follets invoqués), Infection, mana à sec et surcharge ×1,8 — la profondeur mord donc bien, l'écart se joue surtout sur les premiers étages. **Confirmé le 2026-08-31** (profil 6 objets, robot débloqué) : 5 étages descendus, 36 kills, 3 morts, fin à l'étage 6 sur un essaim bandits + chaman — le fond du donjon (boss, étage 8-9) reste hors de portée d'un profil sans soins ; seule la purge des charges de Baume sépare la survie de la chute. **Thème repaire (même graine, profil 3 objets + 3 sorts)** : 8 étages descendus, mort à l'étage 9 à 1 PV (essaim chauves-souris + loups) — la traversée tient neuf étages sans un seul enlisement du robot ; le repaire mord moins fort que la ruine aux premiers étages (pas de Rôdeur) mais l'arrivée au fond se joue à un point de vie. **Nuance (graine 404, profil 6 objets)** : le profil lourd traverse le repaire **sans une seule mort** jusqu'à l'étage 9 — après s'être délesté de 21 objets devant une nappe d'eau à l'étage 8 (la surcharge interdit la nage, larguer est le geste prévu). L'armure lourde adoucit donc bien la profondeur ; c'est le poids, pas les PV, qui devient le prix à payer au fond.
- **Rythme** : `DELAI_PAS = 0.12 s` entre deux pas — trop lent, trop rapide pour suivre les loups ? Durée d'une rencontre (cible 60-200 ticks, affichée à l'écran de fin)
- **Écran de fin de combat** (observé le 2026-08-31, sonde du sommeil) : dormir peut afficher « FIN DU COMBAT — victoire en 0 ticks » aux pistes vides — une bête de la faune engage le dormeur puis se désengage pendant la nuit, le combat naît et meurt sans un coup. S'ajoute au « reste en surimpression jusqu'au clic » du rapport 13 : faut-il taire l'écran quand le joueur n'a rien fait (0 tick, pistes vides), ou le garder comme trace de la nuit mouvementée ?
- **Télégraphe** (« ! » + tuiles rouges) vu à temps ? **Coûts sur les tuiles** (jaune) utiles ou bruit ? **Capacités** (hotbar 2-4 + clic) : la prévisualisation suffit-elle ?
- **Capacités** : composer une capacité (Tab → Capacités → Nouvelle) en enchaînant forme + noyau + modificateurs — la liste ordonnée suffit-elle ? — [[Structure compétences-modules-slots]]
- **Jet de coup** : 5 % de critiques ×1,5, 5 % de coups ratés — se sent-il, frustre-t-il ? — [[Pipeline de résolution du combat]]
- **Talents** : Le Sabre (un swap gratuit par chaîne), La Paume (soins qui tissent), La Trace (la meute pose sur ta jauge), l'Elfe (surchauffe en endurance), le Nain (tout se récolte, lentement) — chacun se sent-il ? — [[Talents de classe]], [[Talents de race]]
- **Chaîne Wu Xing** : les deux voies sont hors cible (écart 36 % ; le swap ne paie jamais) — **chiffres à trancher** (+0,35 → +0,45 sur l'engendrement ? une charge moyenne dans la rotation ?) — [[Wu Xing — cycles et vecteurs]] **Mesuré le 2026-08-28** (`test_criteres`, totaux sur ~41-45 ticks) : rotation 72,8 vs construction masse→lourde 111,5 (35 %) ; `bonus_engendrement` 0,45 → 0,9 ne ramène l'écart qu'à 26 % (la construction profite aussi de sa dernière transition terre→métal) ; `gain_par_segment` 0,1 ne change rien à l'écart. Atteindre ±15 % demande soit un multiplicateur de résolution ≈ ×5 (absurde), soit de revoir **ce que la rotation résout** (une lourde en dernier coup, comme la construction) — décision de conception, pas de réglage. **Re-mesuré le 2026-08-31** (`test_criteres`) : écart rotation vs construction toujours hors cible (38 % vs dague→Gel, 26 % vs masse→lourde) ; en revanche le **swap redevient sain** — non rentable à l'épée, rentable en dague→épée lourde (2,60/tick contre 2,59) : le critère 2 (« rentable dans certains cas seulement ») est atteint, seul le critère 1 attend la décision.
- **Bombes** : P 40 / R 2 / 3d6 après 20 ticks — ouvre-t-elle un mur sans raser la pièce ? le retard se lit-il ? — [[Explosions]]
- **Labyrinthe** : lisibilité des salles murées de roche, variété des étages, densité des couloirs, taille des salles — [[Donjons — structure et intégration]]
- **Plans industriels** (ruines à l'étage 3+, forgerons) : la découverte technique a-t-elle un visage ? — [[Palier industriel]]
- **Artefact** du boss d'un donjon majeur (≥ 4 étages) : +25 % hors fourchette, sans sertissure — se sent-il exceptionnel ? — [[Trésors et artefacts]]
- **Récolte en donjon** : lisibilité des filons, portée de la Perception, proportion de tuiles récoltables — [[Récolte]]
- **Écrans** : l'atelier en texte devient-il illisible avec 176 composants ? L'inventaire ? — [[Écrans d'interface]]
- **Donjon dans le noir** : sans torche, le donjon n'est qu'un voile ; une torche en main creuse un trou de lumière — oppressant ou illisible ? — [[Éclairage]]
- **Lumière** : une torche en main rend la vue la nuit mais te fait repérer de plus loin ; les torchères éclairent le camp — l'enjeu se sent-il ? — [[Éclairage]]
- **L'arme mixte** : choisir à chaque coup lequel de ses deux éléments pose le segment — un vrai avantage tactique, ou le mono-élément reste-t-il roi ? — [[Ouvert — Compensation de l'arme mixte]]
- **Le lieu et le mana** : lancer du Feu dans une terre volcanique coûte moins, dans un marais plus — le HUD dit maintenant « lieu : Feu 34 % · Eau 28 % » et la carte du monde le dit pour chaque cellule survolée ; se sent-il ? — [[Wu Xing hors combat]]
- **Cataclysme** : 60 ticks de canalisation visible pour un cratère 7 × 7 qui coupe les lignes de vue — un pari lisible ou une pause gênante ? — [[Sorts cataclysmiques]]
- **La lave** : mares statiques dès l'étage 5, 3d6 au contact, figées en obsidienne par un seau d'eau — obstacle lisible ou mort injuste ? — [[Eau et liquides]]
- **Armes fantomatiques** : la lame invoquée (pure, ×0,7, entretien en mana) ferme-t-elle le cycle des cinq éléments pour un mage sans râtelier, ou reste-t-elle un gadget ? — [[Armes fantomatiques]]
- **Les portails ouverts à tous** : un poursuivant, une bête ou un raid peuvent traverser la brèche du Passeur — piège intéressant ou punition invisible ? — [[Talents de classe]]
- **Incarner une bête** : jouer ton loup apprivoisé — sans mains, sans lecture, sans parole — est-ce un défi ou une impasse ? — [[Ouvert — Changer de personnage]]
- **Le Vampire** : mordu par un vampire, tu te transformes à l'aube sans l'avoir choisi — malédiction jouable (nuit forte, jour brûlant, plus de plats) ou punition ? — [[Talents de race]]
- **Les glyphes se voient** : l'IA les contourne comme le feu, sauf ceux posés sous Dissimulation (L'Ombre) — un piège qu'il faut faire traverser, meilleur jeu qu'un piège gratuit ? — [[Talents de classe]]
- **La source maudite et l'autel du rituel** (étage 4+) : une transformation irréversible au clic droit, sans avertissement — audacieux ou cruel ? — [[Talents de race]]
- **Les anneaux de transmutation** : fermer un élément de son arme pour concentrer sa chaîne — un vrai choix face au râtelier ? — [[Modificateurs d'affinité]]
- **Le premier combat (parcours robot du 2026-08-30)** : à l'étage 1 la dague fait **1 dégât** au bandit (cuir + Perforant), lui met 11 par coup et 17 en critique sur 40 PV — mur ou leçon (reculer, composer un sort, prendre l'Attaque lourde) ? Faut-il baisser l'armure du bandit d'étage 1, ou donner un sort d'attaque au départ ? — [[Prototype de combat — spécification]]
- **Respawn dans l'étage** : mourir te remet à l'entrée du même étage avec tout ton sac — doux ; voulu (prototype) ou faut-il la perte de l'expédition ? — [[Mort et pénalité]]
- **Le donjon à l'action** : plus de temps réel dans les étages — le rythme des salles vides te paraît-il « tour par tour » ou juste calme ? Faut-il aussi fusionner les horloges de combat dans celle de l'étage ? — [[Boucle de tick]]
- **La lueur ambiante** (6/15) : les étages sont-ils encore assez sombres pour que la torche compte ? Un thème plus noir (crypte à 2) ? — [[Éclairage]]
- **Le journal en donjon** : huit « Bandit attend » par tick — filtrer les êtres hors de vue, ou tout garder pour la lecture ?
- **Un ennemi perche et inatteignable** (sonde du 2026-08-31, graine 73, etage 1 ruine) : un Rôdeur en vue à 3 tuiles, ligne de vue dégagée, mais **aucun chemin** n'y mène (relief) — le duel restait figé (chacun « attend » l'autre) jusqu'à ce que le robot apprenne à abandonner la cible. Le générateur peut donc poser un monstre sur un perchoir isolé : est-ce un piment voulu (le contourner, le laisser) ou faut-il garantir qu'un être posé est atteignable depuis l'entrée ? — [[Génération de donjon]]
- **La fourchette des gemmes** (balayage du 2026-08-31) : « misérable +0,04 → mythique +0,28 » est indexée sur la qualité de taille bornée [0,5 ; 2,0] — le haut de la fourchette (mythique = 5,0) est inatteignable ; élargir `loot_rules.gemmes.qualite_taille.max`, ou réindexer sur les paliers de qualité ? — [[Modificateurs d'affinité]]
- **La pluie et la pousse** : le bonus d'arrosage ne joue qu'au semis (semer sous la pluie = −15 % de durée même s'il fait beau ensuite) — le passer en cumul pendant la pousse ? — [[Météo]]
- **Limite d'ennemis au contact** (Trous connus du combat, jamais tranché) : huit voisins peuvent frapper au même tick — faut-il une limite (les autres attendent leur tour autour), ou est-ce le prix d'être encerclé ? — [[Décision — Multi-ennemis et jauge]]
- **L'embuscade** : +2 dés sur la frappe qui ouvre un combat contre une proie surprise (lynx, crocodile, serpent) — se sent-elle, ou se perd-elle dans le bruit des dés ? — [[Prototype de combat — spécification]]

## 4. Le village — PNJ, commerce, quêtes, compagnons (10 min)

- **Hameau en blocs** : lisibilité ; sonorité des noms générés ; **prix** (un lingot de fer = 8 or après troc : trop ? trop peu ?) — [[Villages PNJ — repeuplement et décimation]], [[Prix suggéré]]
- **PNJ** : mouvement (pas glouton, ils butent sur un mur), densité de faune (12 bêtes), la nuit vraiment dangereuse ? — [[IA des créatures]]
- **Réputation et quêtes** : rythme (3-8 cibles, 15 or × niveau), lisibilité des paliers dans le dialogue, frapper un civil rend tout le village hostile après deux coups — [[Réputation et relations]], [[Quêtes et guildes]]
- **Compagnons** : suivre sans postures (ils attaquent tout ennemi à portée), coût de résurrection (20 or × niveau × 1,5), fréquence des morts de vieillesse — [[Apprivoisement et recrutement]]
- **Boutiques typées et halls** : une capitale de grand royaume (9-12 bâtiments) tient-elle dans la cellule ? « Quelle ville a quel hall » se lit-il (pas sur la carte) ? — [[Halls de guilde]]
- **Douanes et lois** : les tarifs sont-ils lisibles dans l'écran de commerce ? **La loi absurde fait-elle rire ?** — [[Lois et infractions]]
- **Désigner une cible / Repli** : clic droit sur l'ennemi pour l'assigner à tous les compagnons, Y dans le dialogue pour le repli — deux gestes suffisent-ils en mêlée ? — [[Compagnons]]
- **Les postures des compagnons** : défensive (ne poursuit pas loin du maître), agressive, évite — protecteur ou passif ? l'échange d'équipement (K dans le dialogue) où il s'équipe tout seul suffit-il ? — [[Compagnons]]
- **Le suiveur territorial** : un résident suit chez toi sans occuper de place d'escorte et rentre dès que tu sors — utile, ou un ordre de plus dans un menu déjà long ? — [[Compagnons]]

## 5. Le territoire — claims, production, raids, royaume (15 min)

- **Claim** (clic sur une cellule voisine depuis la carte du monde) : le coût `50 or × cellules` est-il lisible ? — [[Expansion territoriale]]
- **Logement et faim** : bâtir une chambre (murs, porte, lit, un meuble, ≥ 6 tuiles) et garnir un garde-manger — les −15 / −10 d'humeur se voient-ils sur la production ? — [[Habitat des PNJ]], [[Faim des PNJ]]
- **Semaine** (= 21 nuits) : la production d'un résident se voit-elle ? L'écran Territoire (Tab → Territoire) en liste suffit-il ? — [[Population et exploitation]]
- **Parcelles** : un jour de pousse à 24 000 ticks est-il long ? La récolte au clic ? — [[Agriculture et élevage]]
- **Boutique passive** : caisse séparée du trésor (à relever sur l'étal) — bon ou agaçant ? **Troc d'office** des marchands à sec sans écran d'acceptation ? — [[Boutique passive]], [[Économie — sources et puits]]
- **Raids** : probabilité de base 0,05 et échelle `valeur/20` ; un raid qui tombe pendant la nuit sautée se lit-il ? La tourelle (4 planches + 2 lingots) : 1d6 toutes les 20 ticks à 6 tuiles — assez ? trop ? La punition d'une dette de 4 semaines quand un raid tombe — [[Défense et raids]], [[Raids et menaces]]
- **Conquête** (clic sur la place d'un village) : lisible en un jet et un message ? La **vacance de trône** se remarque-t-elle ? — [[Conquête de village]], [[Familles et succession]]

## 6. Alchimie et élevage (5 min)

- **Entraîneur et commandes** : 20 or × niveau pour +10 de potentiel — un vrai puits ? La commande du collectionneur (une variété à un ou deux pas) donne-t-elle envie de croiser ? — [[Potentiel]], [[Vivarium — capture et élevage]]
- **Assiette harmonieuse** : cocher ses ingrédients dans l'atelier et lire l'harmonie prévue — le puzzle des cinq éléments est-il lisible ? — [[Décision — Affinités de cuisine]]
- **Potions** : +3 / +6 × puissance de la partie (stat de la créature / 10) pendant 3 000 ticks — sensible ? La différence loup / chef de bande se sent-elle ? — [[Cuisine et alchimie]]
- **Élevage** : le facteur entre qui sélectionne et qui laisse faire est **mesuré à ×5,7** (attendu ×15, [[Règle d'anneau]]) — trancher 34/34/16/16 → 40/40/20 ? ; le nom des spécimens (indices bruts) ; une espèce par famille suffit-elle à sentir les six verbes ? Le miel (1 par 4 abeilles) est-il trop lent ? — [[Catalogue des groupes d'élevage]]
- **Les paliers d'élevage** : 25 variétés pour +10 de potentiel, 75 pour la capture — assez tôt pour accrocher, ou trop loin ? — [[Vivarium — registre et paliers]]
- **Le registre par mode** : grille, records, séquences, galerie, familles — chaque espèce a le sien, et une luciole a 96 variétés possibles — lisible, ou trop de combinatoire ? — [[Vivarium — registre et paliers]]

## 7. Modules, composition et interface (ajouts du 2026-08-30, 10 min)

- **Composer sans plafond** : Bombe × 3 sur un carré (`9d6`, puissance 120, 42 de mana la tuile × 9 tuiles) — le prix se sent-il, ou l'échelle linéaire rend-elle le triplé toujours rentable ? Faut-il un avertissement au-delà d'un seuil de ticks ? — [[Six types de modules et assemblage]], [[Structure compétences-modules-slots]]
- **Le prix par tuile annoncé** : « 9 tuiles à la visée nominale → 72–432 » au composeur, puis les tuiles réelles à la visée — lisible, ou faut-il la fourchette en gros sur la hotbar ? — [[Six types de modules et assemblage]]
- **La forme répétée** : Carré + Carré = un carré de 25 tuiles pour 4 ticks de plus — trop bon marché par rapport au noyau répété (prix × 2) ? — [[Six types de modules et assemblage]]
- **L'écran principal** : titre → personnage → monde (graine re-tirable) → case de départ — manque-t-il un aperçu du monde avant Commencer, des emplacements de sauvegarde nommés ? — [[Écrans d'interface]]
- **La police MingLiU-ExtB** : trait bitmap sans lissage, 10 px sur la hotbar — lisible partout, ou trop fin sur les barres ? — [[Écrans d'interface]]
- **HUD et 64 × 64** : compas-horloge et pentagramme en haut à droite, barres et hotbar en bas à gauche, écran de chargement 0,6 s entre cellules — la coupure rend-elle le monde plus lisible ou casse-t-elle l'exploration ? Un étage de 64 × 64 se lit-il encore comme un labyrinthe ? — [[Grille continue]], [[Claims et persistance]]

## Comment répondre

Un callout daté dans la note liée (`> [!success] Tranché le <date>`) — la boucle autonome le lit avant de coder. Une réponse « ça va » suffit pour fermer un point ; une valeur chiffrée suffit pour un réglage.

> [!question] À juger — l'échelle des stats après le passage aux dés (2026-08-31, point 48)
> Les stats de base sont désormais tirées (`1d6+2`) et il ne reste que **8 points** à répartir (12 pour une classe cachée, l'ancien +15 divisé pour tenir l'échelle). Trois questions de game feel restent au designer : **le jet est-il assez large** (3-8 donne peu d'écart entre deux personnages) ; **8 points suffisent-ils** pour sentir un choix, ou faut-il monter ; et **faut-il pouvoir relancer** le tirage à la création — je ne l'ai pas ajouté, le refus des relances étant une décision de design, mais un tirage subi à la création n'est pas la même chose qu'une relance en combat.

## Liens
- **Dépend de** : [[Vers la production]], [[Ordre de construction]]
- **Alimente** : [[Ordre de construction]]
- **Voir aussi** : [[Prototype de combat — spécification]], [[Écrans d'interface]]
