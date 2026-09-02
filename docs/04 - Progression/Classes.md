---
aliases: ["C.3", "Annexe C.3", "Classes", "Classes de départ", "Le Sabre", "Le Souffle", "La Braise", "La Trace", "La Balance", "Le Vent", "La Paume", "Le Creuset"]
tags: [progression, contenu, décidé]
domaine: progression
statut: décidé
etape: 4
---

> [!success] Renommées le 2026-08-26
> Les classes de départ passent de noms génériques (Guerrier, Mage, Artisan, Chasseur, Marchand, Vagabond) à des **noms français évocateurs**, cohérents avec [[Identité visuelle chinoise]] — *« ce qui distingue réellement Sensen, bien plus qu'une perspective »*. Chaque classe porte désormais un **talent** ([[Talents de classe]]).

Les 8 classes visibles : un kit **et un talent** qui définit une façon de jouer.

| Classe | Kit (stats + équipement + compétences de départ) | Talent |
|---|---|---|
| **Le Sabre** | +2 For/+1 End ; épée fer, bouclier bois ; niv. 5 en Épée, Bouclier | **Râtelier vivant** |
| **Le Souffle** | +2 Vol/+1 Per ; bâton, 1 grimoire simple ; niv. 5 en Magie, Méditation, 3 modules de base | **Communion des cinq** |
| **La Braise** | +2 Dex/+1 For ; outils complets qualité Correct ; niv. 5 en Forge et 1 métier au choix | **Main du métal** |
| **La Trace** | +2 Dex/+1 Per ; arc, 20 flèches ; niv. 5 en Arc, Dressage | **Meute** |
| **La Balance** | +2 Cha/+1 Per ; 500 or, étal portatif ; niv. 5 en Négociation, Lecture | **Œil du prix** |
| **La Paume** | +2 Vol/+1 Cha ; herbes et bandages, 1 grimoire de Vie ; niv. 5 en domaine Vie, Alchimie | **Souffle rendu** |
| **Le Creuset** | +2 Per/+1 Vol ; alambic portatif, 6 fioles ; niv. 5 en Alchimie, Herboristerie | **Fiole vive** |
| **Le Vent** | +1 partout ; rien ; +15 points de création en plus | **Sans maître** (aucun, mais peut en apprendre un) |

**Correspondance avec les anciens noms :** Guerrier → Le Sabre · Mage → Le Souffle · Artisan puis Forgeron → **La Braise** · Chasseur → La Trace · Marchand → La Balance · Vagabond → Le Vent.

**Ajoutées le 2026-08-26 :** **La Paume** (soigneur) comble le trou signalé — le design promettait que *« les builds de soutien ont un accès plein au système central »* ([[Jauge de chaîne Wu Xing]] : un soin en position finale résout à ×0.7) sans qu'aucune classe ne l'incarne. **Le Creuset** (alchimiste) donne un porteur à l'Alambic et aux potions.

> **Le renommage résout trois collisions de vocabulaire.** *Forgeron*, *Chasseur* et *Marchand* désignaient à la fois une classe, une créature ([[Créatures]]) et — pour les deux premiers — une fonction ([[Fonctions]]). Chaque mot ne désigne plus qu'une chose.

## Les onze classes cachées

Elles ne sont pas au menu de création : **elles s'apprennent d'un PNJ qui les porte** (relation ≥ 75, comme les recettes exotiques). Détail et talents : [[Talents de classe]].

**Le Passeur** (portails) · **Le Sablier** (tempo) · **Le Sceau** (glyphes) · **Le Masque** (postures) · **Le Porteur** (saisit et lance) · **L'Ombre** (dissimulation, pièges) · **L'Écarlate** (jauge de sang) · **Le Rieur** (dés) · **Le Fossoyeur** (relève les morts) · **La Mèche** (bombes) · **L'Engrenage** (tourelles).

**Les deux dernières sont technologiques**, et c'est pour ça qu'elles sont cachées : la technologie du monde se **retrouve** dans les ruines profondes, comme les recettes du [[Palier industriel]]. Un tourellier s'apprend au même endroit qu'un haut fourneau.

