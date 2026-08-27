---
aliases: ["Astrologie", "Cycle sexagésimal", "Signe", "Date de naissance", "Élément de naissance"]
tags: [progression, wuxing, décidé]
domaine: progression
statut: décidé
etape: 4
---

Le cycle sexagésimal chinois — un élément et un animal — donne une pente de progression et des compatibilités relationnelles. Jamais un plafond.

**Date de naissance choisie librement** (sélecteur avec aperçu des effets), qui détermine le **signe du cycle sexagésimal chinois** : un **élément** (cycle de 5 ans) et un **animal** (cycle de 12 ans) — **60 combinaisons**. Les PNJ ayant déjà un âge ([[Âge des PNJ]]), leur signe en **dérive gratuitement**.

**Élément de naissance** : +10 de potentiel de base dans les domaines liés :
- **Bois** → Foudre/Vie, Agriculture
- **Feu** → domaine Feu, Cuisine, Forge
- **Terre** → Terre, Minage, Construction
- **Métal** → Métal, Forge, façonnage
- **Eau** → Eau/Glace, Alchimie, Navigation

**Animal** : +10 de potentiel dans 2 compétences thématiques :
- Rat → Discrétion/Négociation
- Bœuf → Encaissement/Agriculture
- Tigre → Deux Mains/Athlétisme
- Lapin → Esquive/Herboristerie
- Dragon → Contrôle du Mana/Leadership
- Serpent → Alchimie/Perception
- Cheval → Athlétisme/Dressage
- Chèvre → Tissage/Taille de pierre
- Singe → Lecture/Dextérité fine
- Coq → Armes à distance/Perception
- Chien → Dressage/Encaissement
- Cochon → Cuisine/Négociation

**Compatibilités** : trines harmonieuses {Rat, Dragon, Singe} · {Bœuf, Serpent, Coq} · {Tigre, Cheval, Chien} · {Lapin, Chèvre, Cochon} ; oppositions à 6 ans d'écart. Multiplicateur sur la **vitesse** de gain de relation (×1.25 / ×0.8), jamais un seuil — **et applicable entre PNJ** : les mariages suivent statistiquement les trines, les rivalités les oppositions.

**Tout passe par le potentiel** ([[Potentiel]]), jamais par un bonus dur : la naissance donne une pente, pas un plafond.

**Second modificateur de vitesse de relation ([[Réputation et relations]]) :** les compatibilités astrologiques s'ajoutent aux réputations race/royaume comme modificateur de vitesse du gain de relation.

**Information visible ([[L'information comme récompense]]) :** le signe d'un PNJ se révèle au palier de relation 20-49.

> [!success] Codé le 2026-08-27
> `data/astrologie.json` : `signe(année) = {élément: année mod 5, animal: année mod 12}` ; +10 de potentiel de base sur les compétences listées par élément et par animal (le mapping de la note, `magie_<élément>` pour les domaines). Trines et oppositions sont en données ; leur multiplicateur de relation attend l'étape 9.

## Liens
- **Dépend de** : [[Création de personnage]], [[Identité visuelle chinoise]], [[Wu Xing — cycles et vecteurs]]
- **Alimente** : [[Potentiel]], [[Réputation et relations]], [[Âge des PNJ]], [[Familles et succession]]
- **Voir aussi** : [[Compétences — liste]], [[Domaines de grimoires et manuels]], [[L'information comme récompense]]
