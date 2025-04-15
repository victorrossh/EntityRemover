#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <xs>
#include <cromchat2>

#define PLUGIN "Entity Remover"
#define VERSION "2.0"
#define AUTHOR "ftl~"

// Path to save the configuration files
new const CONFIG_FOLDER[] = "addons/amxmodx/configs/entity_remover";
new const IGNORE_CFG[] = "addons/amxmodx/configs/ignored_entities.cfg";
new const PLASMA_SPRITE[] = "sprites/plasma.spr";
new g_plasma_sprite;
new Array:g_ignored_entities;

// Temporary array to store the map entities
new Array:g_map_entities;
new g_map_entity_count;

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

public plugin_precache() {
	register_forward(FM_Spawn, "FwdSpawn", 0);
	
	g_class = ArrayCreate(32, 1);
	g_model = ArrayCreate(32, 1);
	g_total = 0;

	// Initializes the temporary arrays
	g_map_entities = ArrayCreate(32, 1);
	g_map_entity_count = 0;
	g_map_entity_types = ArrayCreate(EntityInfo, 1);
	g_map_entity_type_count = 0;
	g_ignored_entities = ArrayCreate(32, 1);

	g_plasma_sprite = precache_model(PLASMA_SPRITE);
}

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("say /remove", "MainEntityMenu", ADMIN_IMMUNITY);
	register_clcmd("say_team /remove", "MainEntityMenu", ADMIN_IMMUNITY);

	register_event("HLTV", "EventNewRound", "a", "1=0", "2=0");
	register_logevent("EventNewRound", 2, "1=Round_Start");
	register_logevent("EventNewRound", 2, "1=Round_End");

	for(new i = 1; i <= 32; i++) {
		g_undo_stack[i] = ArrayCreate(EntityData, 1);
	}
	create_config_folder();
	load_ignored_entities();
	ScanMapEntities();
	load_map_config();

	//Chat prefix
	CC_SetPrefix("&x04[FWO]");
}

public plugin_cfg(){
	register_dictionary("entity_remover_ftl.txt");
}

public ScanMapEntities() {
	// Clear previous data
	ArrayClear(g_map_entities);
	ArrayClear(g_map_entity_types);
	g_map_entity_count = 0;
	g_map_entity_type_count = 0;

	// Scan all entities in the map
	new entity_index = 0;
	new entity_name[32];
	new max_entities = engfunc(EngFunc_NumberOfEntities);

	for (entity_index = 1; entity_index < max_entities; entity_index++) {
		if (pev_valid(entity_index)) {
			pev(entity_index, pev_classname, entity_name, sizeof(entity_name) - 1);

			// Check if the entity should be ignored.
			if (equali(entity_name, "player") || equali(entity_name, "worldspawn") || !entity_name[0] || // Empty string check
				ArrayFindString(g_ignored_entities, entity_name) != -1) {
				continue;
			}

			// Check if classname already exists
			new found = ArrayFindString(g_map_entity_types, entity_name);
			if (found == -1) {
				// New classname
				new ent_info[EntityInfo];
				copy(ent_info[ei_classname], 31, entity_name);
				ent_info[ei_count] = 1;
				ent_info[ei_indices] = ArrayCreate(1, 1);
				ent_info[ei_solid] = ArrayCreate(1, 1);
				ent_info[ei_rendermode] = ArrayCreate(1, 1);
				ent_info[ei_renderamt] = ArrayCreate(1, 1);
				
				ArrayPushCell(ent_info[ei_indices], entity_index);
				ArrayPushCell(ent_info[ei_solid], pev(entity_index, pev_solid));
				ArrayPushCell(ent_info[ei_rendermode], pev(entity_index, pev_rendermode));
				new Float:renderamt;
				pev(entity_index, pev_renderamt, renderamt);
				ArrayPushCell(ent_info[ei_renderamt], renderamt);
				
				ArrayPushArray(g_map_entity_types, ent_info);
				g_map_entity_type_count++;
			} else {
				// Existing classname, increment count
				new ent_info[EntityInfo];
				ArrayGetArray(g_map_entity_types, found, ent_info);
				ent_info[ei_count]++;
				ArrayPushCell(ent_info[ei_indices], entity_index);
				ArrayPushCell(ent_info[ei_solid], pev(entity_index, pev_solid));
				ArrayPushCell(ent_info[ei_rendermode], pev(entity_index, pev_rendermode));
				new Float:renderamt;
				pev(entity_index, pev_renderamt, renderamt);
				ArrayPushCell(ent_info[ei_renderamt], renderamt);
				ArraySetArray(g_map_entity_types, found, ent_info);
			}

			g_map_entity_count++;
		}
	}

	for (new i = 0; i < g_map_entity_type_count; i++) {
		if (g_remove_map_entities[i]) {
			ApplyMapEntityToggle(i, true);
		}
	}
}

