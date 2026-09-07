extends Node
## Tests headless du prototype (jalons 1-4) — des `assert`, aucun rendu.
##   & Godot --headless --path godot res://scenes/tests/test_combat.tscn --quit-after 2
## Chaque test cite la note qu'il vérifie.

var echecs := 0


## Un filtre pour n'exécuter qu'une partie de la suite (2026-09-01) : la suite entière dure ~7 min,
## ce qui rend impossible d'itérer sur un seul test. `--seul <fragment>` ne lance que les tests dont
## le nom contient le fragment ; sans argument, tout tourne comme avant.
var _filtre := ""


var _lances: Array[String] = []   # ce que la suite a lancé : un test défini mais absent de la liste est un échec (2026-09-04)


## Les fichiers de la suite (découpée le 2026-09-06 : `tools/fragmenter_tests.py`), chacun un domaine ; les tests y sont tels quels.
const MODULES: Array = [
	preload("res://scenes/tests/suite/tests_noyau.gd"),
	preload("res://scenes/tests/suite/tests_matieres.gd"),
	preload("res://scenes/tests/suite/tests_monde.gd"),
	preload("res://scenes/tests/suite/tests_villages.gd"),
	preload("res://scenes/tests/suite/tests_elevage.gd"),
	preload("res://scenes/tests/suite/tests_talents.gd"),
	preload("res://scenes/tests/suite/tests_equipement_et_terrain.gd"),
	preload("res://scenes/tests/suite/tests_ia_et_donnees.gd"),
	preload("res://scenes/tests/suite/tests_grilles_de_sorts.gd"),
	preload("res://scenes/tests/suite/tests_base_et_compagnons.gd"),
	preload("res://scenes/tests/suite/tests_donjon_et_progression.gd"),
	preload("res://scenes/tests/suite/tests_pnj_et_villes.gd"),
]
var _modules: Array = []


func _lancer(nom: String) -> void:
	_lances.append(nom)
	if not _filtre.is_empty() and not nom.contains(_filtre):
		return
	for m in _modules:
		if m.has_method(nom):
			m.call(nom)
			return
	verifier(false, "test introuvable dans la suite : %s" % nom)


## La liste ci-dessous est écrite à la main : quatre tests neufs et un ancien (test_brouillard) n'y figuraient pas, et
## « --seul » les cherchait dans la liste — il ne prouvait rien, la suite disait « tout passe » sans les jouer. Un test
## défini et jamais lancé compte désormais comme un échec.
func _verifier_tous_lances() -> void:
	for mod in _modules:
		for m in mod.get_method_list():
			var nom := str(m.name)
			if nom.begins_with("test_") and not (nom in _lances):
				verifier(false, "test défini mais jamais lancé : %s" % nom)


