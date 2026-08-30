---
aliases: ["G.3", "Annexe G.3", "Éclairage", "Lumière", "Transparence rendu"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!note] Adapté au pivot tactique
> Réécrit en propagation **2D sur la grille** ([[Risques majeurs]]). Le flood fill 3D d'origine est archivé (GDD source, historique git).

Propagation incrémentale de la lumière en 2D sur la grille, et un cycle jour/nuit qui ne coûte rien.

```
Propagation 0-15 par flood fill 2D INCRÉMENTAL sur les tuiles : les mises
à jour de lumière sont des deltas locaux (pose/destruction d'une tuile ou
d'une source), jamais un recalcul de chunk complet ; file dédiée, budget
par tick, en thread. Les murs (contenu de tuile) bloquent la propagation ;
la transparence (A.4.5 : transparence >= 50) la laisse passer.
Lumière du jour : les tuiles de surface sont éclairées par l'ambiante ;
les intérieurs (pièces détectées, E.5) et les donjons ne reçoivent que
les sources locales. Le cycle jour/nuit (E.21) module en SHADER (uniform
global), pas en re-propagation — changer l'heure ne coûte rien.
```

**Usages ([[Risques majeurs]]) :** visibilité nocturne, donjons, ambiance. La transparence devient un simple tri de rendu.

**Échelle de lumière ([[Application des stats de matériau]]) :** `niveau = luminosite / 100 × 15` (échelle 0-15). Un objet lumineux porté éclaire mais **augmente la détection par les ennemis** — malus de Discrétion.

**Détection modulée par la lumière ([[IA des créatures]]) :** le cône de vision est modulé par la lumière locale.

**Enjeu de construction ([[Cycle jour-nuit et sommeil]]) :** la nuit, seules les sources locales comptent — l'éclairage de la base devient un vrai enjeu.

> [!success] Codé le 2026-08-28 — la lumière locale, sans propagation
> Décision : pas de flood fill 0-15 pour l'instant — une **lumière locale** suffit aux trois usages. `Simulation.lumiere_a(pos)` = max des meubles lumineux à 3 tuiles (`luminosite × (1 − d/4)`) et de l'objet lumineux en main de l'occupant ; `lumiere_de(e)` = ce qu'un être porte. **Vision** : la nuit, `facteur = max(vision_nuit, lumière portée/100)` — une torche en main rend la vue. **Détection** (`voit_ia`) : la nuit au camp, une cible **non éclairée** n'est vue qu'à `portée × vision_nuit` ; une cible **éclairée** (torche, lanterne à côté) à `portée × (1 + lumière/100 × lumiere_detection)` — l'objet lumineux porté augmente la détection (malus de Discrétion de la note), y compris pour les témoins des infractions. Les halos du client existaient déjà ; la propagation en thread et le shader jour/nuit attendent.

> [!success] Codé le 2026-08-28 — la propagation 0-15 sur la grille
> `Simulation.carte_lumiere` (un octet par tuile, 0-15) : **flood fill 2D** depuis les sources — meubles lumineux (`niveau = luminosite / 100 × 15`) et objets lumineux en main des êtres vivants — avec **−1 par tuile** (distance de Tchebychev) ; les contenus `bloque_vue` **reçoivent la lumière mais ne la propagent pas**, sauf `transparence ≥ 50`. Décision : **pas d'incrémental ni de thread pour l'instant** — la carte est recalculée **paresseusement**, au plus une fois par tick de monde et seulement quand on la lit (`niveau_lumiere(pos)` / `lumiere_a(pos)`), sur 128 × 128 tuiles c'est négligeable ; le delta local viendra si le profil le réclame. `lumiere_a` (0-100, lu par la détection et la vision) devient `niveau × 100 / 15`, max avec la lumière portée par l'occupant. **Client** : en donjon, où l'ambiante n'entre pas, chaque tuile vue reçoit un **voile** d'opacité `0,8 × (1 − niveau / 15)` — le halo d'une torche est un vrai trou dans le noir ; au camp, le cycle reste porté par `CanvasModulate` (l'« uniform global » de la note) et les halos.

> [!success] Corrigé le 2026-08-28
> Le voile du donjon est dessiné sur une couche à mélange normal (`voiles`, z 139), pas sur la couche additive des halos (`lumieres`, z 140) où un noir n'assombrit rien. Vérifié par `capture.tscn -- --arene 3 --donjon`.

> [!success] Décidé et codé le 2026-08-30 — une lueur ambiante dans les étages ; le voile sous les êtres et sur toute la silhouette des blocs
> **Instruction du designer** (parcours de donjon) : « la ligne de vue est trop petite ; les sprites et les blocs devraient passer devant le fog ». Ce qui bornait la vue n'était pas la Perception (10 tuiles) mais le **voile du noir** : sans torche, la carte de lumière est à 0 partout et tout est voilé à 80 % dès la deuxième tuile. Désormais chaque tuile d'un étage part d'une **lueur ambiante** `combat_rules.eclairage.donjon_ambiante` (6 sur 15 → voile à 48 %), qu'un thème peut remplacer (`lumiere_ambiante` dans sa fiche : une crypte à 2, une ruine à ciel ouvert à 10) ; les sources s'y ajoutent comme avant, la torche reste un vrai trou de lumière, et la détection lit la même carte (une salle ambiante rend visible, cible et joueur). **Couches** : le voile, le brouillard de guerre et les halos passent **sous les êtres et les végétaux** (z −4/−2/−3 contre 1..4000 pour les êtres — jusqu'ici un être à faible profondeur d'écran passait sous le brouillard, z 150), et le voile d'un mur couvre **toute la silhouette du bloc** (dessus et faces) plutôt qu'un losange posé à ses pieds. Le HUD du monde passe au-dessus de tout (z 4090).

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Application des stats de matériau]], [[Risques majeurs]]
- **Alimente** : [[Cycle jour-nuit et sommeil]], [[IA des créatures]], [[Minimap et brouillard de guerre]]
- **Voir aussi** : [[Meubles]], [[Direction artistique]], [[Budgets de performance]], [[Détection de pièces]]
