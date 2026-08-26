---
aliases: ["F.3", "Annexe F.3", "Créatures", "Catalogue des créatures", "34 créatures"]
tags: [contenu, êtres, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 9
---

Les 34 créatures de départ — animaux réels et humains uniquement. La menace vient des bêtes, des humains hostiles et de l'environnement.

*Format : nom — squelette — niv. combat approx — profil IA — recrutable — notes. Tous suivent le schéma [[Schéma créature]] ; les civils ont des `jobs_compatible`. **Aucune créature fantastique — décision ferme**, pas un état provisoire.*

**Civils (humains, villages) :** Villageois (nv 3, civil, relation 60, jobs fermier/vendeur) · Fermier (nv 3, civil, relation 55, agriculture 15) · Forgeron (nv 6, civil, relation 65, forge 25) · Marchand ambulant (nv 5, civil, relation 70, négociation 20, caravanes inter-villages — pathfinding global [[IA des créatures]]) · Garde de village (nv 12, garde, relation 75) · Prêtre de sanctuaire (nv 8, civil, relation 80, ressuscite les compagnons [[Compagnons]]) · Maître de guilde (nv 20, civil, jamais) · Érudit (nv 4, civil, relation 60, lecture 30) · Tavernier (nv 5, civil, relation 65) · Chasseur (nv 9, civil, relation 60, arc 18, dressage 12) · Roi/Reine (nv 25, civil+escorte, dressage DD élevé — capturable, [[Population et exploitation]])

**Humains hostiles :** Bandit (nv 10, hostile, relation — se rend si dominé) · Chef de bande (nv 16, hostile, relation, camps [[Carte du monde]]) · Braconnier (nv 8, hostile si surpris, relation) · Pillard (nv 12, assaillant, relation, raids [[Raids et menaces]]) · Déserteur (nv 11, hostile, relation) · Ermite (nv 14, neutre→hostile si dérangé, relation 85, donjons/ruines — gardien humain des trésors)

**Plaines/forêts tempérées :** Loup (quadrupède, nv 6, bete_sauvage, meutes 1d4+1, dressage) · Sanglier (quadrupède, nv 8, bete_sauvage acculée, dressage) · Cerf (quadrupède, nv 3, fuit, dressage) · Renard (quadrupède, nv 3, fuit, dressage) · Essaim d'abeilles (amorphe, nv 4, hostile près de la ruche, jamais — miel récoltable)

**Désert :** Scorpion (quadrupède bas, nv 7, hostile, dressage, statut poison) · Vautour (volant, nv 5, hostile si blessé détecté, dressage) · Chameau sauvage (quadrupède, nv 6, fuit, dressage — monture endurante) · Nomade (humain, nv 9, civil, relation, marchand itinérant)

**Toundra/taïga :** Ours polaire (quadrupède, nv 18, bete_sauvage, dressage, fourrure isolante) · Loup blanc (quadrupède, nv 8, meutes, dressage) · Renne (quadrupède, nv 4, fuit, dressage/élevage) · Morse (quadrupède, nv 12, bete_sauvage sur la côte, dressage)

**Marécage :** Crocodile (quadrupède bas, nv 14, embuscade aquatique, dressage) · Nuée de moustiques (amorphe, nv 4, hostile, jamais, dégâts continus faibles + risque infection) · Serpent venimeux (amorphe, nv 8, hostile si approché, dressage, poison)

**Montagne :** Aigle (volant, nv 7, bete_sauvage, dressage) · Ours brun (quadrupède, nv 16, bete_sauvage, dressage) · Bouquetin (quadrupède, nv 4, fuit, dressage/élevage) · Lynx (quadrupède, nv 9, embuscade, dressage)

*Note : les niches "créatures de donjon" sont occupées par les humains hostiles (bandits, pillards, ermites) et les bêtes tanières (ours, loups) — un donjon est une ruine investie, pas une crypte magique. **Le bestiaire reste définitivement réaliste** : la réintroduction de créatures fantastiques est abandonnée ([[Ouvert — Créatures fantastiques]]) ; la haute corruption produit des bêtes réelles plus dangereuses, pas d'autres espèces.*

**Drop rare universel — la statue 1:1 :** toute créature a une faible chance (défaut **0.5 %**, pondérable par créature) de dropper une **statue d'elle-même à l'échelle 1:1** — un meuble décoratif (posable, [[Meubles]]-like) généré automatiquement : le modèle assemblé exact de la créature (ses parties tirées, [[Schéma unifié créature-PNJ]]/[[Squelette modulaire et points d'attache]]), **recolorisé en pierre** via le remapping de palette existant ([[Entités et pathfinding — performance]] — zéro asset à produire). Trophée de chasse ultime, objet de collection et de prestige (humeur/déco), valeur de vente ∝ niveau de la créature.

**Portefeuilles cohérents ([[Barèmes économiques]]) :** villageois/client 30, marchand 300, maître de guilde 2000, roi 15000.

**Profils d'IA ([[IA des créatures]]) :** `hostile`, `bete_sauvage`, `civil`, `garde`, `assaillant`, `compagnon`.

**Spawns nocturnes ([[Cycle jour-nuit et sommeil]]) :** les tables de spawn par biome ont un volet « nuit » — loups en chasse, prédateurs embusqués, humains hostiles en maraude.

**Viandes et parties dérivées :** [[Catalogue matériaux — Paramétriques]].

## Liens
- **Dépend de** : [[Schéma créature]], [[Squelette modulaire et points d'attache]], [[IA des créatures]]
- **Alimente** : [[Catalogue matériaux — Paramétriques]], [[Monstres rares]], [[Génération de donjon]], [[Meubles]], [[Cuisine et alchimie]]
- **Voir aussi** : [[Apprivoisement et recrutement]], [[Population et exploitation]], [[Barèmes économiques]], [[Cycle jour-nuit et sommeil]], [[Statuts]], [[Ouvert — Créatures fantastiques]], [[Décision — Vocabulaire d'attaque des créatures]]
