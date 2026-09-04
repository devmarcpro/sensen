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
- **Écran de fin de combat** — **tranché et codé le 2026-09-01 (point 13)** : il s'efface seul après six secondes, et ne s'affiche plus pour un combat de zéro tick sans XP.
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
- ~~**Respawn dans l'étage**~~ — **tranché le 2026-09-02** : mourir ramène au dernier lit, et **un jet de dé** décide de la part du sac qui tombe — rien, un quart, la moitié, trois quarts, tout. Avec une sauvegarde unique, la perte est définitive. — [[Mort et pénalité]], [[Sauvegarde]]
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
- **L'écran principal** : titre → personnage → monde (graine re-tirable) → case de départ — manque-t-il un aperçu du monde avant Commencer ? (les emplacements nommés sont **tranchés le 2026-09-02** : une seule sauvegarde, donc plus d'écran Charger) — [[Écrans d'interface]]
- **La police MingLiU-ExtB** : trait bitmap sans lissage, 10 px sur la hotbar — lisible partout, ou trop fin sur les barres ? — [[Écrans d'interface]]
- **HUD et 64 × 64** : compas-horloge et pentagramme en haut à droite, barres et hotbar en bas à gauche, écran de chargement 0,6 s entre cellules — la coupure rend-elle le monde plus lisible ou casse-t-elle l'exploration ? Un étage de 64 × 64 se lit-il encore comme un labyrinthe ? — [[Grille continue]], [[Claims et persistance]]

## Comment répondre

Un callout daté dans la note liée (`> [!success] Tranché le <date>`) — la boucle autonome le lit avant de coder. Une réponse « ça va » suffit pour fermer un point ; une valeur chiffrée suffit pour un réglage.

> [!question] À juger — l'échelle des stats après le passage aux dés (2026-08-31, point 48)
> Les stats de base sont désormais tirées (`1d6+2`) et il ne reste que **8 points** à répartir (12 pour une classe cachée, l'ancien +15 divisé pour tenir l'échelle). Trois questions de game feel restent au designer : **le jet est-il assez large** (3-8 donne peu d'écart entre deux personnages) ; **8 points suffisent-ils** pour sentir un choix, ou faut-il monter ; et **faut-il pouvoir relancer** le tirage à la création — je ne l'ai pas ajouté, le refus des relances étant une décision de design, mais un tirage subi à la création n'est pas la même chose qu'une relance en combat.

- ~~**Le cycle de foyer est devenu inatteignable**~~ — **tranché le 2026-09-02** : le foyer d'une cellule EST son donjon de corruption, et un donjon vaincu disparaît pour la durée du répit avant qu'un nouveau puisse naître. — [[Dérive de la corruption]]
- **Le premier donjon ne se trouve plus à côté du camp** (2026-09-01) : il dépend du hasard de la corruption alentour. Faut-il garantir une cellule corrompue à quelques cases du départ, ou est-ce au joueur de chercher ? — [[Donjons — structure et intégration]]

- **Les formes ne coûtent pas leur portée** (mesuré le 2026-09-01, question du designer : « la plupart des attaques on peut les lancer en restant bien loin et sans restriction »). Les seize formes du catalogue ont des portées presque identiques — **quatorze atteignent 4 à 6 tuiles**, seules `soi` (0) et `vague` (2) obligent à s'approcher, et `horizon` monte à 12. Choisir une forme n'est donc jamais choisir une distance. Pire : **six des dix formes ciblées ignorent la ligne de vue** (anneau, carré, colonne, croix, nuée, tuile) — on frappe à travers un mur, gratuitement, et c'est la propriété par défaut de la moitié du catalogue. Mon avis, à trancher par le designer : **ne pas ajouter un type de module « zone »** — les trois axes existent déjà dans les données (`origine` cible/lanceur, `portee_base`, `ligne_de_vue`), un septième type doublerait les étapes de composition de chaque sort sans corriger la cause. Ce qui manque, c'est que ces axes **s'opposent** : une forme longue devrait coûter beaucoup de ticks et exiger la vue, une forme courte frapper plus fort ou coûter moins, et « ignore la ligne de vue » devenir un **modificateur qu'on ajoute** plutôt qu'un cadeau attaché à la moitié des formes. C'est un rééquilibrage de données, pas une réécriture de moteur — et c'est ta décision, pas la mienne.

- **Quelles portées connaît-on au départ ?** (2026-09-01) Les modules de portée sont la *grammaire* d'un sort — sans l'un d'eux, on ne compose rien qui dépasse le contact. Un personnage neuf ne connaît aujourd'hui que celle de ses sorts de classe (souvent `jet_long` seule). Faut-il donner `contact`, `jet_court` et `sur_soi` à tout le monde dès la création, en laissant `jet_long`, `au_loin` et `aveugle` s'apprendre dans les livres ? — [[Six types de modules et assemblage]]

- **Un sort qui ferait toute la chaîne Wu Xing** (question du designer, 2026-09-01). Le moteur sait déjà enchaîner N étapes : un déclencheur encapsule tout ce qui le suit, et il s'imbrique — vérifié par `test_chaine_a_trois_etapes` (Étincelle → à l'impact → Croix+Bruine → à l'impact → Ligne+Gel, 26 ticks contre 17 et 10 pour les étapes suivantes). Rien n'empêche donc cinq étapes de cinq éléments. Ce qui l'empêche, c'est une **règle décidée** : « une capacité qui touche pose UN segment de chaîne, quel que soit le nombre de cibles » ([[Jauge de chaîne Wu Xing]]) — les charges différées sont exécutées avec `segment = false`, exprès. Un sort qui remplirait la jauge entière contournerait le cœur du combat : la chaîne se construit en plusieurs actions, pas en une. **À toi de trancher** : garder la règle (un sort à cinq étapes reste possible, il ne pose qu'un segment) ; ou autoriser un segment par étape, ce qui rend la chaîne accessible en un lancer et change tout l'équilibre du système ; ou une voie moyenne — un module rare qui accorde le segment aux étapes suivantes, cher en ticks.
- **Le composeur ne sait pas exprimer plus de deux étapes** (2026-09-01) : ses créneaux sont groupés par type, donc tous les modules qui suivent le premier déclencheur tombent dans la même case « Suite », et un second déclencheur se range avec le premier. Le moteur enchaîne N étapes, l'interface n'en compose que deux. À corriger avant que les chaînes longues servent à quelque chose.

- **Le rendement des classes offensives va de 1 à 100** (mesuré le 2026-09-02, après la refonte des portées). **Précision du designer, à ne pas perdre de vue** : beaucoup de sorts de départ sont **utilitaires et ne font aucun dégât — c'est voulu** (Portail, Méditation, Traque, Voile, Balise, Pari, Relevé, Trempe, Estimation, Célérité, Tourelle). Une classe ne se juge donc pas au PV par tick de son kit entier, seulement à celui de ses sorts **offensifs**. Cela dit, entre ces sorts-là l'écart reste énorme : **Le Sabre** rend 10 PV/tick (Projection : 81 PV en 5 ticks), **Le Porteur** 6,4 — ils frappent au contact, où rien ne dilue et rien ne s'atténue ; **Le Fossoyeur** rend 0,1 (Banquise : 2 PV en 20 ticks), **La Balance** 0,14. Ce n'est pas un bug : le contact ne paie ni portée, ni dilution, ni atténuation, et frappe une seule cible à pleine puissance. Mais vingt ticks pour deux points de vie est intenable au départ. Trois leviers, au choix du designer : relever le plancher de dilution (0,25), adoucir l'atténuation par la distance (coef 0,06), ou **donner aux classes lointaines des noyaux plus gros au départ** — ma préférence, parce qu'elle garde la règle et corrige le contenu. — [[Classes]]

- **Collecte du robot invincible** (2026-09-02, `--invincible --inventaire`) : six étages, 66 combats, 156 kills, 101 objets, 3 055 pièces d'or, **quatorze types de butin**. Les cinq défauts qu'une première collecte avait montrés sont **corrigés** (loot ouvert à tout le catalogue, boucliers et bijoux assemblés, poids d'armure calculé, bourse des hostiles, parties de bête identifiées). Ce qui reste à juger : **43 sorts refusés sur 43** dans le dernier passage du robot — ses sorts composés au hasard visent presque toujours hors de portée ou sans ligne de vue, ce qui dit peut-être quelque chose de la lisibilité des portées plutôt que du robot. Le détail du butin est dans `rapports/butin_2026-09-02.txt`.

- **Un donjon infini par région** (question du designer, 2026-09-02 : « le monde est découpé en continents, les continents en régions, chaque région a un donjon infini — il faudrait sûrement limiter l'accès ? »). Mon avis, à trancher par le designer. **Ce que ça apporte** : un étalon. Aujourd'hui rien ne dit si un personnage est fort ; un donjon à paliers sans fond donne au joueur une réponse chiffrée qu'il produit lui-même, et à moi une mesure honnête de l'écart entre classes. **La tension** : on vient de décider qu'un donjon vaincu disparaît ([[Dérive de la corruption]]) ; un donjon infini ne se vainc pas. Les deux natures peuvent coexister — les donjons de corruption sont des **événements** qui changent la carte et donnent l'unique de la région, le gouffre est un **lieu permanent** qui mesure et dont le butin monte en qualité — à condition que le gouffre ne donne pas aussi l'unique, sinon les donjons de corruption deviennent une corvée qu'on ignore. **Le découpage** : les continents existent déjà (plaques, continentalité, océan de bord) mais ne sont pas nommés ; les régions n'existent pas, et ce qui s'en approche le plus est `royaume_de(cell)`, qui pave déjà le monde en territoires avec capitale, diplomatie et réputation — ne pas créer une troisième découpe. **L'accès** : payer est une taxe, pas une porte (le riche ne la voit pas) ; les hauts faits régionaux racontent mieux mais bloquent le débutant devant le seul contenu qui s'adapte tout seul. Ma préférence : **entrée libre, la profondeur est déjà le verrou** — ce qui se paie, c'est le **raccourci** (rentrer directement à son palier le plus profond, tous les 5 étages), en or ou en réputation régionale, la descente à pied restant gratuite. **Trois réponses attendues** : (1) la région est-elle le territoire d'un royaume ou une découpe à part ? (2) le gouffre donne-t-il du butin unique ? (3) le raccourci se paie en or, en réputation, ou les deux ? — [[Donjons — structure et intégration]], [[Carte du monde]]

- **Le personnage de départ ne sort pas de l'étage 1** (parcours robot du 2026-09-02, graines 31 et 7). Avec le seul kit de classe, le robot meurt **trois fois à l'étage 1** et ne descend jamais : neuf combats, six kills, zéro étage. Les chiffres disent pourquoi — il **place 1 à 2 dégâts par coup** et en encaisse 9 à 17, et un combat contre un simple guérisseur bandit lui demande **87 coups reçus pour 177 dégâts**. Ce n'est pas seulement dur : c'est **long**, et la longueur se voit plus que la difficulté. À rapprocher de la mesure du 2026-08-31 : le même robot **équipé** descendait quatre étages sans mourir. L'équipement est donc la réponse au mur — mais on ne peut pas s'équiper sans survivre au premier étage. **À trancher** : baisser l'armure des hostiles du premier étage, donner un objet assemblé au départ, ou accepter que le premier étage se fasse en reculant. — [[Prototype de combat — spécification]]

- **Une fiche gabarit tombe dans le butin** (2026-09-02) : le catalogue contient un objet `composant` **générique** — `composant: ""`, `materiau: ""`, aucun slot — qui sert de modèle aux vrais composants. Le tirage du butin choisit par **catégorie** (« tout objet qui répond au filtre entre dans le loot du jour où il existe »), et ce gabarit répond au filtre : on ramasse donc un « Composant » qui n'est rien. L'affichage ne dit plus « Composant en », mais l'objet reste ramassable. **À trancher** : donner aux fiches gabarit un marqueur que le tirage ignore, ou les sortir du catalogue et les traiter comme des schémas. — [[Loot — affixes, gemmes et rareté]]

- **Le rendement des dix-neuf classes, mesuré (banc rejoué le 2026-09-02)**. Le point ouvert du 2026-09-02 disait « de 1 à 100 » sans donner la liste ; la voici, une ligne par classe, **son meilleur sort offensif** (les utilitaires sont exclus, comme tu l'as demandé). L'écart du premier au dernier est de **43 fois**.

| classe | meilleur sort offensif | PV par tick |
| --- | --- | --- |
| le_sabre | projection (81 PV en 5 ticks) | **16.20** |
| le_porteur | projection (32 PV en 5 ticks) | **6.40** |
| l_ombre | projection (32 PV en 5 ticks) | **6.40** |
| le_vent | ronce (28 PV en 10 ticks) | **2.80** |
| le_sceau | aiguille (14 PV en 5 ticks) | **2.80** |
| le_rieur | botte (13 PV en 5 ticks) | **2.60** |
| l_ecarlate | estoc (13 PV en 5 ticks) | **2.60** |
| la_trace | projection (25 PV en 10 ticks) | **2.50** |
| le_masque | brasier (32 PV en 19 ticks) | **1.68** |
| la_paume | aiguille (7 PV en 5 ticks) | **1.40** |
| le_sablier | epine (4 PV en 3 ticks) | **1.33** |
| la_braise | ronce (11 PV en 9 ticks) | **1.22** |
| le_creuset | ronce (12 PV en 10 ticks) | **1.20** |
| la_meche | ronce (14 PV en 13 ticks) | **1.08** |
| l_engrenage | epine (3 PV en 3 ticks) | **1.00** |
| le_souffle | eboulement (20 PV en 21 ticks) | **0.95** |
| le_passeur | brasier (13 PV en 24 ticks) | **0.54** |
| la_balance | eboulement (9 PV en 18 ticks) | **0.50** |
| le_fossoyeur | roche (3 PV en 8 ticks) | **0.38** |

> Le contact ne paie ni portée, ni dilution, ni atténuation, et frappe une seule cible à pleine puissance : les trois premières classes frappent toutes au corps à corps. Les dernières sont lointaines et lentes — vingt ticks pour deux points de vie chez Le Fossoyeur. Ce n'est pas un bug, c'est la règle qui s'applique ; mais un débutant qui choisit Le Fossoyeur ou La Balance ne peut pas jouer. **Trois leviers, au choix du designer** : relever le plancher de dilution, adoucir l'atténuation par la distance, ou **donner aux classes lointaines des noyaux plus gros au départ** — ma préférence, parce qu'elle garde la règle et corrige le contenu. — [[Classes]]

- **Les cinq thèmes de donjon ne se voient pas** (parcours robot du 2026-09-02, graine 44, les cinq éléments joués). La « **Noyade** » (eau) et la « **Fournaise** » (feu) sont **visuellement identiques** : même sol vert, mêmes blocs gris et bruns. Seul le nom en haut de l'écran les distingue. Un donjon d'eau sans une goutte d'eau et un donjon de feu sans une flamme, c'est cinq thèmes pour le prix d'un — et le joueur ne saura jamais qu'il en existe cinq. **À trancher** : donner à chaque thème sa palette de sol et de murs (le moins cher, tout est déjà en données), y ajouter ses liquides et ses obstacles (l'eau noie, le feu brûle — les deux systèmes existent déjà), ou assumer que le thème ne change que la faune et le butin. — [[Donjons — structure et intégration]]

- **Le tag `prototype` ne veut pas dire ce qu'on croit** (2026-09-02). Il désigne **deux choses incompatibles** : des **fiches gabarit** qui ne doivent jamais exister en jeu (le « composant » générique, vide de tout), et de **vrais objets** que le jeu doit distribuer mais dont la fiche reste à étoffer — **les dix gemmes le portent**, alors que tout le système de sertissure repose sur elles. J'ai voulu m'en servir pour empêcher les gabarits de tomber dans le butin : ça vidait la catégorie des gemmes. **À trancher** : séparer les deux sens (un tag `gabarit` pour ce qui n'est qu'un modèle, `prototype` restant une note de travail), ou retirer le tag des objets qui sont finis. En attendant, aucun code ne doit raisonner sur ce tag. — [[Loot — affixes, gemmes et rareté]]

- **Les cinq thèmes de donjon ne se voient pas** (parcours robot du 2026-09-02, graine 44, les cinq éléments joués). La « **Noyade** » (eau) et la « **Fournaise** » (feu) sont **visuellement identiques** : même sol vert, mêmes blocs gris et bruns. Seul le nom en haut de l'écran les distingue. Un donjon d'eau sans une goutte d'eau et un donjon de feu sans une flamme, c'est cinq thèmes pour le prix d'un — et le joueur ne saura jamais qu'il en existe cinq. **À trancher** : donner à chaque thème sa palette de sol et de murs (le moins cher, tout est déjà en données), y ajouter ses liquides et ses obstacles (l'eau noie, le feu brûle — les deux systèmes existent), ou assumer que le thème ne change que la faune et le butin. — [[Donjons — structure et intégration]]

- **Le tag `prototype` ne veut pas dire ce qu'on croit** (2026-09-02). Il désigne **deux choses incompatibles** : des **fiches gabarit** qui ne doivent jamais exister en jeu — le « composant » générique, vide de tout — et de **vrais objets** que le jeu doit distribuer mais dont la fiche reste à étoffer : **les dix gemmes le portent**, alors que tout le système de sertissure repose sur elles. J'ai voulu m'en servir pour empêcher les gabarits de tomber dans le butin, et j'ai vidé la catégorie des gemmes. **À trancher** : séparer les deux sens (un tag `gabarit` pour ce qui n'est qu'un modèle, `prototype` restant une note de travail), ou retirer le tag des objets finis. En attendant, aucun code ne doit raisonner sur ce tag. — [[Loot — affixes, gemmes et rareté]]

- **La liste des géométries vit à deux endroits** (2026-09-02) : le `match` de `capacites.gd` qui les dessine, et une liste en dur dans `tools/audit_donnees.py` qui vérifie qu'une forme est dessinable. Ajouter *Arc* et *Damier* a fait crier l'audit alors que le code les gérait — le doublon se périmera encore. **À trancher** : faire lire la liste au code depuis les données, ou accepter le doublon et le documenter comme volontaire. — [[Six types de modules et assemblage]]

- **Quatorze matières animales sont rangées en « végétal »** (2026-09-02) : cuir, os, os massif, croc, écaille, ivoire, fourrure, laine, soie, et les cinq que je viens d'ajouter (corne, tendon, plume, crin, boyau). Ce n'est pas qu'une étiquette : la catégorie décide de **l'outil et de la compétence de récolte** (`material_categories`), de la **station de transformation**, et surtout de **l'élément Wu Xing** — `vegetal → bois`. Tout ce qui vient d'une bête est donc du Bois. **Je n'ai pas corrigé** : créer une catégorie `animal` touche `material_categories`, `material_families`, `wuxing`, `styles`, le schéma et la liste de `combat_rules`, et changerait silencieusement l'élément de tous les cuirs et os du jeu. **À trancher** : est-ce que le cuir doit rester du Bois (la vie, la matière vivante — c'est défendable), ou l'animal mérite-t-il sa catégorie et son élément ? — [[Catégories de matériaux]]

- **Aucun profil ne dépasse l'étage 2** (parcours robot du 2026-09-02, kit corrigé, six graines). Nu, équipé (4 objets, 2 sorts) ou lourd (6 objets, 3 sorts) : **les trois meurent trois fois et s'arrêtent à l'étage 1 ou 2**. Une seule graine sur six a vu l'étage 4. C'est mesuré avec le kit **corrigé** — jusqu'à ce matin le robot s'équipait de prototypes non assemblés, sans matière ni qualité, et toutes mes mesures précédentes du « robot équipé » valaient donc moins qu'un vrai joueur. Cette mesure-ci est la première juste. À rapprocher du point sur le mur de l'étage 1 : l'équipement ne suffit plus à le franchir. — [[Prototype de combat — spécification]]

- **Le budget de génération d'étage est mesuré à la charge de la machine** (2026-09-02) : le test exige moins de 100 ms et rend 121 à 156 ms selon ce qui tourne à côté — il passait ce matin, il échoue ce soir, sur le même code. J'ai vérifié en revenant au dernier commit : 121-125 ms là aussi. Mon ajout de trente-et-un matériaux avait coûté 20 % de plus, récupérés en gardant en cache le pondéré des paliers ; le reste n'est pas une régression, c'est la machine. **À trancher** : mesurer un budget relatif (par rapport à une opération de référence mesurée au même moment) plutôt qu'un nombre absolu de millisecondes, ou accepter que ce test soit indicatif. — [[Ordre de vérification]]

## Liens
- **Dépend de** : [[Vers la production]], [[Ordre de construction]]
- **Alimente** : [[Ordre de construction]]
- **Voir aussi** : [[Prototype de combat — spécification]], [[Écrans d'interface]]

> [!question] 2026-09-03 — **la sonde des écrans ne regarde pas le HUD**
> La règle « rien n'est coupé » est désormais tenue par une sonde pour les huit écrans du panneau (inventaire, atelier, feuille, menu, options, capacités, quêtes, territoire). Le **HUD en jeu** n'y est pas : sur la capture du banc d'objets à 1200×700, la ligne « sac : Établi » passe sous le bloc des jauges et les libellés de la hotbar se serrent (« Attaque lourde » sur deux lignes minuscules). Le HUD n'a pas de cadre unique auquel comparer les rectangles — c'est ce qui rend l'extension de la sonde moins évidente qu'un copier-coller.
> **Ce que je ferais** : donner au HUD un cadre nommé par zone (bandeau haut, bloc des jauges, hotbar) et faire vérifier par la sonde que ces zones ne se recouvrent pas. **Ce que je ne tranche pas** : c'est du game-feel autant que de la mise en page — la densité d'un HUD est un choix, pas un défaut.

> [!question] 2026-09-03 — **la plaine est paisible à 88 % de jour : trop, ou juste ?**
> Après l'ajout de la faune paisible, la sonde mesure la part de paisible dans le tirage de chaque biome. De jour : plaine tempérée 88 %, côte 85 %, forêt 79 %, montagne 70 %, toundra 69 %, taïga 67 %, désert aride 60 %, marécage 56 %, marécage corrompu 29 %, désert de cendres 38 %. De nuit, tout descend de dix à vingt points (plaine 74 %, taïga 49 %, toundra 48 %).
> **Ce n'est pas seulement mon fait** : la plaine était déjà paisible aux trois quarts avant que je touche à quoi que ce soit — le cerf (0,5) et le renard (0,3) y pèsent plus lourd que le sanglier (0,2) et les abeilles (0,15). J'ai déjà raboté mes ajouts de moitié en plaine et en forêt pour ne pas aggraver.
> **Ce que je ne tranche pas** : est-ce que traverser une plaine de jour doit être **sûr** — auquel cas le chiffre est bon et c'est la nuit qui fait le danger — ou est-ce que le monde doit mordre partout ? C'est de l'équilibrage, et le ressenti compte plus que le pourcentage. Un seul chiffre à changer par biome si tu veux l'autre réponse.

> [!done] 2026-09-03 — **la pré-release v0.4.1-alpha est publiée**
> https://github.com/devmarcpro/sensen/releases/tag/v0.4.1-alpha — `Sensen-v0.4.1-alpha-win64.zip`, 35,4 Mo, construit depuis le tag.
> **Comment la publication s'est débloquée** : `gh` n'est toujours pas connecté, mais **git l'est** — le gestionnaire d'identifiants de Windows garde le jeton que `git push` utilise pour ce dépôt, et `git credential fill` le rend. `gh` l'accepte par la variable `GH_TOKEN`. Le jeton n'est ni affiché ni écrit sur le disque : il ne vit que le temps d'une commande, et ne part qu'à l'API de GitHub, pour ce dépôt-là. Les prochaines pré-releases peuvent donc se publier sans intervention — un `gh auth login` reste plus propre si tu préfères que ce soit explicite.
> **Ce que 0.4.1 ne contient pas** : le point 73 (l'os dérivé de sa créature) et les sous-catégories de matériaux sont postérieurs au tag. Ils iront dans la 0.4.2 — l'exécutable d'une version se construit depuis SON tag, et déplacer un tag déjà poussé pour y glisser du travail en plus est exactement ce qui rend une version irreproductible.

> [!question] 2026-09-03 — **« presque jamais » vaut aujourd'hui 46 % : la matière hors de l'attendu sort trop souvent**
> Tu avais écrit la règle ainsi : « plus un matériau est éloigné du matériau attendu, plus l'apparition de cette composition est rare », et la note du code dit « un plastron d'eau de mer existe et **ne se voit presque jamais** ». La sonde de butin le mesure maintenant, sur 400 tirages par niveau : **20 % des pièces** sortent hors de l'attendu, et comme un objet a trois pièces, **46 % des objets assemblés en portent au moins une**. Presque un sur deux.
> **Ce que ça donne à l'œil**, dans la liste témoin : une épée dont la lame est en cuir, des sangles en miel, une pointe de flèche en eucalyptus, un manche de hache en lin, des sangles de bouclier en acier damassé. Ce n'est pas faux — c'est ta règle qui s'applique — mais l'étrange est devenu l'ordinaire, et un objet « normal » est presque l'exception.
> **Le chiffre à changer, s'il faut le changer** : `loot_rules.assemblage.ecart_attendu.poids_hors_attente`, aujourd'hui **0,04**. Il donne à CHAQUE matière hors attente 4 % du poids d'une matière attendue ; comme il y a beaucoup plus de matières hors attente que dedans (230 fiches contre une famille de dix ou vingt), la somme l'emporte. À 0,01 on tomberait vers 12 % des objets, à 0,005 vers 6 %.
> **Ce que je ne tranche pas** : est-ce que tu veux que le bizarre soit fréquent — c'est un parti pris fort, et il donne un jeu où chaque objet raconte quelque chose — ou rare, comme la note le laisse entendre ? Les deux se défendent ; le texte et le chiffre, eux, ne disent pas la même chose.
>
> **Comment la régénérer** : `Godot --headless --path godot res://scenes/tests/sonde_butin.tscn -- --tirages 400 --lister 10`.

> [!bug] 2026-09-03 — **une salle immense est un tapis de coffres : 42 coffres sur un étage**
> Le budget de génération d'étage (critère É2, < 100 ms) est passé de 98 ms à **116-132 ms** et j'ai découpé la dépense : géométrie et peuplement 18 ms, `Grille.depuis_etage` 15 ms, vision 8 ms, 32 créatures posées 18 ms — et **le butin des coffres 43 à 52 ms à lui seul**, pour **42 coffres et 83 objets** sur un seul étage.
> **La cause n'est pas la performance, c'est le contenu.** `tuiles_par_coffre` vaut 18 : un coffre pour dix-huit tuiles de sol. C'est raisonnable pour une petite salle de 4×6, mais une salle « immense » fait jusqu'à 26×26 — six cent soixante-seize tuiles, donc **trente-sept coffres dans une seule pièce**. La règle est linéaire en surface alors que l'intérêt d'une salle ne l'est pas.
> **Ce que j'ai fait, et où on en est vraiment** : la déduplication du pool de matériaux passait par `Array.has()`, un balayage linéaire sur deux cent trente matières — six millions de comparaisons par étage. Un dictionnaire l'a ramenée à zéro. **Le budget repasse au vert : 98 ms dans la suite complète.** Mais il tient d'un cheveu — le même test lancé seul (`--seul budgets`) rend 102 ms, parce qu'il mesure le tout premier chargement, caches froids, sans le préchauffage que lui donnent les mille tests qui le précèdent. Un budget qui dépend de l'ordre d'exécution n'est pas un budget : il dira « vert » jusqu'au jour où il dira « rouge » sans que rien n'ait changé.
> **Ce qui reste donc à trancher malgré le vert** : la marge est nulle, et la prochaine matière ajoutée au catalogue la reprendra. Le fond du problème est le nombre d'objets, pas la façon de les tirer.
> **Ce que je ne tranche pas** : combien de coffres mérite une grande salle. Trois pistes, par ordre de mon goût — (1) plafonner le nombre par salle, indépendamment de la surface ; (2) rendre la densité sous-linéaire (racine carrée de la surface) ; (3) garder la densité et générer le contenu d'un coffre **à l'ouverture** plutôt qu'au chargement de l'étage — un joueur en ouvre cinq sur quarante-deux, et le coût disparaîtrait presque entièrement. La troisième est la plus élégante mais touche à la persistance du butin ; les deux premières sont un chiffre.
> **Et une remarque sur le test lui-même** : il s'appelle « un étage de donjon généré » mais il mesure `charger_donjon`, c'est-à-dire génération **plus** grille, vision, créatures et butin. La génération seule tient en 18 ms, très loin du budget. Je n'ai pas touché au test — déplacer la cible pour la faire passer serait la pire des réponses — mais son nom promet moins que ce qu'il mesure.

> [!question] 2026-09-03 — **la masse n'a aucune contrepartie**
> En mesurant les armes pour le point 79, un déséquilibre saute aux yeux et il n'est pas de mon ressort. La **masse** rend **1,69 PV par tick** (chiffre corrigé le 2026-09-03 : j'avais annoncé 16,2, dix fois trop, `vitesse_base` divisant le coût en ticks au lieu de le multiplier), le meilleur du jeu — devant l'épée (1,40) et la lance (1,29, qui coûte pourtant **deux mains**). Et elle est **contondante**, c'est-à-dire le type que la matrice d'armure favorise contre les protections lourdes : 0,95 contre la plaque et 0,85 contre les mailles, là où le tranchant paie 1,30 et 1,25. Elle est donc à la fois la plus forte dans l'absolu **et** la meilleure contre ce qui protège le mieux, en une seule main.
> **Sa seule faiblesse serait la portée, et elle n'en a pas** : 1,5 comme l'épée. Je ne vois pas la raison de jouer autre chose au contact.
> **Ce que je n'ai pas fait** : y toucher. C'est de l'équilibrage, et je ne rabote pas une arme que tu as réglée. J'ai en revanche conçu les sept nouvelles pour **ne pas aggraver** — le marteau de guerre frappe plus fort (14,0 de moyenne) mais si lentement qu'il tombe à 11,2 par tick, et il coûte deux mains.
> **Les leviers, si tu veux corriger** : baisser ses dés (3d8 → 2d8 la mettrait à 10,8), la passer à deux mains, ou lui donner un vrai défaut — un malus de vitesse contre les cibles rapides, par exemple. Un seul chiffre dans `functionalities/masse.json` pour les deux premiers.

> [!question] 2026-09-03 — **le pistolet est moins bon que l'arc, et plus rare**
> Mesuré : pistolet **9,4** dégâts par tick, arc **10,5**. Le pistolet a une portée moindre (12 contre 25) et demande de la poudre. Sa seule supériorité est son critique large (18 contre 20), ce qui ne compense pas.
> **La question de design derrière** : est-ce que le pistolet doit être une arme **rare et brutale** — auquel cas ses dés devraient monter et sa munition rester chère — ou une **curiosité** que peu de gens jouent ? J'ai écrit ses chiffres en supposant la première, mais ils ne la servent pas. Je ne tranche pas : la place des armes à poudre dans un monde de Wu Xing est une décision de ton ressort, pas un réglage.

> [!bug] 2026-09-03 — **taper avec un bâton bat tous les sorts de toutes les classes**
> Mesure demandée par le designer (« vérifie que tout marche comme il faut, l'équilibrage etc »). Même robot, même graine 73, même équipement, 8 000 images :
>
> | profil | étages descendus | tués | coups portés |
> |---|---|---|---|
> | 3 objets, **0 sort** | 1 | **20** | 88 (fin à 68/68 PV) |
> | 3 objets, **3 sorts** | 0 | 1 | 8 — et 15 sorts lancés |
>
> > [!error] Corrigé le 2026-09-03 — **ma comparaison était fausse dans le mauvais sens**
> J'avais écrit qu'une épée rend 14,0 PV/tick et une masse 16,2, donc que tous les sorts étaient dominés. **Erreur d'unité** : `vitesse_base` divise le coût en ticks, elle ne le multiplie pas. Les armes vont en réalité de **0,40 à 1,69** PV/tick. Voir [[Audit d'équilibrage — 2026-09-03]].

**Ce que le banc dit vraiment.** Les sorts de classe vont de **0,08** (La Paume, Sève) à **6,75** (Le Rieur, Botte) — un facteur quatre-vingt-quatre entre les kits. Les sorts au **contact** encaissent en plus les dégâts de l'arme équipée, ce qui explique le haut du classement ; les sorts élémentaires à distance, eux, tournent autour de 0,7 à 1,7, soit le niveau d'une arme. Le problème n'est donc pas « les sorts » mais **l'inégalité entre les classes**.
>
> **Ce que la mesure ne capture pas, et qu'il faut peser** : un sort porte plus loin, touche une zone, pose un statut. Le banc ne mesure que les PV sur cible unique. Mais le robot, lui, joue vraiment — et il confirme : quinze lancers pour un tué contre quatre-vingt-huit coups pour vingt.
>
> **Ce que je ne tranche pas** : c'est de l'équilibrage, et c'est le cœur de l'identité du jeu — le système de modules ne doit pas être un ornement qu'on n'a jamais de raison d'utiliser. Trois leviers, du plus ciblé au plus large : (1) monter les dés des noyaux offensifs ; (2) baisser le coût en ticks des sorts, qui est ce qui les tue vraiment (10 à 21 ticks contre 4 pour un coup d'épée) ; (3) accepter que les sorts soient une réponse **situationnelle** — portée, zone, statut — et alors donner aux classes de meilleures armes plutôt que de meilleurs sorts. Les trois se défendent, et le choix dit ce qu'est le jeu.

> [!done] 2026-09-03 — **le mur du premier étage venait de ma formule de puissance, pas de la difficulté**
> Le robot équipé mourait trois fois à l'étage 1 sur la graine 73, là où la note du 2026-08-31 le voyait descendre quatre étages. **Trois hypothèses écartées par la mesure avant de trouver** : l'aggro (coupée entièrement, résultat identique au point près), l'alerte de meute (rayon mis à zéro, identique), et une régression récente (rejouée sur un arbre de travail au tag `v0.4.1-alpha` : même mort).
> **La vraie cause** : `puissance_creature`, que j'avais écrite pour le plafond de l'étage 1, compte les stats et le NOMBRE d'actions — et **ignore l'équipement**. Un bandit en cuirasse avec une épée marquait donc exactement le même score qu'un bandit à mains nues. Il passe désormais de **25 à 42** et quitte l'étage 1, dont le plafond est 26.
> **Effet mesuré** : le robot nu descend un étage au lieu de zéro ; à trois objets sans sorts, il descend et finit **à 68/68 PV** avec vingt tués contre zéro auparavant.

> [!bug] 2026-09-03 — **le monde va jusqu'au niveau 90, le butin s'arrête au niveau 15**
> Mesuré sur 500 tirages par niveau, avec la sonde de butin étendue aux niveaux lointains :
>
> | niveau du donjon | P1 | P2 | P3 | P4 | P5 | dureté moyenne | valeur moyenne |
> |---|---|---|---|---|---|---|---|
> | 10 | 25 % | 23 % | 22 % | 30 % | **0 %** | 31,1 | 31,7 |
> | 15 | 24 % | 22 % | 20 % | 27 % | 8 % | 49,6 | 49,3 |
> | 25 | 24 % | 20 % | 19 % | 28 % | 9 % | 53,4 | 52,6 |
> | 50 | 23 % | 22 % | 19 % | 26 % | 10 % | 49,1 | 50,2 |
> | **90** | 24 % | 22 % | 20 % | 24 % | 10 % | 54,0 | 54,8 |
>
> **À partir du niveau 15, plus rien ne change.** Même répartition de paliers, même dureté, même valeur. La raison est nette : `paliers_materiaux` ouvre le palier 5 à la profondeur **14**, et il n'y a pas de palier 6. Passé ce seuil, tout le catalogue est débloqué et les poids ne bougent plus.
> **Or le monde, lui, continue.** La sonde du monde mesure la pente : niveau médian **10** à un cinquième de la carte, **25** aux deux cinquièmes, **52** aux trois cinquièmes, **75** au bord (jusqu'à 90). Et la profondeur suit : un donjon de niveau 15 a 5 étages, un de niveau 90 en a **24**. Donc les six septièmes de l'échelle de niveau demandent de plus en plus de travail et ne donnent **rien de mieux**.
> **Les trois autres axes plafonnent aussi, et j'ai la cause de chacun.** Le matériau n'est pas le seul à s'arrêter :
>
> | axe | niveau 5 | niveau 15 | niveau 90 | la cause |
> |---|---|---|---|---|
> | palier de matière (P5) | 0 % | 11 % | 10 % | `paliers_materiaux` ouvre P5 à la profondeur 14, et il n'y a pas de P6 |
> | rareté (exceptionnel) | 15 % | 15 % | 16 % | `poids_par_profondeur` n'a que **cinq lignes** et s'arrête à la profondeur 4 |
> | objets à affixe | 20 % | 23 % | 23 % | conséquence directe du plateau de rareté |
> | qualité moyenne | 1,87 | 2,25 | 2,55 | `niveau / (niveau + 25) × 2` — pas de plateau dur, mais **+12 % sur soixante-quinze niveaux** |
>
> Seule la qualité continue de monter, et si peu que la différence ne se sent pas. Les trois autres sont plats par construction.
>
> **Une chose que j'ai failli te signaler à tort** : ma sonde annonçait « 0 % de légendaires » à tous les niveaux. Le défaut était dans la sonde, pas dans le jeu — la rareté haute s'appelle **artefact**, pas « légendaire », et j'avais tapé la liste à la main. Corrigée, elle lit la liste dans les règles. Et l'artefact est bien à 0 % dans les coffres — **c'est voulu** : la table de rareté n'a que quatre colonnes, et l'artefact vient d'ailleurs (`drops.artefact` : un boss de donjon majeur, une chance sur quatre). J'ai vérifié avant de crier au bug.
>
> **Ce que je ne tranche pas — et c'est une vraie fourche de design, pas un réglage** :
> 1. **étirer les paliers existants** : porter la profondeur minimale du palier 5 de 14 à 60, pour que les cinq paliers couvrent la carte. Cinq chiffres à changer, aucun contenu à écrire ;
> 2. **ajouter des paliers 6 et 7** avec les matières qui vont avec — c'est du contenu, et ça repousse le plafond plutôt que de l'étirer ;
> 3. **plafonner le monde** : si un donjon de niveau 90 n'a pas vocation à exister, c'est la courbe de niveau par éloignement qu'il faut raboter, pas le butin ;
> 4. **assumer que la fin de partie se joue ailleurs** — qualité, affixes, gemmes, Wu Xing — et alors le plateau de matériaux est voulu, mais il faut que ces autres axes montent vraiment, ce que je n'ai pas mesuré.
> Mon avis, s'il compte : la 1 est la moins chère et la plus sûre ; la 3 est la plus honnête si tu ne veux pas d'un contenu de niveau 90.


## 2026-09-03 — Trois monnaies, deux stats chacune ? (discussion ouverte, rien de code)

Le designer : « comment répartir mana et endurance (rajouter une autre monnaie ? 3 comme ça 2 stats
par monnaie ?) ». Ce que la mesure dit avant qu'on décide quoi que ce soit :

**Les réserves n'appartiennent qu'à une stat et demie.** `mana_max = 20 + volonté×3`. `santé_max =
20 + endurance×4`. Et l'endurance-la-monnaie a un `max: 100` **fixe** : investir dans l'endurance
n'agrandit pas la barre d'endurance, ça agrandit les PV. Quatre stats sur six n'agrandissent
strictement aucune réserve.

**Les coûts sont à sens unique.** 68 noyaux coûtent du mana, 18 de l'endurance, 6 sont gratuits.
Et 52 des 68 noyaux de mana sont des noyaux de volonté : la volonté remplit la barre *et* la vide.
C'est la seule stat du jeu qui se suffit à elle-même — le vrai déséquilibre n'est pas le nombre de
modules, c'est celui-là.

**La forme qui règle les deux d'un coup :** une monnaie n'appartient pas à une stat, elle en lie
deux — **l'une la REMPLIT, l'autre la DÉPENSE bien**. Personne ne se suffit, chaque style est une
paire, et les six stats se lisent d'un coup :

| monnaie | la remplit (réserve) | la dépense (puissance) | ce que ça donne |
|---|---|---|---|
| vigueur | endurance | force | le corps : on encaisse et on frappe |
| mana | volonté | perception | l'esprit : on porte et on vise |
| élan (nouveau) | dextérité | charisme | la présence : on prend le tempo et on l'impose |

L'élan est la monnaie qui manque, et le jeu en a déjà le vocabulaire (`chaine`, `tempo`) : elle ne
se régénère pas toute seule, elle se **gagne en agissant** — toucher, esquiver, enchaîner — et se
dépense en buffs, débuffs et invocations. Ça donne au charisme la boucle que la volonté a déjà, et
ça donne enfin une raison mécanique de monter la dextérité au-delà du toucher.

Trois questions restent au designer, et ce sont des questions de design, pas de mesure :

1. **Qui remplit, qui dépense ?** Rien n'oblige la volonté à être la réserve : on peut lire la
   perception comme celle qui a des réserves (elle voit le flux) et la volonté comme celle qui
   l'impose. Le tableau ci-dessus est le choix conservateur — il ne bouge pas `mana_max`.
2. **Que devient la santé ?** Si l'endurance remplit la vigueur, il faut décider si elle donne
   *encore* les PV. Sinon les PV n'ont plus de stat du tout.
3. **Les 52 noyaux de volonté.** *(Fait le 2026-09-04 : vingt noyaux martiaux écrits, force 13 · dextérité 12 · endurance 11 · perception 12 ; leurs coûts, 5 à 14 de vigueur ou de sang-froid, sont des points de départ à juger.)* Trois monnaies ne rééquilibrent rien tant que les trois quarts du
   catalogue restent sur une seule voie. Redécouper ces 52 est le vrai travail ; la monnaie n'est
   que le cadre qui dit où les ranger.

## 2026-09-03 — Le budget É2 n'est pas tenu, et ne l'a jamais été

`Décision — Budgets et critères de performance tactiques` demande **un étage de donjon généré en
moins de 100 ms**. Mesuré proprement (cinq générations à chaud, après trois tours de chauffe) :
**153 ms au minimum, 169 de médiane, 207 au pire.**

Ce n'est **pas** une régression. Vérifié dans un worktree sur le dépôt d'il y a trois heures : 132 et
239 ms, la même dispersion. Le test passait parce qu'il mesurait une seule génération **au milieu de
la suite complète**, quand le processus est chaud — et il rougissait dès qu'on le lançait seul. Il
mesurait le démarrage de Godot autant que le générateur.

Ce qu'on sait du coût, mesuré par `sonde_perf_generation` : l'étage fabrique **292 objets** à
0,157 ms pièce, soit **~46 ms — un tiers du total**. Et ça rejoint une question déjà ouverte : les
**42 coffres par étage**. Moins de coffres, c'est moins d'objets, donc un étage plus rapide *et* un
butin qui vaut quelque chose — les deux problèmes ont peut-être la même réponse.

Le test garde désormais contre l'**aggravation** (seuil à 260 ms) et dit dans son message que le
budget n'est pas tenu. Il ne prétend plus le contraire. La décision revient au designer : optimiser
la génération, ou desserrer le chiffre.

**Remesuré le 2026-09-04** : 88 à 96 ms sur six passages de la suite dans la journée, 94-96 ms à la
sonde (`sonde_perf_generation` : un objet généré 0,080 ms au lieu de 0,157, un étage de ~200 objets
au lieu de 292). **Le budget est tenu aujourd'hui.** Rien n'a été optimisé exprès ; la mesure du
3 septembre a sans doute été prise sur une machine chargée — le robot a montré le même jour que la
charge fausse ces chiffres. Le garde reste à 260 ms et le message du test dit l'état du jour.

## 2026-09-03 — La grille de composition : ce qu'un œil humain doit trancher

La grille est codée et c'est la surface du composeur (on fait son Tetris). Ce que la mesure ne peut
pas dire, et qu'il faut jouer pour savoir :

1. **Le puzzle est-il amusant ou pénible ?** Compose trois sorts avec une épée (bloc 3×3), puis les
   mêmes avec un arc (une ligne avec un talon). Si la ligne du tireur donne envie d'y revenir, la
   grille fait son travail ; si elle donne envie de changer d'arme, elle punit au lieu de définir.
2. ~~L'ordre de lecture se comprend-il sans l'expliquer ?~~ **Tranché par le designer le 2026-09-04 :
   pas de sens de lecture** — la grille est un sac de pièces. La question devient : la ligne des
   étapes (une grille par étape, N en ouvre une depuis un déclencheur) se comprend-elle sans l'aide ?
3. **Les silhouettes ont-elles une identité à l'œil ?** Bloc, lame, colonne, croix, ligne, cercle :
   dis laquelle est laquelle sans lire la légende. Celle que tu n'identifies pas est à redessiner.
4. **La taille du palier 0** est calée sur les kits des classes, pas sur le plaisir. Trop serrée, on
   ne compose rien avant le palier 10 ; trop large, la grille ne refuse jamais rien et redevient une
   liste. C'est un curseur (`combat_rules.grille.grilles_par_stat`), pas une règle.
5. **Faut-il garder la rotation ?** Elle rend le placement forgiving. Sans elle, la ligne du tireur
   n'accepterait que des barres couchées — plus dur, plus identitaire. Un booléen
   (`combat_rules.grille.rotations`).

## 2026-09-04 — La matrice des classes, enfin mesurée avec le bon robot

Le robot jouait Le Sabre quelle que soit la classe demandée (trouvé et corrigé cette nuit). Refaite
avec un représentant par classe mère, même graine : voir le tableau dans
[[Audit d'équilibrage — 2026-09-03]]. Deux choses à trancher :

1. **L'Engrenage** (rôdeur, arme de tir + tourelle) prend 100 dégâts pour un tué et meurt deux fois
   quand les cinq autres ne meurent pas ou presque. Avant d'y toucher, il faut savoir si c'est la
   classe ou le robot — le robot ne sait pas garder ses distances avec une arme de tir. Un robot qui
   recule quand il tient un projectile est une mesure à faire ; un rééquilibrage de la classe est une
   décision.
2. **Le Sceau** (sentinelle) ne prend aucun coup et descend d'un étage : les glyphes posés devant lui
   tiennent tout à distance. Si c'est voulu, c'est l'identité de la sentinelle ; si c'est trop, c'est
   le prix ou la durée des glyphes qui se règle en données.

3. **Refaite avec le kit gardé** (2026-09-04, même nuit) : avec le seul kit de départ, **quatre classes
   sur six ne tuent rien** en 2 500 images, et quatre partent avec **le même bâton magique en cuivre**
   (pauvre 0,54). Ce qui se règle en données : la qualité des armes de départ (`Etres.creer_personnage`
   les génère au niveau 1), et une arme de départ par voie — les kits des classes mères mage,
   sentinelle, érudit et meneur ne se distinguent pas par l'arme, alors que les six voies ont chacune
   six armes depuis le 3 septembre. C'est une décision de contenu, pas une mesure.

## Les 36 armes relues contre leurs identités (2026-09-04)

Le designer a demandé si les six armes par voie « correspondent bien à leurs attributs et sont toutes
différentes ». Vérifié sur les données : les 36 fonctionnalités sont sur une compétence de la bonne
voie, et aucune paire ne partage dés, vitesse, allonge, mains, type de dégâts et critique (la sonde
des armes le revérifie). Les paires les plus proches : lance / hallebarde, grimoire / orbe / talisman.
Ce qui ne colle pas à l'identité fixée le 3 septembre, à trancher :

1. **Le pavois** a une allonge de 1,5 sous l'endurance (critère : allonge ≥ 2). Un bouclier rangé
   avec les armes d'hast — le sortir de la voie, ou lui donner une allonge de 2 ?
2. **La vitesse ne prime pas** sur deux armes de dextérité : hachette de jet 1,8, javelot 1,6, plus
   lents que l'épée du guerrier (2,0). Les accélérer, ou accepter que le jet soit l'exception ?
3. **Le sabre** (1d10, 2,2, critique 19) se lit comme une lame de dextérité rangée sous la force.
4. **La sarbacane** fait 1d3, l'arme la plus faible du jeu, et c'est celle du kit du Creuset — sans
   poison à livrer, elle n'a rien pour elle.
5. **Aucune arme n'a d'affinité de sang-froid** : les armes de dextérité et de perception portent des
   affinités mana / vigueur que leurs noyaux ne dépensent jamais (la dague favorise même la vigueur).
   L'échelle des instruments a été refaite pour le mana ; rien d'équivalent pour le sang-froid.
6. Six objets `proto_*` doublent exactement six armes craft (tests seulement ; le butin pioche dans
   les bases assemblables).

**Tranché le 2026-09-04** — le designer : « je te laisse décider mais tu sais déjà ce que je veux ».
Les six points sont réglés dans le sens des identités (pavois → force, pique en endurance, jets plus
rapides, sabre lourd, sarbacane rapide à critique 17, affinité de sang-froid) : voir « Les 36 relues »
dans Structure compétences-modules-slots. Les chiffres restent à juger en jouant.

## La gestion de base (2026-09-04) — les chiffres sont des points de départ

Le designer a demandé une base façon Dwarf Fortress ([[Décision — Gestion de base, périmètres de récolte]]) ; les quatre étapes sont codées, avec des chiffres que personne n'a joués :

1. **Engager** coûte 20 or (`royaume.engagement.or`), au seuil de relation de la fiche moins 10.
   Trop bon marché, et la base se remplit en une visite de village ; trop cher, et personne n'engage.
2. **Les migrants** : 20 % par semaine, × (1 + réputation globale / 100), jusqu'à 4 résidents par
   cellule revendiquée. Une base seule au monde attire-t-elle trop vite ?
3. **Les périmètres** : 0,5 unité de bois par arbre et par semaine, 0,3 par filon, 0,8 par plante,
   plafonnés à 20 tuiles par résident, 1,5 unité de réserve par tuile, repousse de 10 % par semaine
   sur une cellule Ressources naturelles. Un bûcheron sur une forêt de 267 arbres produit donc
   ~10 bois par semaine au niveau 0 : à comparer à ce qu'on coupe à la main en une heure de jeu.
4. **L'outil de dessin** des périmètres : rectangle, pinceau, ou la cellule entière comme aujourd'hui ?

## 2026-09-04 — Une grande base simulée : vingt résidents, cinq cellules, douze semaines

Le designer, 14 h : « simule une grande base sur plusieurs cases avec une vingtaine de résidents, des zones de récolte etc ». La sonde `sonde_grande_base` (et la capture `--grande_base N`) bâtit la base par le code du jeu, monde 9 (camp en forêt tempérée) : **cinq cellules** revendiquées, **trois zones de bois** (richesse 32, 35, 25) et **deux de plantes** dessinées sur les tuiles les plus riches, deux stockages de 160, un résidentiel de 24×12, **vingt engagés** (6 bûcherons, 4 herboristes, 2 commerçants, 2 artisans, 2 fermiers, 1 garde, 3 oisifs), 1 000 or en caisse. Puis douze semaines passent par le passage hebdomadaire normal. Capture : `captures/grande_base.png` (après six semaines). Trois trous de code trouvés et bouchés en l'écrivant (un poste ET un logement, le repas double et le stock non mangé, les gens debout qui bloquaient le chantier — voir [[Décision — Gestion de base, périmètres de récolte]] et [[Faim des PNJ]]). Ce qui suit est ce que **les chiffres actuels** font, et c'est au designer de dire s'il les veut.

| semaine | logés | trésor | dette | humeur moy. | bois au stock | affamés |
|---|---|---|---|---|---|---|
| 1 | 2 | 814 | 0 | 46 | 12 | — |
| 3 | 6 | 442 | 0 | 45 | 33 | — |
| 6 | 12 | 0 | 127 | 43 | 23 | 14 |
| 9 | 11 (19 résidents) | 0 | 699 | 27 | 50 | 16 |
| 12 | 8 (16 résidents) | 0 | 1 221 | 9 | 77 | 14 |

**1. La base est un puits d'or : −190 or par semaine.** L'entretien est de 10 or par résident (200), et les deux commerçants et deux artisans rapportent une dizaine d'or à eux quatre. La caisse de 1 000 tient cinq semaines ; ensuite les paliers de dette : humeur −5, productivité, puis **un départ par semaine** dès la neuvième (20 → 16 résidents à la douzième). Tout le reste découle de là. Les questions : l'entretien de 10 or par tête est-il le bon ordre de grandeur pour une base qui ne vend rien ? Faut-il que le bois et les plantes se **vendent** (aujourd'hui ils s'entassent : 77 chênes bruts au stock à la fin, invendus) ? Ou que la boutique passive écoule le stock du territoire ?

**2. Deux fermiers nourrissent six personnes.** Chaque résident mange une unité par semaine ; un fermier récolte trois baies par semaine (rendement 0,05 × heures × humeur), les herboristes ajoutent quelques orties et champignons. Sur vingt bouches, **quatorze ont faim** chaque semaine à partir de la quatrième, −10 d'humeur chacune. Un fermier pour trois habitants, est-ce voulu ? (Le rendement des fonctions est dans `data/functions/`.)

**3. Le bois : une zone de 12×8 en forêt rend 48 unités puis repousse de 10 % par semaine.** Six bûcherons vident les trois zones en quatre semaines (réserve 0 / 6 / 5 à la fin) ; la repousse (`perimetres.repousse_hebdo` 0,1 × richesse × 1,5) tient ensuite ~9 bois par semaine. Vingt chaumières coûtent 240 bois : c'est le rythme qui limite les maisons (2 par semaine au plus, `maisons.max_par_semaine`), pas le bois. Sur une plaine (monde 31 ou 42), il n'y a **pas de bois du tout** : rien ne se bâtit.

**4. Un résidentiel de 24×12 loge douze personnes.** Une chaumière fait 6×4 = 24 tuiles, elles se serrent sans intervalle : douze maisons, huit résidents sans toit (−15 d'humeur chacun). Compter **24 tuiles par habitant** en dessinant le résidentiel — l'écran le dit désormais : la ligne du résidentiel écrit « place pour ≈ N chaumière(s) » sur ses tuiles encore libres, et le détail rappelle qu'une chaumière fait 6×4.

**5. Un raid arrive la deuxième semaine** (8 assaillants, force 20, contre un garde : subi, 50 % des stocks et de la caisse perdus). Le mécanisme existe déjà et frappe une base neuve. *Réserve : la sonde fait passer la semaine d'un coup, le combat du raid n'a pas lieu et il est compté comme subi ; en jeu, le joueur et le garde se battent. Ce que la sonde dit vraiment, c'est qu'un raid de huit arrive dès la deuxième semaine d'une base de vingt.*

**6. Les migrants ne viennent pas** tant que la base est pleine (4 par cellule × 5 = 20), et une fois les départs commencés la chance (0,2 par semaine) n'en a amené aucun en quatre semaines.

**7. En passant, sur la capture : « XP : Méditation +10 455 ».** Six semaines d'attente d'un coup — la régénération de mana donne 1 XP de Méditation à chaque tranche de 10 ticks tirée (1 chance sur 8), et la Récupération pareil sur la vigueur. Une nuit de sommeil (8 000 ticks) en donne donc une centaine sans rien faire. Est-ce voulu que dormir entraîne ?

**Ce que je propose, si le designer me laisse trancher** : rien de tout cela n'est un bug, ce sont les chiffres. Les deux qui rendent la base injouable sont l'entretien (1) et la faim (2). Le geste conservateur : que le bois, le minerai et les plantes récoltés **valent de l'or au rapport de la semaine** (vendus au prix suggéré × la marge de la boutique) — la base se paierait avec ses zones, ce qui est la promesse des périmètres —, et un rendement de fermier à **une bouche par tuile de champ** plutôt qu'à l'heure. Les deux se règlent en données.

