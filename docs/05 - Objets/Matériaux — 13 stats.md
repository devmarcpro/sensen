---
aliases: ["4.2", "4.2 Matériaux, récolte et artisanat", "4.2 stats", "C.5", "Annexe C.5", "13 stats", "Stats des matériaux", "Matériaux"]
tags: [objets, matériaux, décidé]
domaine: objets
statut: décidé
etape: 6
---

Chaque matériau porte 13 statistiques fixes. Le choix du matériau dans un craft est un arbitrage multidimensionnel, pas seulement dureté/poids.

**Catégories de matériaux :** chaque matériau appartient à une catégorie (bois, minerai, roche, liquide, synthétique, etc.). Voir [[Catégories de matériaux]].

**Stats par matériau :** chaque matériau possède ses propres statistiques individuelles fixes, indépendamment de sa catégorie. **13 stats** (effets détaillés en [[Application des stats de matériau]], schéma en [[Schéma matériau]]) :
- `durete` — dégâts, protection, récolte
- `densite` — poids, vitesse d'arme
- `valeur_base` — économie
- `conductivite_mana` — efficacité magique (réduction des coûts en mana)
- `flammabilite` — prend feu, vitesse de combustion
- `isolation` — protection chaleur/froid
- `conductivite_electrique` — sensibilité/propagation de la foudre
- `flottabilite` — flotte ou coule (crucial pour les véhicules navals)
- `luminosite` — émet de la lumière (éclairage, visibilité/discrétion)
- `fertilite` — rendement agricole du sol ([[Agriculture et élevage]])
- `transparence` — laisse passer la lumière/le regard (fenêtres, serres)
- `elasticite` — amortit les chutes, puissance des arcs
- `friction` — surfaces glissantes (glace) ou routes rapides (pavés)

Le choix du matériau dans un craft est donc un **arbitrage multidimensionnel**, pas seulement dureté/poids.

**Rappel C.5 :** les 13 stats sont `durete`, `densite`, `valeur_base`, `conductivite_mana`, `flammabilite`, `isolation`, `conductivite_electrique`, `flottabilite`, `luminosite`, `fertilite`, `transparence`, `elasticite`, `friction`. Tags dérivés par seuils ([[Schéma matériau]]) + tags manuels : `organique`, `corrompu`.

**Important :** les matériaux bruts n'ont **pas de "qualité"** — seulement leurs stats fixes. La récolte n'améliore jamais la qualité d'un matériau, seulement la vitesse/quantité obtenue ([[Récolte]]).

**Décision :** *Stats par matériau : résolu* — 13 stats, chiffrées pour les **153 matériaux** du catalogue ([[Catalogue matériaux — Bois]] et suivants).

**Vecteur Wu Xing dérivé de la catégorie :** voir [[Wu Xing hors combat]].

> [!success] Codé le 2026-08-28 — `data/materials/` (155 fichiers), `tools/gen_materials.py`
> Les **155 lignes des 11 tables de catalogue** (la table fait foi, pas l'en-tête) sont transcrites par `tools/gen_materials.py` : 13 stats, couleur de la palette (unique, vérifiée au boot), outil/compétence de la catégorie, surcharge `wuxing` de [[Décision — Surcharges Wu Xing des matériaux]] (44 matériaux), clés `material.<id>.name` dans `locale/fr.csv`. Les gabarits paramétriques (feuilles, pousses, parties de créatures) attendent leurs sources (arbres, dépeçage). L'id est le slug du nom sans parenthèse : `aluminium`, `chrome`, `guano`.

> [!success] Codé le 2026-09-02 — trente-et-un matériaux de plus, et une passe de cohérence sur les 166 anciens (designer)
> « Il manque pas mal de matériaux », puis « profites-en pour repasser sur ceux qu'on avait déjà », puis « tu peux rééquilibrer, j'ai écrit aucune stats ».
> **Ce qui manquait était fonctionnel, pas décoratif.** De quoi faire un **arc composite** (corne, tendon), une corde (crin, boyau), un empennage (plume) — un jeu d'assemblage où l'on ne pouvait ni corder un arc ni empenner une flèche. Les matières **travaillées** que l'artisanat produit et que rien ne représentait : cuir bouilli (l'armure légère historique), charbon de bois (qui fait l'acier), poix, cire, feutre, porcelaine. Des métaux qui ont un **caractère** et pas seulement une dureté : la fonte casse, l'acier damassé est le haut du panier, l'électrum est un alliage naturel. Des minéraux qui **font** quelque chose : magnétite, hématite, galène, alun.
>
> **Le principe de la passe de cohérence** : les chiffres doivent respecter l'**ordre** du monde réel, pas ses unités. Un joueur ne connaît pas la densité du plomb, mais il sait que le plomb est plus lourd que le fer et que l'ébène coule. Quand le catalogue contredit ce savoir-là, il ment ; quand il le respecte, il s'apprend tout seul.
> - **Les densités des métaux** étaient approximatives et parfois fausses : le bismuth passait pour plus lourd que le plomb, le tungstène pour plus lourd que le platine. Ce n'est pas cosmétique — la densité décide du **poids porté** et de la **vitesse d'arme** (un manche dense frappe plus lentement) : l'erreur se voyait en jeu. Vingt-six densités alignées sur le réel, arrondi.
> - **Les gemmes étaient des conductrices électriques** — topaze 70, améthyste 45 — alors que ce sont des isolants, et leur dureté ignorait l'échelle de Mohs qui les classe depuis deux siècles. Dureté = Mohs × 5 : le diamant devient la matière la plus dure du jeu, ce qu'il est.
> - **Trois contradictions isolées** : le buis et l'ébène **flottaient**, alors que ce sont précisément les deux bois qui coulent ; la glace était plus dense que l'eau ; le sel gemme sec conduisait le courant.
> - **L'os était plus dur que le tungstène** (34 contre 42, le fer à 25). C'était la cause du butin saturé d'armures en os dont le designer s'était plaint, et le palier dérivé le rangeait en matière de fin de partie. Ramené à 16.
> - **Dix matières manufacturées n'avaient ni outil ni compétence de récolte** : démolir un mur de brique ou une vitre ne rendait rien. La maçonnerie se défait à la pioche, le papier et le caoutchouc se découpent.
> Cinquante-huit corrections sur quarante-cinq fiches. La courbe du butin par niveau de donjon ne bouge pas.


## Liens
- **Dépend de** : [[Data-driven design]]
- **Alimente** : [[Application des stats de matériau]], [[Schéma matériau]], [[Stats d'un objet crafté]], [[Récolte]], [[Craft compositionnel]]
- **Voir aussi** : [[Catégories de matériaux]], [[Wu Xing hors combat]], [[Qualité d'artisanat]], [[Catalogue matériaux — Bois]]
