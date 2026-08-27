---
aliases: ["À juger", "Parcours de jeu", "Session de jugement"]
tags: [index, production, ouvert]
domaine: index
statut: ouvert
etape: 10
---

**Tout ce qui attend un œil humain, dans l'ordre où on le rencontre en jouant.** Chaque incrément a laissé ses questions dans [[Vers la production]] ; cette note les regroupe en un **parcours d'une heure** (`godot/` dans l'éditeur, F5, ou `main.tscn`). Répondre = écrire un callout daté dans la note concernée ; le code suit.

> [!important] Ce que la boucle autonome ne peut pas juger (2026-08-28)
> Elle lance les tests, la scène headless et des captures ; elle ne ressent ni le rythme, ni la lisibilité, ni le plaisir. Les questions ci-dessous sont **les seules** qui bloquent : le solo doit être « bon » avant la coop ([[Ordre de construction]], étape 11).

## 1. Arriver — le camp, l'iso, le corps (10 min)

- **Lisibilité de l'iso** 32×32 : le relief se lit-il, faut-il des ombres de flanc ou une grille ? (molette : zoom, clic milieu : déplacer) — [[Prototype de combat — spécification]]
- **Fluidité** : vitesse du glissement, rendu translucide du mémorisé ; **recentrage** au passage d'une cellule (~150-300 ms si non pré-générée) — [[Boucle de tick]]
- **Le camp a-t-il l'air d'un lieu ?** Les accidents de relief sont-ils assez nombreux, la couleur de sol par biome suffit-elle ? Le camp vide au départ est-il lisible (récolter à la hache, scier, poser) ? — [[Génération par couches de bruit]], [[Claims et persistance]]
- **Végétaux en billboards** : silhouettes assez lisibles et variées, taille des arbres vs personnages, occultation d'un être derrière un arbre (les sprites définitifs sont pour plus tard, décision du designer) — [[Direction artistique]]
- **Faim et poids** : vitesse de la faim (2 h 30 de jeu actif), −10 % de stats sous 25, capacité de charge — [[Faim]], [[Armures et poids porté]]
- **Nuit et météo** : obscurité de la nuit (trop ? pas assez ?), fréquence des pluies et orages, sévérité du froid/chaud sans vêtements — [[Cycle jour-nuit et sommeil]], [[Météo]]

## 2. Le monde — carte, biomes, voyage (10 min)

- **Carte du monde (M)** : une couleur par biome suffit-elle ? La règle « voyage seulement vers l'exploré » ? Le coût en temps du voyage ? Les **territoires teintés** des royaumes se lisent-ils (à vérifier avec un royaume en vue — aucun ne tombait près du camp sur la capture) — [[Carte du monde]], [[Génération des royaumes PNJ]]
- **Côtes et mer** : forme des côtes, part de mer visible depuis le camp, lisibilité des 12 biomes par le sol et les arbres — [[Biomes — schéma]]
- **Minimap** : teintes par matériau, place à l'écran ; on ne sauvegarde qu'en surface — [[Sauvegarde]]
- **Dérive de la corruption** : on ne la voit qu'en dormant beaucoup (une semaine = 21 nuits) — faut-il afficher le delta ? — [[Dérive de la corruption]]

## 3. Le donjon — combat, loot, étages (10 min)

- **Rythme** : `DELAI_PAS = 0.12 s` entre deux pas — trop lent, trop rapide pour suivre les loups ? Durée d'une rencontre (cible 60-200 ticks, affichée à l'écran de fin)
- **Télégraphe** (« ! » + tuiles rouges) vu à temps ? **Coûts sur les tuiles** (jaune) utiles ou bruit ? **Capacités** (F1 + clic) : la prévisualisation suffit-elle ?
- **Chaîne Wu Xing** : les deux voies sont hors cible (écart 36 % ; le swap ne paie jamais) — **chiffres à trancher** (+0,35 → +0,45 sur l'engendrement ? une charge moyenne dans la rotation ?) — [[Wu Xing — cycles et vecteurs]]
- **Labyrinthe** : lisibilité des salles murées de roche, variété des étages, densité des couloirs, taille des salles — [[Donjons — structure et intégration]]
- **Récolte en donjon** : lisibilité des filons, portée de la Perception, proportion de tuiles récoltables — [[Récolte]]
- **Écrans** : l'atelier en texte devient-il illisible avec 176 composants ? L'inventaire ? — [[Écrans d'interface]]

## 4. Le village — PNJ, commerce, quêtes, compagnons (10 min)

- **Hameau en blocs** : lisibilité ; sonorité des noms générés ; **prix** (un lingot de fer = 8 or après troc : trop ? trop peu ?) — [[Villages PNJ — repeuplement et décimation]], [[Prix suggéré]]
- **PNJ** : mouvement (pas glouton, ils butent sur un mur), densité de faune (12 bêtes), la nuit vraiment dangereuse ? — [[IA des créatures]]
- **Réputation et quêtes** : rythme (3-8 cibles, 15 or × niveau), lisibilité des paliers dans le dialogue, frapper un civil rend tout le village hostile après deux coups — [[Réputation et relations]], [[Quêtes et guildes]]
- **Compagnons** : suivre sans postures (ils attaquent tout ennemi à portée), coût de résurrection (20 or × niveau × 1,5), fréquence des morts de vieillesse — [[Apprivoisement et recrutement]]
- **Boutiques typées et halls** : une capitale de grand royaume (9-12 bâtiments) tient-elle dans la cellule ? « Quelle ville a quel hall » se lit-il (pas sur la carte) ? — [[Halls de guilde]]
- **Douanes et lois** : les tarifs sont-ils lisibles dans l'écran de commerce ? **La loi absurde fait-elle rire ?** — [[Lois et infractions]]

## 5. Le territoire — claims, production, raids, royaume (15 min)

- **Claim** (clic sur une cellule voisine depuis M) : le coût `50 or × cellules` est-il lisible ? — [[Expansion territoriale]]
- **Semaine** (= 21 nuits) : la production d'un résident se voit-elle ? L'écran de gestion (K) en liste suffit-il ? — [[Population et exploitation]]
- **Parcelles** : un jour de pousse à 24 000 ticks est-il long ? La récolte au clic ? — [[Agriculture et élevage]]
- **Boutique passive** : caisse séparée du trésor (à relever sur l'étal) — bon ou agaçant ? **Troc d'office** des marchands à sec sans écran d'acceptation ? — [[Boutique passive]], [[Économie — sources et puits]]
- **Raids** : probabilité de base 0,05 et échelle `valeur/20` ; un raid qui tombe pendant la nuit sautée se lit-il ? La tourelle sans recette. La punition d'une dette de 4 semaines quand un raid tombe — [[Défense et raids]], [[Raids et menaces]]
- **Conquête** (clic sur la place d'un village) : lisible en un jet et un message ? La **vacance de trône** se remarque-t-elle ? — [[Conquête de village]], [[Familles et succession]]

## 6. Alchimie et élevage (5 min)

- **Potions** : +3 / +6 × puissance de la partie (stat de la créature / 10) pendant 3 000 ticks — sensible ? La différence loup / chef de bande se sent-elle ? — [[Cuisine et alchimie]]
- **Élevage** : le facteur **×15** entre qui sélectionne et qui laisse faire ([[Règle d'anneau]]) — à mesurer sur une dizaine de couvées de carpes ; le nom des spécimens (indices bruts) ; une espèce par famille suffit-elle à sentir les six verbes ? Le miel (1 par 4 abeilles) est-il trop lent ? — [[Catalogue des groupes d'élevage]]

## Comment répondre

Un callout daté dans la note liée (`> [!success] Tranché le <date>`) — la boucle autonome le lit avant de coder. Une réponse « ça va » suffit pour fermer un point ; une valeur chiffrée suffit pour un réglage.

## Liens
- **Dépend de** : [[Vers la production]], [[Ordre de construction]]
- **Alimente** : [[Ordre de construction]]
- **Voir aussi** : [[Prototype de combat — spécification]], [[Écrans d'interface]]