public FwdSpawn(ent) {
	if(pev_valid(ent)) {
		set_task(0.1, "TaskDelayedCheck", ent);
	}
}

public TaskDelayedCheck(ent) {
	if(!pev_valid(ent)) return;
	
	new class[32], model[32];
	pev(ent, pev_classname, class, 31);
	pev(ent, pev_model, model, 31);
	
	// Check specific entities
	for(new i = 0; i < g_total; i++) {
		new saved_class[32], saved_model[32];
		ArrayGetString(g_class, i, saved_class, 31);
		ArrayGetString(g_model, i, saved_model, 31);
		
		if(equali(class, saved_class) && equali(model, saved_model)) {
			RemoveEntity(ent);
			return;
		}
	}
}

public MainEntityMenu(id, level, cid) {
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	new menu = menu_create("\r[FWO] \d- \wEntity Menu:", "MainMenuHandler");
	new item_text[64];

	menu_additem(menu, "\wRemove Aimed Entity", "1");
	menu_additem(menu, "\wMap Entities", "2");
	menu_additem(menu, "\wReset All Settings^n", "3");

	formatex(item_text, sizeof(item_text) - 1, "\wNoclip %s", g_noclip_enabled[id]?"\y[ON]^n":"\r[OFF]^n");
	menu_additem(menu, item_text, "4");

	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public MainMenuHandler(id, menu, item) {
	if(item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	switch(item) {
		case 0: OpenAimMenu(id);
		case 1: ShowMapEntities(id);
		case 2: ResetSettings(id);
		case 3: ToggleNoclip(id);
	}
	return PLUGIN_HANDLED;
}

public OpenAimMenu(id) {
	new menu = menu_create("\r[FWO] \d- \wRemove Aimed Entity:", "AimMenuHandler");

	menu_additem(menu, "\wRemove", "1");
	menu_additem(menu, "\wUndo", "2");

	menu_display(id, menu, 0);
}

public AimMenuHandler(id, menu, item) {
	if(item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	switch(item) {
		case 0: {
			new ent = GetAimAtEnt(id);
			if(pev_valid(ent)) {
				new class[32];
				pev(ent, pev_classname, class, 31);
			
				OpenConfirmationMenu(id, ent, class);
			}
			else {
				//client_print_color(id, print_chat, "^4[FWO] ^1No entity found.");
				CC_SendMessage(id, "%L", id, "NO_ENTITY");
				MainEntityMenu(id, 0, 0);
			}
		}
		case 1: {
			UndoLastRemoval(id);
			MainEntityMenu(id, 0, 0);
		}
	}
	return PLUGIN_HANDLED;
}

public OpenConfirmationMenu(id, ent, const class[]) {
	new title[128];
	formatex(title, charsmax(title), "\r[FWO] \d- \wRemove Entity: \y%s?", class);
	new menu = menu_create(title, "ConfirmationMenuHandler");

	menu_additem(menu, "\wYes", fmt("%d", ent));
	menu_additem(menu, "\wNo", "2");
	
	menu_display(id, menu, 0);
	
	
}

// Store entity data
	

public ConfirmationMenuHandler(id, menu, item) {
	if(item == 0) {

		new info[8], dummy;
		menu_item_getinfo(menu, item, dummy, info, sizeof(info) - 1, _, _, _);
		new ent = str_to_num(info);
		
		if(pev_valid(ent)) {
			new ent_data[EntityData];
			ent_data[ent_index] = ent;
			pev(ent, pev_solid, ent_data[ent_solid]);
			pev(ent, pev_rendermode, ent_data[ent_rendermode]);
			pev(ent, pev_renderamt, ent_data[ent_renderamt]);
			pev(ent, pev_classname, ent_data[ent_classname], 31);
			pev(ent, pev_model, ent_data[ent_model], 31);

			ArrayPushArray(g_undo_stack[id], ent_data);
			g_undo_size[id] = ArraySize(g_undo_stack[id]);

			RemoveEntity(ent);
			SaveSpecificEntity(ent_data[ent_classname], ent_data[ent_model]);
			//client_print_color(id, print_chat, "^4[FWO] ^1Entity removed: ^3%s", ent_data[ent_classname]);
			CC_SendMessage(id, "%L", id, "ENTITY_REMOVED", ent_data[ent_classname]);
		}
	}
	MainEntityMenu(id, 0, 0);
	return PLUGIN_HANDLED;
}

public UndoLastRemoval(id) {
	if(g_undo_size[id] > 0) {
		new ent_data[EntityData];
		ArrayGetArray(g_undo_stack[id], g_undo_size[id]-1, ent_data);
		ArrayDeleteItem(g_undo_stack[id], g_undo_size[id]-1);
		g_undo_size[id]--;
		
		if(pev_valid(ent_data[ent_index])) {
			set_pev(ent_data[ent_index], pev_solid, SOLID_BSP);
			set_pev(ent_data[ent_index], pev_rendermode, ent_data[ent_rendermode]);
			set_pev(ent_data[ent_index], pev_renderamt, ent_data[ent_renderamt]);
			
			RemoveSavedEntity(ent_data[ent_model]);
			//client_print_color(id, print_chat, "^4[FWO] ^1Last removal undone: ^3%s", ent_data[ent_classname]);
			CC_SendMessage(id, "%L", id, "LAST_REMOVAL_UNDONE", ent_data[ent_classname]);
		}
	}
	else {
		//client_print_color(id, print_chat, "^4[FWO] ^1No removals to undo.");
		CC_SendMessage(id, "%L", id, "NO_REMOVALS");
	}
	MainEntityMenu(id, 0, 0);
	return PLUGIN_HANDLED;
}

public ShowMapEntities(id) {
	new menu = menu_create("\r[FWO] \d- \wMap Entities:", "map_entities_handler");

	if (g_map_entity_type_count > 0) {
		new entity_item[64];
		for (new i = 0; i < g_map_entity_type_count; i++) {
			new ent_info[EntityInfo];
			ArrayGetArray(g_map_entity_types, i, ent_info);
			formatex(entity_item, sizeof(entity_item) - 1, "%s (%dx)", ent_info[ei_classname], ent_info[ei_count]);
			menu_additem(menu, entity_item, fmt("%d", i));
		}
	} else {
		menu_additem(menu, "No entities found", "");
	}

	menu_display(id, menu, 0);
}

public map_entities_handler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new info[8], dummy;
	menu_item_getinfo(menu, item, dummy, info, sizeof(info) - 1, _, _, _);
	new type_index = str_to_num(info);

	OpenEntityOptionsMenu(id, type_index);

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public OpenEntityOptionsMenu(id, type_index) {
	new ent_info[EntityInfo];
	ArrayGetArray(g_map_entity_types, type_index, ent_info);
	
	new menu_title[64];
	formatex(menu_title, sizeof(menu_title) - 1, "\r[FWO] \d- \w%s Options:", ent_info[ei_classname]);
	new menu = menu_create(menu_title, "EntityOptionsHandler");

	new item[64], status[8];
	format(status, 7, g_remove_map_entities[type_index] ? "\y[ON]" : "\r[OFF]");
	formatex(item, sizeof(item) - 1, "%s %s", ent_info[ei_classname], status);
	menu_additem(menu, item, fmt("%d", type_index));
	
	// Uniques entities 
	for (new i = 0; i < ent_info[ei_count]; i++) {
		new item_name[32];
		formatex(item_name, sizeof(item_name) - 1, "Entity #%d", i + 1);
		//menu_additem(menu, item_name, fmt("%d %d", type_index, ArrayGetCell(ent_info[ei_indices], i)));
		menu_additem(menu, item_name, fmt("%d", type_index));
	}

	menu_display(id, menu, 0);
}

public EntityOptionsHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		ShowMapEntities(id);
		return PLUGIN_HANDLED;
	}

	new info[16], dummy;
	menu_item_getinfo(menu, item, dummy, info, sizeof(info) - 1, _, _, _);
	new type_index = str_to_num(info);

	if (item >= 0 && item < g_map_entity_type_count) {
		new ent_info[EntityInfo];
		ArrayGetArray(g_map_entity_types, type_index, ent_info);
		
		if (item == 0) { // Toggle Remove All
			g_remove_map_entities[type_index] = !g_remove_map_entities[type_index];
			ApplyMapEntityToggle(type_index, g_remove_map_entities[type_index]);
			new status[32];
			formatex(status, charsmax(status), "%L", id, g_remove_map_entities[type_index] ? "MSG_GLOBAL_REMOVED" : "MSG_GLOBAL_RESTORED");
			CC_SendMessage(id, "%L", id, "GLOBAL_ENTITY_TOGGLED", ent_info[ei_classname], status);
			save_map_config(); // Saves directly to the .txt
			OpenEntityOptionsMenu(id, type_index);
		} else if (item >= 1) { 
			new ent_array_index = item - 1;
			if (ent_array_index >= 0 && ent_array_index < ent_info[ei_count]) {
				new ent_id = ArrayGetCell(ent_info[ei_indices], ent_array_index);
				if (pev_valid(ent_id)) {
					TeleportPlayerToEnt(id, ent_id);
					CreateGuideLine(id, ent_id);
					OpenEntityOptionsMenu(id, 0);
					//CC_SendMessage(id, "Follow the plasma line to the entity.");
					CC_SendMessage(id, "%L", id, "FOLLOW_PLASMA");
				} else {
					//CC_SendMessage(id, "Entity no longer valid.");
					CC_SendMessage(id, "%L", id, "ENTITY_INVALID");
					OpenEntityOptionsMenu(id, type_index);
				}
			}
		}
	}

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public ApplyMapEntityToggle(type_index, bool:remove) {
	new ent_info[EntityInfo];
	ArrayGetArray(g_map_entity_types, type_index, ent_info);
	
	new ent = -1;
	new index = 0;
	while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", ent_info[ei_classname])) != 0) {
		if (pev_valid(ent)) {
			if (remove) {
				RemoveEntity(ent);
			} else {
				// Restore original properties (same transparency, etc.)
				new solid = ArrayGetCell(ent_info[ei_solid], index);
				new rendermode = ArrayGetCell(ent_info[ei_rendermode], index);
				new Float:renderamt = Float:ArrayGetCell(ent_info[ei_renderamt], index);
				
				set_pev(ent, pev_rendermode, rendermode);
				set_pev(ent, pev_renderamt, renderamt);
				set_pev(ent, pev_solid, solid); // Instead of using SOLID_BSP, we use the stored original value, avoiding becoming opaque
			}
			index++;
		}
	}
}

public SaveSpecificEntity(const class[], const model[]) {
	ArrayPushString(g_class, class);
	ArrayPushString(g_model, model);
	g_total++;
	
	new map[32];
	get_mapname(map, 31);
	
	new filepath[256];
	formatex(filepath, 255, "%s/%s.txt", CONFIG_FOLDER, map);
	
	new file = fopen(filepath, "at");
	if(file) {
		fprintf(file, "^"%s^" ^"%s^"^n", class, model);
		fclose(file);
	}
}

public RemoveSavedEntity(const model[]) {
	for(new i = 0; i < g_total; i++) {
		new saved_model[32];
		ArrayGetString(g_model, i, saved_model, 31);
		
		if(equali(model, saved_model)) {
			ArrayDeleteItem(g_class, i);
			ArrayDeleteItem(g_model, i);
			g_total--;
			save_map_config();
			break;
		}
	}
}

public ResetSettings(id) {
	// Reset global entities (menu 2)
	for(new i = 0; i < g_map_entity_type_count; i++) {
		if(g_remove_map_entities[i]) {
			g_remove_map_entities[i] = false;
			ApplyMapEntityToggle(i, false);
		}
	}
	
	// Reset specific entities (menu 1)
	if(g_total > 0) {
		new ent = 0;
		new class[32], model[32];
		new max_entities = engfunc(EngFunc_NumberOfEntities);
		
		// Scan all entities in the map
		for(ent = 1; ent < max_entities; ent++) {
			if(pev_valid(ent)) {
				pev(ent, pev_classname, class, 31);
				pev(ent, pev_model, model, 31);
				
				// Check if this entity matches any saved specific removal
				for(new i = 0; i < g_total; i++) {
					new saved_class[32], saved_model[32];
					ArrayGetString(g_class, i, saved_class, 31);
					ArrayGetString(g_model, i, saved_model, 31);
					
					if(equali(class, saved_class) && equali(model, saved_model)) {
						// Restore the entity
						set_pev(ent, pev_rendermode, kRenderNormal);
						set_pev(ent, pev_renderamt, 255.0);
						set_pev(ent, pev_solid, SOLID_BSP);
						break; // Move to next entity once matched
					}
				}
			}
		}
		
		// Clear specific entity arrays
		ArrayClear(g_class);
		ArrayClear(g_model);
		g_total = 0;
	}
	
	// Delete config file
	new map[32];
	get_mapname(map, 31);
	new filepath[256];
	formatex(filepath, 255, "%s/%s.txt", CONFIG_FOLDER, map);
	if(file_exists(filepath)) {
		delete_file(filepath);
	}

	//client_print_color(id, print_chat, "^4[FWO] ^1All settings have been reset.");
	CC_SendMessage(id, "%L", id, "ALL_SETTINGS_RESET");
	MainEntityMenu(id, 0, 0);
}

public RemoveEntity(ent) {
	set_pev(ent, pev_rendermode, kRenderTransAlpha);
	set_pev(ent, pev_renderamt, 0.0);
	set_pev(ent, pev_solid, SOLID_NOT);
}

public GetAimAtEnt(id) {
	static Float:start[3], Float:view_ofs[3], Float:dest[3];
	pev(id, pev_origin, start);
	pev(id, pev_view_ofs, view_ofs);
	xs_vec_add(start, view_ofs, start);
	
	pev(id, pev_v_angle, dest);
	engfunc(EngFunc_MakeVectors, dest);
	global_get(glb_v_forward, dest);
	
	xs_vec_mul_scalar(dest, 9999.0, dest);
	xs_vec_add(start, dest, dest);
	
	engfunc(EngFunc_TraceLine, start, dest, DONT_IGNORE_MONSTERS, id, 0);
	
	new ent = get_tr2(0, TR_pHit);
	if(pev_valid(ent)) {
		new class[32];
		pev(ent, pev_classname, class, 31);
		if(!equali(class, "player") && !equali(class, "worldspawn")) {
			return ent;
		}
	}
	return 0;
}


public ToggleNoclip(id) {
	g_noclip_enabled[id] = !g_noclip_enabled[id];
	
	set_pev(id, pev_movetype, g_noclip_enabled[id] ? MOVETYPE_NOCLIP : MOVETYPE_WALK);
	MainEntityMenu(id, ADMIN_IMMUNITY, 0);
}

public TeleportPlayerToEnt(id, ent_id)
{
	new const Float:dist_to_ent = 250.0;
	new Float:player_origin[3], Float:ent_origin[3];
	new Float:vec_dir[3];
	new Float:player_angles[3];
	pev(id, pev_origin, player_origin);
	get_brush_entity_origin(ent_id,  ent_origin);

	xs_vec_sub(ent_origin, player_origin, vec_dir);
	xs_vec_normalize(vec_dir, vec_dir);

	engfunc(EngFunc_VecToAngles, vec_dir, player_angles);

	xs_vec_neg(vec_dir, vec_dir);
	xs_vec_add_scaled(ent_origin, vec_dir, dist_to_ent, player_origin);
	
	set_pev(id, pev_origin, player_origin);
	SetUserAgl(id, player_angles);
}

stock SetUserAgl(id, Float:agl[3])
{
	entity_set_vector(id, EV_VEC_angles, agl);
	entity_set_int(id, EV_INT_fixangle, 1);
}

public CreateGuideLine(id, ent_id) {
	new Float:player_origin[3], Float:ent_origin[3];
	
	// Get the player's position
	pev(id, pev_origin, player_origin);
	player_origin[2] += 10.0; // Adjust the line to be created at the player's eye level
	
	// Get the entity's position
	get_brush_entity_origin(ent_id,  ent_origin);
	
	if (!g_noclip_enabled[id]) { 
		g_noclip_enabled[id] = true;
		set_pev(id, pev_movetype, MOVETYPE_NOCLIP);
		//CC_SendMessage(id, "Noclip &x06activated&x01, follow the plasma to visualize the desired entity.");
		CC_SendMessage(id, "%L", id, "NOCLIP_TO_PLASMA");
	}
	
	// Create the beam between segment_start and segment_end
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMPOINTS);                          // Temporary entity type: line between two points
	engfunc(EngFunc_WriteCoord, player_origin[0]);      // Origin X
	engfunc(EngFunc_WriteCoord, player_origin[1]);      // Origin Y
	engfunc(EngFunc_WriteCoord, player_origin[2]);      // Origin Z
	engfunc(EngFunc_WriteCoord, ent_origin[0]);        // Destination X
	engfunc(EngFunc_WriteCoord, ent_origin[1]);        // Destination Y
	engfunc(EngFunc_WriteCoord, ent_origin[2]);        // Destination Z
	write_short(g_plasma_sprite);                       // Precached sprite index
	write_byte(0);                                      // Frame start
	write_byte(0);                                      // Frame rate
	write_byte(200);                                    // Time the line remains active (set_task in frames), 20 seconds = 200
	write_byte(20);                                     // Line width
	write_byte(0);                                      // Noise
	write_byte(255);                                    // Color R (red)
	write_byte(0);                                      // Color G (green)
	write_byte(0);                                      // Color B (blue)
	write_byte(200);                                    // Brightness
	write_byte(0);                                      // Scroll speed
	message_end();
}

