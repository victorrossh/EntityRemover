#if defined _entity_remover_globals_included
	#endinput
#endif
#define _entity_remover_globals_included

#define DEBUG 0

// Path to save the configuration files
new const CONFIG_FOLDER[] = "addons/amxmodx/configs/entity_remover";
new const IGNORE_CFG[] = "addons/amxmodx/configs/ignored_entities.cfg";
new const PLASMA_SPRITE[] = "sprites/plasma.spr";
new g_plasma_sprite;
new Array:g_ignored_entities;

// Temporary array to store the map entities
new Array:g_map_entities;
new g_map_entity_count;

// Array to store the map name
new g_szMapName[32];

enum _:EntityData {
	ent_index,
	ent_solid,
	ent_rendermode,
	Float:ent_renderamt,
	ent_classname[32],
	ent_model[32]
};

enum _:EntityInfo {
	ei_classname[32],
	ei_count,
	Array:ei_indices,
	Array:ei_solid,
	Array:ei_rendermode,
	Array:ei_renderamt
};

new Array:g_map_entity_types; // Array of EntityInfo for unique classnames 
new g_map_entity_type_count;  // Count of unique types
new bool:g_remove_map_entities[4096];

new bool:g_noclip_enabled[33];

new Array:g_undo_stack[33];
new g_undo_size[33];
new Array:g_class;
new Array:g_model;
new g_total;
new Trie:g_removed_entities;

// MySQL settings
enum Settings {
	SQL_TYPE[32],
	SQL_HOST[32],
	SQL_USER[32],
	SQL_PASSWORD[32],
	SQL_DATABASE[32]
};

new g_eSettings[Settings];
new Handle:g_iSqlTuple;
new g_fwdDBLoaded;