---
aliases: ["Simulation de vie et de monde", "Véritable simulation", "Monde vivant", "Directive de simulation", "Les onze références"]
tags: [vision, simulation, décidé, designer]
domaine: vision
statut: décidé
etape: 11
---

La directive du 5 septembre : Sensen doit être une **véritable simulation de vie et de monde**. Ce que ça veut dire exactement, ce que le jeu simule déjà — mesuré, pas supposé —, ce qui manque, et dans quel ordre le combler.

## La directive du designer (2026-09-05, reproduite telle quelle)

> « je veux que mon jeu soit une véritable simulation de vie et de monde, dwarf fortress, elin, kenshi, cataclysme, tales of maj eyal, rimworld, factorio »

C'est une directive, pas une question : elle s'applique. Elle **promeut** la simulation — jusqu'ici un pilier parmi sept ([[Piliers d'inspiration]] : « densité systémique ») — au rang de **critère de jugement du jeu**, au même titre que « un jeu de décisions, pas de dextérité » ([[Pitch et identité]]). Quatre références entrent : Kenshi, Cataclysm DDA, RimWorld, Factorio.

**Ce qu'elle ne remplace pas.** L'identité tient toujours : un jeu de décisions. La simulation la **sert** — elle donne aux décisions un monde qui répond — elle ne la remplace pas. Un système que le joueur ne perçoit jamais n'est pas de la simulation, c'est du coût.

## La règle qui tranche — ce qui compte comme simulation

Quatre conditions, toutes nécessaires. Un système qui n'en tient que trois est de la comptabilité, pas de la vie :

1. **Causal** — un état change parce qu'un autre a changé, pas parce qu'un dé l'a décidé. La foudre qui frappe le point haut le plus conducteur est causale ; un raid tiré au sort ne l'est pas.
2. **Persistant** — c'est encore vrai quand le joueur part et revient. C'est déjà la règle du LOD ([[LOD de simulation]], [[Abstraction hors-site]]).
3. **Perceptible** — le joueur peut le constater en jouant, sans ouvrir le débogage. Un chiffre qui ne sort jamais à l'écran n'existe pas.
4. **Actionnable** — le joueur peut agir dessus, ou au moins s'en servir. Sinon c'est un décor animé.

Cette règle est le filtre de tout ce qui suit, et le critère des sondes qui vérifieront chaque axe.

## Les onze références — ce qu'on prend, ce qu'on refuse

