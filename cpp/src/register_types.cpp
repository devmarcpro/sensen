// L'entrée de la GDExtension sensen_grille : une seule classe, SensenGrille (le noyau pur de calcul de la grille).
#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "sensen_grille.h"

using namespace godot;

static void initialiser_sensen(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(SensenGrille);
}

static void terminer_sensen(ModuleInitializationLevel p_level) {
}

extern "C" {
GDExtensionBool GDE_EXPORT sensen_grille_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialiser_sensen);
	init_obj.register_terminator(terminer_sensen);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
