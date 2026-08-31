---
aliases: ["4.2.2", "4.2.2 Palier industriel", "Palier industriel", "Recettes industrielles"]
tags: [objets, craft, endgame, décidé]
domaine: objets
statut: décidé
etape: 6
---

L'endgame d'artisanat : des recettes trouvées et achetées, statistiquement supérieures mais élémentairement muettes. Aucun système nouveau.

Le joueur **trouve et achète des recettes industrielles** (ruines profondes, marchands des capitales, rangs hauts de guilde) : aciers alliés, béton, verre trempé, brique réfractaire, caoutchouc. Aucun système nouveau — ce sont des entrées de plus en [[Composant et recette d'obtention]], avec des `unlock_sources` exigeantes et des stations améliorées (Forge → **Haut fourneau**, Enclume → **Laminoir**) consommant du **combustible** (coke/charbon), ce qui redonne un usage aux minerais communs de fin de partie.

**Équilibrage automatique par le Wu Xing** : ces matériaux sont des composites, donc leurs vecteurs sont **plats** (acier inox Métal 0.6 / Feu 0.25 / Eau 0.15 ; béton armé Terre 0.4 / Métal 0.35 / Eau 0.15 / Feu 0.10). Résultat : **statistiquement supérieurs, élémentairement muets** — multiplicateurs amortis, jauge de chaîne terne. Le fer pur d'un forgeron reste meilleur pour un build Wu Xing que l'acier allié d'une ruine. Puissance brute contre expressivité, sans aucun nerf à écrire.

**Règle générale ([[Wu Xing hors combat]]) :** *plus un matériau est composite, plus son vecteur s'aplatit* — d'où des matériaux industriels statistiquement forts mais élémentairement muets.

**Ce qu'il remplace ([[Craft compositionnel]]) :** la chimie élémentaire (Extracteur/Synthétiseur, 58 éléments) supprimée le 2026-08-09. Voir [[Décisions fondatrices]].

**Combustibles concernés ([[Catalogue matériaux — Minéraux]]) :** Houille (carburant de forge), Lignite (médiocre), Anthracite (meilleur carburant), Tourbe compactée.

**Les classes technologiques ([[Talents de classe]]) :** **La Mèche** (bombes) et **L'Engrenage** (tourelles) se découvrent aux mêmes endroits que ces recettes — ruines profondes, marchands des capitales, hauts rangs de guilde. La technologie a désormais des porteurs, pas seulement des plans.

> [!success] Codé le 2026-08-28
> Recettes marquées `industrielle: true` (`recipes/tremper_verre`, `cuire_brique_refractaire`, `couler_beton`) : **invisibles à l'atelier tant qu'elles ne sont pas connues** (`e.recettes_connues`). On les apprend en lisant un **plan industriel** (objet `plan_industriel`, type manuel, tag `plan` : le générateur lui donne une recette industrielle au lieu de modules ; même jet de lecture que les livres) — trouvé dans les **ruines profondes** (`loot_rules.drops.plan` : étage ≥ 3, 8 % des drops du tout-venant) ou acheté chez les **forgerons** de ville (inventaire du type de boutique). Matériaux ajoutés au catalogue synthétique : **verre trempé** (30), **brique réfractaire** (32), **béton** (40) — vecteurs plats (terre/feu/eau à parts proches), statistiquement forts, élémentairement muets. Combustible : la houille. Aciers alliés et caoutchouc attendent (l'acier et l'acier trempé existaient déjà comme métaux).

> [!success] Codé le 2026-08-28 — aciers alliés et caoutchouc
> Trois matériaux de plus, recettes `industrielle: true` à la **forge** (apprises par plan industriel comme les autres) : **acier inoxydable** (`allier_inox` : 2 acier + 1 chrome + 1 nickel + 1 anthracite ; catégorie `metal`, donc utilisable dans les lames et plaques ; dureté 42, valeur 45 ; vecteur plat Métal 0,6 / Feu 0,25 / Eau 0,15 comme dans la note), **acier au tungstène** (`allier_acier_tungstene` : 2 acier + 1 tungstène + 1 anthracite ; dureté 50, densité 16, valeur 55 ; Métal 0,7 / Feu 0,2 / Terre 0,1), **caoutchouc** (`vulcaniser_caoutchouc` : 3 sève + 1 soufre + 1 houille ; catégorie `synthetique`, élasticité 90, friction 80, isolation 60, conductivité électrique 0 ; Bois 0,5 / Eau 0,3 / Feu 0,2). Décision : l'anthracite est le combustible des alliages (meilleur carburant de la note), la houille suffit à la vulcanisation ; pas de haut fourneau ni de laminoir en station propre — la forge porte tout tant que les stations industrielles n'ont pas de meuble.

> [!success] Corrigé le 2026-08-31 — le forgeron vend enfin les plans
> La note promettait les plans industriels « achetés chez les forgerons de ville (inventaire du type de boutique) », mais `shop_types/forgeron.json` ne sélectionnait que armes, outils et stations — la seule source réelle était le drop des ruines profondes. Un bloc de sélection `manuel` + tag `plan` (0 à 1 par réassort hebdomadaire) rejoint l'étal du forgeron : le générateur d'objets lui donne sa recette industrielle comme pour un plan trouvé en donjon.

## Liens
- **Dépend de** : [[Craft compositionnel]], [[Composant et recette d'obtention]], [[Stations de transformation]]
- **Alimente** : [[Wu Xing hors combat]], [[Jauge de chaîne Wu Xing]]
- **Voir aussi** : [[Décisions fondatrices]], [[Catalogue matériaux — Minéraux]], [[Quêtes et guildes]], [[Décision — Surcharges Wu Xing des matériaux]]