public EventNewRound() {
	// Reapplies the global removals from Menu 2 (GLOBAL ENTITIES) at the beginning of each round
	if (g_map_entity_type_count > 0) {
		for (new i = 0; i < g_map_entity_type_count; i++) {
			if (g_remove_map_entities[i]) {
				new ent_info[EntityInfo];
				ArrayGetArray(g_map_entity_types, i, ent_info);
				new ent = -1;
				while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", ent_info[ei_classname])) != 0) {
					if (pev_valid(ent)) {
						RemoveEntity(ent);
					}
				}
			}
		}
	}

	// Reapplies the specific removals from Menu 1(Aim Menu) at the beginning of each round
	if (g_total > 0) {
		new ent, model[32];
		new saved_class[32], saved_model[32];
		for (new i = 0; i < g_total; i++) {
			ArrayGetString(g_class, i, saved_class, 31);
			ArrayGetString(g_model, i, saved_model, 31);
			
			ent = 0;
			while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", saved_class)) != 0) {
				if (pev_valid(ent)) {
					pev(ent, pev_model, model, 31);
					if (equali(model, saved_model)) {
						RemoveEntity(ent);
						break;
					}
				}
			}
		}
	}
}

public create_config_folder() {
	mkdir(CONFIG_FOLDER);
}