func _ready() -> void:
	# GameData a déjà chargé (autoload) : aucune erreur de schéma tolérée.
	TestsBase.lanceur = self
	for scr in MODULES:
		_modules.append(scr.new())
	Simulation.slot_autosave = "test_auto"   # l'autosave du retour d'expédition ne doit jamais écraser « monde » pendant la suite
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seul" and i + 1 < args.size():
			_filtre = str(args[i + 1])
	verifier(GameData.erreurs.is_empty(), "données valides (Décision — Pipeline de contenu)")
	_lancer("test_grille")
	_lancer("test_noyau_cpp")
	_lancer("test_regen_longue")
	_lancer("test_planches")
	_lancer("test_noyau_passes")
	_lancer("test_des")
	_lancer("test_regles")
	_lancer("test_simulation")
	_lancer("test_garde_et_lourde")
	_lancer("test_horloges")
	_lancer("test_wuxing")
	_lancer("test_ratelier")
	_lancer("test_capacites")
	_lancer("test_projectiles")
	_lancer("test_statuts")
	_lancer("test_liaisons")
	_lancer("test_glyphes_terrain")
	_lancer("test_evenements")
	_lancer("test_niveaux")
	_lancer("test_paperdoll_et_tutoriels")
	_lancer("test_materiaux")
	_lancer("test_recolte")
	_lancer("test_fabrication")
	_lancer("test_assemblage")
	_lancer("test_desequiper_jeter")
	_lancer("test_surface")
	_lancer("test_sauvegarde")
	_lancer("test_carte_et_voyage")
	_lancer("test_corruption")
	_lancer("test_cycle_et_meteo")
	_lancer("test_village")
	_lancer("test_village_vivant")
	_lancer("test_reputation_et_quetes")
	_lancer("test_rang_de_guilde")
	_lancer("test_compagnons")
	_lancer("test_territoire")
	_lancer("test_agriculture_et_boutique")
	_lancer("test_defense_et_raids")
	_lancer("test_royaumes_pnj")
	_lancer("test_conquete_et_succession")
	_lancer("test_alchimie")
	_lancer("test_villes_et_halls")
	_lancer("test_saisons_et_elevage")
	_lancer("test_elevage_familles")
	_lancer("test_loci_et_soie")
	_lancer("test_harmonie")
	_lancer("test_registre_elevage")
	_lancer("test_familles")
	_lancer("test_entraineur_et_commandes")
	_lancer("test_gabarits_guildes")
	_lancer("test_pretre_et_tourelle")
	_lancer("test_regle_anneau_mesure")
	_lancer("test_chatoyant")
	_lancer("test_routes")
	_lancer("test_habitat_pnj")
	_lancer("test_artefacts")
	_lancer("test_talents")
	_lancer("test_reforge_et_fiole")
	_lancer("test_communion")
	_lancer("test_lumiere")
	_lancer("test_palier_industriel")
	_lancer("test_betail")
	_lancer("test_ombre_et_rieur")
	_lancer("test_ecarlate_et_porteur")
	_lancer("test_passeur_et_sablier")
	_lancer("test_masque_et_sceau")
	_lancer("test_fossoyeur_et_engrenage")
	_lancer("test_propagation_lumiere")
	_lancer("test_aciers_allies")
	_lancer("test_vampire")
	_lancer("test_spectre")
	_lancer("test_lycanthrope")
	_lancer("test_incarnation")
	_lancer("test_terrasser")
	_lancer("test_empoigne")
	_lancer("test_armes_fantomes")
	_lancer("test_cataclysme")
	_lancer("test_vecteur_lieu")
	_lancer("test_effets_equipement")
	_lancer("test_palette_etage")
	_lancer("test_arme_mixte")
	_lancer("test_niveaux_recette")
	_lancer("test_plantes")
	_lancer("test_bestiaire")
	_lancer("test_statuts_complets")
	_lancer("test_potions_completes")
	_lancer("test_poison_illegal")
	_lancer("test_nage")
	_lancer("test_neige_et_gel")
	_lancer("test_automate_eau")
	_lancer("test_foudre")
	_lancer("test_retrait_eau")
	_lancer("test_compagnons_postures")
	_lancer("test_cueillette")
	_lancer("test_affixes_reveilles")
	_lancer("test_feu")
	_lancer("test_lave")
	_lancer("test_courant")
	_lancer("test_ia_portails")
	_lancer("test_paliers_elevage")
	_lancer("test_especes_ajoutees")
	_lancer("test_tannage")
	_lancer("test_huile_d_arme")
	_lancer("test_liens_donnees")
	_lancer("test_discretion")
	_lancer("test_embuscade")
	_lancer("test_triche")
	_lancer("test_statue")
	_lancer("test_routes_entre_royaumes")
	_lancer("test_tooltips")
	_lancer("test_registre_loci")
	_lancer("test_meubles_rituels")
	_lancer("test_suiveur_territorial")
	_lancer("test_transmutation")
	_lancer("test_arrachage")
	_lancer("test_glyphes_visibles")
	_lancer("test_derobade")
	_lancer("test_alternance")
	_lancer("test_meute_liaison")
	_lancer("test_etats_tuiles_par_grille")
	_lancer("test_index_monde")
	_lancer("test_sauvegarde_terrain")
	_lancer("test_uniques_artefacts")
	_lancer("test_bombes")
	_lancer("test_grille_sort")
	_lancer("test_element_module")
	_lancer("test_flottabilite")
	_lancer("test_grilles_possedees")
	_lancer("test_trames")
	_lancer("test_cran_de_puissance")
	_lancer("test_etapes")
	_lancer("test_lod_projection")
	_lancer("test_faune_rarefaction")
	_lancer("test_engager_et_migrants")
	_lancer("test_perimetres")
	_lancer("test_faim_des_residents")
	_lancer("test_escorte_en_donjon")
	_lancer("test_compagnon_se_bat")
	_lancer("test_compagnons_defendent")
	_lancer("test_dette_paliers")
	_lancer("test_classes_des_pnj")
	_lancer("test_composer_capacites")
	_lancer("test_charges_de_modules")
	_lancer("test_assemblage_sans_limite")
	_lancer("test_creation_de_sorts")
	_lancer("test_zones_au_sol")
	_lancer("test_conditions_et_modificateurs")
	_lancer("test_camp")
	_lancer("test_geographie")
	_lancer("test_faim_et_poids")
	_lancer("test_donjon")
	_lancer("test_donjon_temps_a_l_action")
	_lancer("test_portes_une_par_ouverture")
	_lancer("test_chaine_a_trois_etapes")
	_lancer("test_dilution_par_surface")
	_lancer("test_cuir_par_espece")
	_lancer("test_loot_varie")
	_lancer("test_chasse")
	_lancer("test_recuperation")
	_lancer("test_serments")
	_lancer("test_conditions_payantes")
	_lancer("test_familles_non_vides")
	_lancer("test_kit_de_depart")
	_lancer("test_parchemins")
	_lancer("test_portees_a_motif")
	_lancer("test_types_ennemis")
	_lancer("test_loot_assemble")
	_lancer("test_budgets")
	_lancer("test_sauvegarde_partout")
	_lancer("test_boss_et_artefact")
	_lancer("test_loot")
	_lancer("test_coffres_et_rares")
	_lancer("test_gemmes_et_livres")
	_lancer("test_progression")
	_lancer("test_expedition")
	_lancer("test_arenes_autonomes")
	_lancer("test_brouillard")
	_lancer("test_bete_engage_sur_son_horloge")
	_lancer("test_cri_de_ralliement")
	_lancer("test_routine_civile")
	_lancer("test_proie_n_engage_pas")
	_lancer("test_sprites_objets")
	_lancer("test_boutiques_vendent")
	_lancer("test_recruter_contre_or")
	_lancer("test_plafond_par_salle")
	_lancer("test_calendrier")
	_lancer("test_territoires")
	_lancer("test_villes")
	_lancer("test_champs_et_betes")
	_lancer("test_champs_saisons_et_troupeau")
	_lancer("test_plan_de_ville")
	_lancer("test_vocation_des_villes")
	_lancer("test_reperes_de_ville")
	_lancer("test_verger")
	_lancer("test_tombes_nommees")
	_lancer("test_majorite_quitte_le_lit")
	_lancer("test_sauvegarde_ville")
	_lancer("test_anneau_moyen")
	_lancer("test_population_villes")
	_lancer("test_lod_pnj")
	_lancer("test_economie")
	_lancer("test_transports")
	_lancer("test_pnj_distincts")
	_lancer("test_royaume_pays")
	_lancer("test_batiment_etages")
	_lancer("test_palette_village")
	_verifier_tous_lances()
	Monde.fermer_tous()   # aucun thread de pré-génération ne doit survivre aux autoloads
	for nom_s in ["test_terrain", "test_sensen", "test_sensen2", "test_graine", "test_partout", "test_partout2", "test_auto"]:
		Sauvegarde.effacer(nom_s)   # la suite nettoie derrière elle : l'écran Charger ne liste que de vraies parties
	if echecs == 0:
		print("TESTS : tout passe")
		get_tree().quit(0)
	else:
		printerr("TESTS : %d échec(s)" % echecs)
		get_tree().quit(1)


func verifier(cond: bool, nom: String) -> void:
	if cond:
		print("  ok   " + nom)
	else:
		echecs += 1
		printerr("  ÉCHEC " + nom)