La table complète est dans [[Piliers d'inspiration]]. Ce que les quatre nouvelles apportent, et la ligne qu'on ne franchit pas :

| Référence | Ce qu'on prend | Ce qu'on ne prend pas |
|---|---|---|
| **Kenshi** | Un monde qui se fait la guerre sans le joueur ; des blessures qui durent au-delà du combat ; aucune main invisible qui met le monde à ton niveau | La lenteur, l'absence de direction, l'interface hostile |
| **Cataclysm DDA** | La granularité de la survie : température ressentie et isolation, faim, soif, sommeil, état du corps | La simulation pour elle-même — cent besoins dont aucun ne décide rien |
| **RimWorld** | La vie intérieure : besoins ressentis, traits de caractère, souvenirs qui pèsent sur l'humeur, humeur qui fait *agir* | Le conteur qui truque les événements pour faire un récit ([[Niveau de danger]] est causal, il le reste) |
| **Factorio** | Le débit : un atelier qui consomme à un rythme, un stock qui se vide, une logistique à concevoir | L'usine comme sujet du jeu ; l'automatisation totale qui retire le joueur de la boucle |

Les sept d'origine ne bougent pas. Dwarf Fortress reste la référence maîtresse de cette note — c'est d'elle que vient la mémoire du monde (axe F).

## Audit du 2026-09-05 — ce que Sensen simule vraiment

Mesuré dans le code, pas dans les notes. Neuf axes, notés par la règle des quatre conditions.

| Axe | État | Ce qui est codé | Ce qui manque |
|---|---|---|---|
| **1. Le monde physique** | **fort** | Automate d'eau (`eau_active`), feu de tuile qui se propage par flammabilité, foudre pondérée par hauteur et conductivité, lave qui se fige, météo en fonction pure du temps et du lieu, gel, courant, saisons, **température ressentie** avec l'isolation de l'équipement et de la doublure (`temperature_ressentie`) | Rien d'urgent. C'est l'axe où le jeu tient déjà la comparaison — DDA pour la température, DF pour les fluides |
| **2. Le temps et la persistance** | **fort** | Fenêtre 3×3 simulée en plein, monde hors fenêtre avancé par formules horaires et hebdomadaires (`_tiquer_monde`, `_semaine_territoire`), routine projetée au réveil (`_projeter_routine`), calendrier de douze mois et sept jours | Les **événements en zone logique** : un raid hors écran se résout au passage hebdomadaire, jamais par matérialisation |
| **3. Le corps et la survie** | **moyen** | Faim, sommeil, poids porté et surcharge, armure par zone, 84 statuts, anti-stunlock, température | La blessure qui **dure** : `_appliquer_degats` ne connaît que les PV. Pas de membre estropié, pas de convalescence, pas de maladie, pas de soif, pas de captivité |
| **4. La vie intérieure des PNJ** | **faible** | `humeur` : **un entier**, recalculé une fois par semaine (`_recalculer_humeurs`), **pour les seuls résidents du territoire du joueur**, à partir du logement, de la chambre, des co-occupants, de la faim, de la dette et des fêtes. Il ne sert qu'à `facteur_humeur` — un multiplicateur de production borné [0,4 ; 1,2] | Tout le reste : pas de besoins ressentis, pas de traits, pas de souvenirs, pas de goûts, pas d'humeur qui fait *agir*. C'est de là que RimWorld et DF tirent leur récit entier |
| **5. Les liens entre PNJ** | **faible** | Les **familles** existent vraiment : conjoint, enfants, parents, mariages, naissances, héritiers ([[Familles et succession]]) — c'est la seule relation PNJ↔PNJ du jeu | `social.relations` n'a en pratique **qu'une clé** : l'identifiant du joueur — `reputation()` est la seule fonction qui y écrit. Aucune amitié, aucune rancune, aucune rivalité, aucune opinion d'un PNJ sur un autre |
| **6. L'économie** | **moyen** | Prix suggéré par formule, stocks de boutique et réapprovisionnement, douanes, trésor, dette, taxes, marchés du calendrier | La ville ne **produit** ni ne **consomme** pour elle-même ; les prix ne viennent pas de l'offre et de la demande ; rien ne circule entre deux villes. C'est B3, déjà au programme |
| **7. Les chaînes de production** | **faible** | Le craft compositionnel est profond — 245 matières → composants → objets, stats calculées ([[Craft compositionnel]]) — et les postes de récolte assignés à un périmètre en sont l'embryon | C'est une **recette**, pas une **chaîne** : rien ne consomme en continu, rien n'a de débit, rien ne se logistique entre deux stockages. Factorio n'a aujourd'hui aucun équivalent dans le jeu |
| **8. La géopolitique** | **faible** | Royaumes déterministes avec nom, gouvernance, territoire contigu, capitale, lois, douanes, accords, successions ([[Génération des royaumes PNJ]]) | `_semaine_royaumes_pnj` ne fait **qu'une chose** : combler les vacances de dirigeant et de hall de guilde. Aucune frontière ne bouge d'elle-même, aucune guerre entre royaumes PNJ, aucune disette. Kenshi, c'est exactement l'inverse |
| **9. La mémoire du monde** | **absent** | — | Rien n'enregistre ce qui s'est passé. Le calendrier date les jours depuis l'an 1 020, mais **l'an 1 019 n'existe pas**, et la conquête d'un village hier ne laisse aucune trace consultable. C'est le *Legends* de DF : ce qui fait qu'un monde paraît **réel** plutôt que **neuf** |

**Ce que l'audit dit en une phrase :** Sensen simule très bien la **matière** (axes 1 et 2) et très peu les **gens** (axes 4, 5, 9). Or ce sont les gens qu'on cite quand on dit « Dwarf Fortress » ou « RimWorld ».

## Le programme — F à K, après A à E

[[Un monde réel — villes, PNJ, royaumes et calendrier]] porte déjà A (calendrier, fait), B (villes), C (PNJ), D (royaumes), E (la 0.5.0). Les axes ci-dessous **complètent** ce programme sans le remplacer ; C absorbe G et H.

- **F. La chronique** — la mémoire du monde. Les systèmes émettent déjà leurs événements au journal (succession, conquête, raid, mort d'un PNJ nommé, fête, disette) : il s'agit de les **enregistrer** comme faits datés `{date, lieu, acteurs, type}` au lieu de les afficher puis les perdre, d'en **générer une pré-histoire** à la création du monde (règnes, fondations, guerres, catastrophes avant l'an 1 020), de les rendre **lisibles** (un écran, une entrée de dialogue : « le vieux se souvient de la peste de 1 011 »). Le moins cher de tous — additif, réversible, aucun risque d'équilibrage — et le plus fort en « monde réel ». Il fait payer A et D.
- **G. La vie intérieure** (dans C) — des **besoins ressentis** en continu (repos, ventre, chaleur, société, sens), des **traits** en données JSON, des **souvenirs** qui expirent, et l'humeur comme leur **somme** au lieu d'un entier hebdomadaire. Pour **tout être**, pas seulement les résidents ([[Contraintes permanentes]] : le joueur n'est pas un type à part). Garde-fou : `facteur_humeur` reste la sortie, donc rien en aval ne change tant que le designer n'a pas jugé.
- **H. Les liens entre PNJ** (dans C) — l'opinion d'un PNJ sur un autre, construite de ses traits, de ce qu'ils ont vécu ensemble et de la famille. Amitiés, rivalités, rancunes. Alimente [[Dialogue PNJ]], [[Quêtes et guildes]] et la politique des villes.
- **I. Le corps qui garde ses cicatrices** — Kenshi et DDA : la blessure qui survit au combat, la convalescence, l'estropié, la maladie, la soif, la captivité. **C'est l'axe au plus gros risque de design** : il touche [[Mort et pénalité]], qui est une décision fondatrice (« pas de permadeath, on pénalise l'économie »). Rien ne se code ici sans le designer.
- **J. Les chaînes de production** — Factorio : un atelier qui consomme des entrées à un **débit**, un stock qui se vide et se remplit, une logistique entre deux périmètres, puis les rails de B4 comme transport de masse. Dépend de B (la ville comme territoire) ; c'est l'axe qui transforme la base d'une liste d'assignations en une **machine qu'on conçoit**.
- **K. La géopolitique vivante** (dans D) — des royaumes qui se font la guerre, qui ont faim, qui s'étendent et qui perdent des villes, sans le joueur. Dépend de D et de F : une guerre dont personne ne garde le souvenir n'a pas eu lieu.

**Ordre recommandé, et pourquoi.** F d'abord — il est peu cher, sans risque, et il rend tout le reste lisible : chaque axe suivant écrira dans la chronique au lieu d'ajouter son propre affichage. Puis G et H, qui sont le programme C et la demande 92 du designer. Puis B3 (l'économie) et J, qui vont ensemble : un débit sans économie ne se mesure pas. K avec D. **I en dernier**, parce que c'est le seul qui puisse changer ce qu'est le jeu.

## Ce que ça coûte, dit franchement

Chaque axe ajoute de l'**état par être**, et le monde en porte plus de cent. La règle de [[Simulation du monde — performance]] ne bouge pas et devient le garde-fou de ce programme :

- **Rien de tiquable par PNJ hors fenêtre.** La leçon du niveau 2 est déjà payée ([[LOD de simulation]]) : on a remplacé un graphe qu'on tique par une **projection au réveil**, coût nul pendant l'absence. Tout ce qui est ajouté ici suit la même forme — un besoin hors fenêtre se calcule à la lecture depuis `dormant_depuis`, il ne s'incrémente pas.
- **La chronique est bornée.** Un monde qui vit mille ans ne peut pas garder chaque fait : la pré-histoire est résumée par règne, et les faits anciens se condensent. Le budget est un nombre en données, pas une liste qui gonfle.
- **Tout en JSON validé par schéma** ([[Data-driven design]]) : les traits, les besoins, les types de faits de la chronique, les seuils. Aucun nombre de gameplay en dur.
- **Sauvegarde** ([[Sauvegarde]]) : la chronique et les souvenirs sont du nouvel état à sérialiser — c'est le seul poste de coût disque de ce programme.

## À trancher par le designer

Consigné aussi dans [[À juger — parcours de jeu]]. Ces quatre-là ne sont pas des réglages : chacun change ce qu'est le jeu.

1. **Le corps (axe I) contre « pas de permadeath ».** [[Mort et pénalité]] est une décision fondatrice. Kenshi tient à ce qu'on perde un bras et qu'on continue. Les deux se marient — un estropié n'est pas un mort — mais il faut le dire.
2. **L'humeur qui fait agir (axe G).** Un PNJ malheureux part-il, vole-t-il, se révolte-t-il ? RimWorld dit oui, et c'est la moitié de son intérêt. C'est aussi ce qui rend une base ingouvernable.
3. **Le débit (axe J) : RimWorld ou Factorio ?** Le joueur **assigne des gens** (aujourd'hui) ou **conçoit une chaîne** (convoyeurs, stocks tampons, goulots) ? Les deux se défendent ; le choix décide de ce qu'est l'endgame de territoire.
4. **La pré-histoire (axe F).** Combien d'années le monde a-t-il vécu avant l'an 1 020, et le joueur peut-il tout lire, ou seulement ce qu'un PNJ veut bien lui dire ([[L'information comme récompense]]) ?

## Liens
- **Dépend de** : [[Pitch et identité]], [[Piliers d'inspiration]], [[Contraintes permanentes]]
- **Alimente** : [[Un monde réel — villes, PNJ, royaumes et calendrier]], [[Villes — population, quartiers et économie]], [[IA des créatures]], [[Réputation et relations]], [[Économie — sources et puits]], [[Vers la production]]
- **Voir aussi** : [[LOD de simulation]], [[Abstraction hors-site]], [[Mort et pénalité]], [[Familles et succession]], [[Simulation du monde — performance]], [[À juger — parcours de jeu]], [[Prompt de la boucle]]
