---
aliases: ["Actions des créatures", "creature_actions catalogue", "F.12"]
tags: [contenu, combat, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 0
---

> [!success] Rédigé le 2026-08-26
> Catalogue produit sur délégation — schéma et règles en [[Décision — Vocabulaire d'attaque des créatures]]. Valeurs de premier équilibrage, à ajuster au prototype.

Les actions du bestiaire — **24 actions** partagées par famille, deux règles qui économisent tout le reste.

## Deux règles structurantes

**1. Les humanoïdes armés n'ont PAS d'actions dédiées** : ils utilisent le **système d'attaque standard du joueur** — leur arme d'inventaire ([[Stats d'armes]]), la garde, l'attaque lourde, le tir ([[Décision — Projectiles]]). C'est la conséquence directe du schéma unifié ([[Schéma unifié créature-PNJ]]) : un bandit est un personnage. Seules les **élites** ont en plus 1-2 actions spéciales.

**2. Les casters humains** (Ermite) lancent des **modules du catalogue standard** ([[Modules]]) via un grimoire d'inventaire — zéro contenu dédié.

## Le catalogue (`data/creature_actions/`, 24 actions)

*Format : id — forme · portée · coût ticks — effet — élément. Télégraphe automatique si coût > 10 ticks. Dés : notation [[Pipeline de résolution du combat]].*

**Morsures et griffes (socle des bêtes) :**
| id | forme · portée · ticks | effet | élém. |
|---|---|---|---|
| `morsure` | cible_unique · 1 · 8 | 1d6 perforant | Bois |
| `morsure_puissante` | cible_unique · 1 · 12 | 2d6 perforant + Saignement | Bois |
| `morsure_venimeuse` | cible_unique · 1 · 10 | 1d4 perforant + Poison | Bois |
| `griffure` | cible_unique · 1 · 6 | 1d4 tranchant | Bois |
| `coup_de_patte` | cible_unique · 1 · 12 | 2d6 contondant + projection 1 tuile | Terre |

**Charges et coups (télégraphés) :**
| id | forme · portée · ticks | effet | élém. |
|---|---|---|---|
| `charge` | ligne · 3 · 14 | 2d6 contondant + projection 1d3 tuiles, se déplace au contact | Terre |
| `coup_de_defenses` | cible_unique · 1 · 10 | 1d8 perforant | Métal |
| `coup_de_tete` | cible_unique · 1 · 12 | 1d8 contondant + projection 1 (bonus +1 dé si plus haut que la cible) | Terre |
| `masse_ecrasante` | cible_unique · 1 · 16 | 2d8 contondant | Terre |
| `ruade` | cible_unique · 1 · 10 | 1d6 contondant + recul 1 tuile (l'animal fuit ensuite) | Terre |

**Meute et essaim :**
| id | forme · portée · ticks | effet | élém. |
|---|---|---|---|
| `harcelement_meute` | cible_unique · 1 · 8 | 1d4 perforant, **+1 dé si un allié de meute est adjacent à la cible** (condition `cible_adjacente_a_allie`) | Bois |
| `hurlement` | anneau · r3 · 12 | allies de meute : +10 % vitesse 30 ticks | Bois |
| `dard_essaim` | anneau · r1 · 8 | 1d4 perforant + Poison (léger) sur toutes les tuiles adjacentes | Bois |
| `nuee` | soi (aura r1) · continu | 1 dégât/10 ticks aux entités au contact + 10 % Infection | Eau |

**Embuscade et venin :**
| id | forme · portée · ticks | effet | élém. |
|---|---|---|---|
| `pique_venimeuse` | cible_unique · 1 · 10 | 1d4 perforant + Poison | Eau |
| `pinces` | cible_unique · 1 · 8 | 1d4 tranchant ×2 coups | Métal |
| `machoire_verrouillee` | cible_unique · 1 · 16 | 2d8 perforant + Enracinement 10 ticks | Eau |
| `embuscade` | *(passive)* | première attaque du combat : **+2 dés** si la créature n'était pas détectée ([[IA des créatures]]) | — |
| `bond` | déplacement 3 + cible_unique · 12 | saute (ignore 1 obstacle) puis 1d6 tranchant | Bois |

**Volants :**
| id | forme · portée · ticks | effet | élém. |
|---|---|---|---|
| `pique_plongeant` | ligne · 4 · 14 | 2d6 tranchant, ignore le dénivelé (vol) | Bois |
| `serres` | cible_unique · 1 · 8 | 1d6 tranchant | Métal |
| `becquetage` | cible_unique · 1 · 6 | 1d4 perforant | Métal |

**Élites (en plus du système standard) :**
| id | forme · portée · ticks | effet | élém. |
|---|---|---|---|
| `cri_de_ralliement` | anneau · r4 · 12 | alliés : +15 % dégâts 40 ticks | Feu |
| `enchainement` | cible_unique · 1 · 14 | deux attaques d'arme consécutives (chacune pose son segment) | *(arme)* |

## Affectations par race animale ([[Créatures]])

- **Loup / Loup blanc** : morsure, harcelement_meute, hurlement · **Sanglier** : coup_de_defenses, charge · **Cerf / Renard / Renne / Chameau** : morsure (renard), ruade · **Essaim d'abeilles** : dard_essaim · **Scorpion** : pique_venimeuse, pinces · **Vautour** : becquetage, pique_plongeant · **Ours brun / polaire** : griffure, morsure_puissante, coup_de_patte · **Morse** : masse_ecrasante, coup_de_defenses · **Crocodile** : morsure, machoire_verrouillee, embuscade · **Nuée de moustiques** : nuee · **Serpent venimeux** : morsure_venimeuse, embuscade · **Aigle** : serres, pique_plongeant · **Bouquetin** : coup_de_tete, ruade · **Lynx** : bond, griffure, embuscade
- **Humains** (villageois → roi, bandits, pillards…) : système standard (arme + garde + lourde + tir) · **Chef de bande** (élite) : + cri_de_ralliement, enchainement · **Ermite** : modules de grimoire ([[Modules]]) · **Garde / Pillard** : standard, profil IA dédié.

> [!success] Codé (vérifié le 2026-08-28)
> Les 24 actions du tableau sont dans `data/creature_actions/` et portées par les 19 races du bestiaire ; rien à ajouter.

## Liens
- **Dépend de** : [[Décision — Vocabulaire d'attaque des créatures]], [[Créatures]], [[Vocabulaire des modules — six axes]]
- **Alimente** : [[IA des créatures]], [[Prototype de combat — spécification]], [[Combat tactique sur grille]]
- **Voir aussi** : [[Statuts]], [[Décision — Chaîne côté ennemis]], [[Schéma unifié créature-PNJ]]
