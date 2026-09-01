---
aliases: ["5.3", "5.3 XP de combat", "XP de combat", "XP = dégâts appliqués"]
tags: [combat, progression, décidé]
domaine: combat
statut: décidé
etape: 4
---

L'XP vaut les dégâts appliqués, versée à trois pistes simultanées — et l'armure gagne ce qu'elle épargne.

`xp = dégâts réellement appliqués` (après armure, après le minimum de 1), **plafonnés aux PV restants** de la cible (un coup à 400 sur une cible à 30 PV rapporte 30 — anti-overkill).

Versée **en entier à trois pistes simultanées** :
1. l'**élément** du coup (le même dominant qui a rempli le segment de chaîne) ;
2. la **compétence d'arme** (ou le domaine de magie pour un module) ;
3. la **maîtrise de type de dégâts** (tranchant / perforant / contondant).

Le multiplicateur de **potentiel** ([[Potentiel]]) s'applique ensuite, **par piste**.

**Côté défense, symétrie exacte** : l'armure gagne ce qu'elle **épargne** — `dégâts évités` versés à la **compétence de construction** de la pièce touchée (Matelassé, Cuir, Mailles, Écailles, Plaque). Une zone nue ne rapporte rien, et la compétence de construction augmente en retour la réduction de la pièce ([[Armure par zone et constructions]]).

**Boucle vertueuse assumée** : finir ses chaînes avec son élément phare y verse une XP gonflée par le multiplicateur — le joueur *choisit* sa spécialisation par sa façon de jouer. Le **potentiel régule seul** l'emballement (l'élément le plus monté épuise son potentiel et ralentit, les éléments frais gardent le leur) : aucune règle anti-farm n'est nécessaire.

Parité totale avec les PNJ et compagnons qui progressent ([[Compagnons]]).

**Multi-cibles ([[Trous connus du combat]]) :** la jauge se remplit d'un segment par attaque, **l'XP, elle, se somme par cible**.

> [!success] Codé le 2026-08-26 — dans le prototype
> Chaque être porte `xp: {element, competence, type, construction}`. À chaque dégât appliqué : `min(dégâts, PV restants)` versé à l'élément dominant du coup, à la compétence (`combat_skill` de l'arme ; pour un noyau magique, `magie_<élément>` en attendant le mappage des domaines de [[Domaines de grimoires et manuels]] ; pour une action de créature, son id) et au type de dégâts ; la cible verse `dégâts évités` (bruts × zone − finaux) à la construction de la pièce touchée. L'**écran de fin** (client) affiche l'issue, la durée du combat en ticks (le critère « 60 à 200 ticks » se lit directement) et les quatre pistes, puis les remet à zéro : non persistée, comme prévu par la spec.

> [!success] Décidé et codé le 2026-08-30 — **l'XP gagnée s'affiche à chaque action**
> **Instruction du designer** : « j'aimerais que l'XP gagnée par le joueur soit affichée à chaque action ». Tout versement d'XP passe par `Simulation.gagner_xp` (combat, encaissement, construction, modules, mais aussi récolte, craft, lecture…) : il émet désormais `xp_gagnee(id, clé, xp)`. Le client **cumule** ce que le joueur reçoit sur une courte fenêtre (0,4 s — une action en produit plusieurs lignes : élément, compétence, type, modules) puis l'affiche **en texte flottant** au-dessus du joueur, une ligne par piste (« +3 Feu », « +3 Épée », « +3 tranchant », « +3 Étincelle »), qui monte et s'efface en 1,6 s, et **une ligne de journal** qui résume l'action (« XP : Feu +3 · Épée +3 · … »). Les clés se nomment par leur catalogue : `element_<x>` → l'élément, une compétence → son nom, un module → son nom, sinon la clé (« encaissement », une construction). **Décision** : rien n'est affiché pour les autres êtres (le journal serait illisible), et le cumul par fenêtre évite quatre flottants superposés par coup.

> [!success] Codé le 2026-09-01 — l'écran de fin se tait quand il n'a rien à dire (designer, point 13)
> Deux reproches, tous deux réglés. Il **restait en surimpression jusqu'au clic** : il s'efface désormais **seul** au bout de `fin_combat.secondes` (six par défaut), un clic ou une touche continuant de l'écarter tout de suite. Et il s'affichait **pour un combat où rien ne s'était passé** — une bête qui engage un dormeur puis se désengage donnait « victoire en 0 ticks », pistes vides : un combat de moins de `ticks_min` ticks, sans une once d'XP ni un niveau gagné, **ne produit plus d'écran du tout**.

## Liens
- **Dépend de** : [[Combat tactique sur grille]], [[Jauge de chaîne Wu Xing]], [[Potentiel]], [[Progression par l'usage]]
- **Alimente** : [[Armure par zone et constructions]], [[Double niveau combat et général]], [[Domination et multiplicateurs]]
- **Voir aussi** : [[Le vocabulaire des modules et l'absence d'arbre de talents]], [[Compagnons]], [[Trous connus du combat]], [[Pipeline de résolution du combat]], [[Décision — Multi-ennemis et jauge]]