public load_ignored_entities() {
	ArrayClear(g_ignored_entities);

	if (file_exists(IGNORE_CFG)) {
		new file = fopen(IGNORE_CFG, "rt");
		if (file) {
			new line[32];
			while (fgets(file, line, 31)) {
				trim(line);
				if (line[0] && !equali(line, "")) {
					ArrayPushString(g_ignored_entities, line);
				}
			}
			fclose(file);
		}
	}
}

public load_map_config() {
	new map[32];
	get_mapname(map, 31);
	
	new filepath[256];
	formatex(filepath, 255, "%s/%s.txt", CONFIG_FOLDER, map);
	
	if(file_exists(filepath)) {
		new file = fopen(filepath, "rt");
		if(file) {
			new line[128];
			while(fgets(file, line, 127)) {
				trim(line);
				
				if(contain(line, "^"") != -1) {
					new class[32], model[32];
					parse(line, class, 31, model, 31);
					replace(class, 31, "^"", "");
					replace(model, 31, "^"", "");
					
					if(equali(model, "GLOBAL")) {
						// Global entity (menu2)
						for (new i = 0; i < g_map_entity_type_count; i++) {
							new ent_info[EntityInfo];
							ArrayGetArray(g_map_entity_types, i, ent_info);
							if (equali(class, ent_info[ei_classname])) {
								g_remove_map_entities[i] = true;
								ApplyMapEntityToggle(i, true); // Apply immediately
								break;
							}
						}
					} else {
						// Specific entity
						ArrayPushString(g_class, class);
						ArrayPushString(g_model, model);
						g_total++;
					}
				}
			}
			fclose(file);
		}
	}
}

public save_map_config() {
	new map[32];
	get_mapname(map, 31);
	
	new filepath[256];
	formatex(filepath, 255, "%s/%s.txt", CONFIG_FOLDER, map);
	
	new file = fopen(filepath, "wt");
	if (file) {
		// Save map entities (menu 2)
		//We should use the "for" from menu 2 first, so all global entities are saved at the top of the .txt file
		for (new i = 0; i < g_map_entity_type_count; i++) {
			new ent_info[EntityInfo];
			ArrayGetArray(g_map_entity_types, i, ent_info);
			if (g_remove_map_entities[i]) {
				fprintf(file, "^"%s^" ^"GLOBAL^"^n", ent_info[ei_classname]);
			}
		}
		
		// Save specific entities (menu 1)
		for(new i = 0; i < g_total; i++) {
			new class[32], model[32];
			ArrayGetString(g_class, i, class, 31);
			ArrayGetString(g_model, i, model, 31);
			fprintf(file, "^"%s^" ^"%s^"^n", class, model);
		}
		
		fclose(file);
	}
}