## Ce qui a changé, ce qui n'a pas changé

**Ce qui a changé :** la classe ne détermine plus *uniquement* le kit de départ — elle porte un **talent permanent** ([[Talents de classe]]).

**Ce qui n'a pas changé :** **aucun plafond, aucune pénalité** liés à la classe. *Le talent est un plancher, pas une cage* — tous les slots restent libres, le build émerge par-dessus.

**Ce qui a bougé de catalogue :** « artisan » n'est plus une classe mais une **fonction** ([[Fonctions]] : craft et vend ce qu'il craft) ; *ce* qu'un artisan produit dépend de sa classe.

**Potentiels de base ([[Potentiel]]) :** chaque race ([[Races]]) ET chaque classe définit ses potentiels de base par stat et par familles de compétences (champ `base_potentials`) — ex. Le Souffle : domaines de magie 120, armes lourdes 60. Les valeurs vivent dans `data/classes/` ([[Décision — Pipeline de contenu]]).

Race et classe **s'additionnent** : le plancher final est la moyenne des deux valeurs quand elles diffèrent (un Nain Souffle a 90 en Forge et 90 en magie — ni spécialiste ni nul). C'est ce qui rend les combinaisons mécaniquement distinctes.

**Équipement initial ([[Début de partie]]) :** kit de la classe, rien d'autre.

> [!success] Corrigé le 2026-08-29 — cinq classes cachées distribuaient des compétences qui n'existent pas
> Trouvé par `tools/audit_donnees.py` : les fiches des classes cachées, écrites à la main, donnaient des niveaux de départ dans **`arcanes`**, **`tir`**, **`artisanat`** et **`perception`** — quatre ids absents de `data/competences/` (les vrais sont `magie_arcane`, `arbalete`, `forge`…, et *perception* est une **stat**, pas une compétence). Les points partaient dans le vide : ni fiche, ni famille de potentiel, ni progression par l'usage. Corrigé au plus près du thème de chaque classe : **Le Passeur** magie de l'Espace + Athlétisme, **Le Sablier** magie Arcane + Esquive, **Le Sceau** Enchantement + Encaissement, **Le Fossoyeur** magie de la Corruption + Encaissement, **L'Engrenage** Arbalète + Forge. L'audit vérifie désormais que toute compétence citée par une classe existe.

> [!success] Codé le 2026-09-02 — les 57 capacités de départ relues une à une (designer, point 72)
> Quand la portée est devenue un module, les capacités des 19 classes l'ont reçu par **transcription mécanique** de l'ancienne portée implicite de leur forme. Or presque toutes les formes portaient à 5-6 tuiles : **les 57 capacités se sont donc retrouvées en `jet_long`**, sans exception. L'Écarlate — la classe de sang, d'épée et d'encaissement — lançait son Saignement à six tuiles, et payait cinq ticks pour ça.
> Chaque capacité porte maintenant la portée de **son style**, lue sur les compétences de départ de sa classe : `contact` pour celles qui vivent au corps à corps (L'Écarlate, L'Ombre, Le Sabre, Le Masque, Le Porteur, Le Rieur), `jet_court` pour les érudits et les alchimistes, `jet_long` pour les tireurs et les mages de feu, et `sur_soi` pour les formes qui **suivent le trajet du lanceur** (`chemin`) — elles n'avaient aucun sens ancrées sur une tuile lointaine. Une classe de mêlée gagne au passage les ticks qu'elle payait pour une portée dont elle n'avait pas l'usage.


## Liens
- **Dépend de** : [[Création de personnage]], [[Les trois axes — race, classe, fonction]]
- **Alimente** : [[Talents de classe]], [[Potentiel]], [[Début de partie]], [[Fonctions]]
- **Voir aussi** : [[Races]], [[Talents de race]], [[Compétences — liste]], [[Identité visuelle chinoise]], [[Créatures]]
