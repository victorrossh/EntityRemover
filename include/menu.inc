public MainEntityMenu(id, level, cid) {
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	if (!is_user_alive(id)) {
		CC_SendMessage(id, "%L", id, "MUST_BE_ALIVE");
		return PLUGIN_HANDLED;
	}

	g_bNoclip[id] = bool:get_user_noclip(id);

	new szTitle[128];
	formatex(szTitle, charsmax(szTitle), "%L", id, "MENU_MAIN_TITLE");

	new menu = menu_create(szTitle, "MainMenuHandler");
	new szItem[64];

	formatex(szItem, charsmax(szItem), "%L", id, "MENU_OPTION_REMOVE_AIMED");
	menu_additem(menu, szItem, "1");

	formatex(szItem, charsmax(szItem), "%L", id, "MENU_OPTION_MAP_ENTITIES");
	menu_additem(menu, szItem, "2");

	formatex(szItem, charsmax(szItem), "%L", id, "MENU_OPTION_RESET_SETTINGS");
	menu_additem(menu, szItem, "3");

	formatex(szItem, sizeof(szItem) - 1, "\wNoclip %s", g_bNoclip[id]?"\y[ON]^n":"\r[OFF]^n");
	menu_additem(menu, szItem, "4");

	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public MainMenuHandler(id, menu, item) {
	if(!is_user_alive(id)) {
		CC_SendMessage(id, "%L", id, "MUST_BE_ALIVE");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if(item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	switch(item) {
		case 0: OpenAimMenu(id);
		case 1: ShowMapEntities(id);
		case 2: {
			ResetSettings();
		}
		case 3: ToggleNoclip(id);
	}
	return PLUGIN_HANDLED;
}

public OpenAimMenu(id) {
	new szTitle[128];
	formatex(szTitle, charsmax(szTitle), "%L", id, "MENU_AIM_TITLE");

	new menu = menu_create(szTitle, "AimMenuHandler");
	new szItem[64];

	formatex(szItem, charsmax(szItem), "%L", id, "MENU_OPTION_REMOVE");
	menu_additem(menu, szItem, "1");

	formatex(szItem, charsmax(szItem), "%L", id, "MENU_OPTION_UNDO");
	menu_additem(menu, szItem, "2");

	menu_display(id, menu, 0);
}

public AimMenuHandler(id, menu, item) {
	if (!is_user_alive(id)) {
		CC_SendMessage(id, "%L", id, "MUST_BE_ALIVE");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

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
			MainEntityMenu(id, 0, 0);
		}
	}
	return PLUGIN_HANDLED;
}

public OpenConfirmationMenu(id, ent, const class[]) {
	new szTitle[128];
	formatex(szTitle, charsmax(szTitle), "%L", id, "MENU_CONFIRM_TITLE", class);

	new menu = menu_create(szTitle, "ConfirmationMenuHandler");
	new szItem[64];

	formatex(szItem, charsmax(szItem), "%L", id, "MENU_OPTION_YES");
	menu_additem(menu, szItem, fmt("%d", ent));

	formatex(szItem, charsmax(szItem), "%L", id, "MENU_OPTION_NO");
	menu_additem(menu, szItem, "2");
	
	menu_display(id, menu, 0);
}

// Store entity data
public ConfirmationMenuHandler(id, menu, item) {
	if (!is_user_alive(id)) {
		CC_SendMessage(id, "%L", id, "MUST_BE_ALIVE");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if(item == 0) {

		new info[8], dummy;
		menu_item_getinfo(menu, item, dummy, info, sizeof(info) - 1, _, _, _);
		new ent = str_to_num(info);
		
		if(pev_valid(ent)) {
			DeleteEntity(ent);
			new class[32];
			pev(ent, pev_classname, class, 31);
			CC_SendMessage(id, "%L", id, "ENTITY_REMOVED", class);
		}
	}
	menu_destroy(menu);
	MainEntityMenu(id, 0, 0);
	return PLUGIN_HANDLED;
}

public ShowMapEntities(id) {
	new szTitle[128];
	formatex(szTitle, charsmax(szTitle), "%L", id, "MENU_MAP_TITLE");

	new menu = menu_create(szTitle, "map_entities_handler");
	new szItem[64];

	new size = ArraySize(g_aMapEntites);

	if (size > 0) {
		new classname_item[64];
		for (new i = 0; i < size; i++) {
			new classname_info[eClassnameInfo];
			ArrayGetArray(g_aMapEntites, i, classname_info);
			formatex(classname_item, sizeof(classname_item) - 1, "%s (%dx)", classname_info[eClassname], classname_info[eEntCount]);
			menu_additem(menu, classname_item, fmt("%d", i));
		}
	} else {
		formatex(szItem, charsmax(szItem), "%L", id, "MENU_NO_ENTITIES");
		menu_additem(menu, szItem, "");
	}

	menu_display(id, menu, 0);
}

public map_entities_handler(id, menu, item) {
	if (!is_user_alive(id)) {
		CC_SendMessage(id, "%L", id, "MUST_BE_ALIVE");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

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
	new classname_info[eClassnameInfo];
	ArrayGetArray(g_aMapEntites, type_index, classname_info);
	
	new szTitle[64];
	formatex(szTitle, charsmax(szTitle), "%L", id, "MENU_OPTIONS_TITLE", classname_info[eClassname]);
	new menu = menu_create(szTitle, "EntityOptionsHandler");

	new szItem[64], status[8];
	new bool:classname_removed = TrieKeyExists(g_tRemovedClassnames, classname_info[eClassname]);
	format(status, 7, classname_removed ? "\y[OFF]" : "\r[ON]");
	formatex(szItem, charsmax(szItem), "%L", id, "MENU_OPTION_TOGGLE", classname_info[eClassname], status);
	menu_additem(menu, szItem, fmt("%d", type_index*1000));
	
	// Uniques entities 
	new entity_info[eEntityInfo];
	new entity_index;

	new item_name[64];
	
	for (new i = 0; i < classname_info[eEntCount]; i++) {
		ArrayGetArray(classname_info[eEntities], i, entity_info);
		entity_index = entity_info[eId];
		if (pev_valid(entity_index)) {
			// IMPLEMENT THIS AGAIN
			//new bool:is_removed = g_remove_map_entities[type_index] || TrieKeyExists(g_removed_entities, fmt("%d", ent_id));
			new bool:is_removed = classname_removed | TrieKeyExists(g_tRemovedEntities, fmt("%d", entity_index));

			formatex(item_name, sizeof(item_name) - 1, is_removed ? "%L %L" : "%L", LANG_PLAYER, "MENU_OPTION_ENTITY", entity_index, LANG_PLAYER, "MENU_STATUS_REMOVED");
			menu_additem(menu, item_name, fmt("%d", type_index * 1000 + entity_index));
		}
	}

	menu_display(id, menu, 0);
}

public EntityOptionsHandler(id, menu, item) {
	if (!is_user_alive(id)) {
		CC_SendMessage(id, "%L", id, "MUST_BE_ALIVE");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(menu);
		ShowMapEntities(id);
		return PLUGIN_HANDLED;
	}

	new info[16], dummy;
	menu_item_getinfo(menu, item, dummy, info, sizeof(info) - 1, _, _, _);
	new type_index = str_to_num(info) / 1000;
	new entity_index = str_to_num(info) % 1000;

	if (item == 0) { // Toggle Remove All
		new classname_info[eClassnameInfo];
		ArrayGetArray(g_aMapEntites, type_index, classname_info);
		new bool:classname_removed = TrieKeyExists(g_tRemovedClassnames, classname_info[eClassname]);

		if(classname_removed)
			RestoreClassname(type_index);
		else
			DeleteClassname(type_index);

		OpenEntityOptionsMenu(id, type_index);
	} else if (item >= 1) { 
		if (pev_valid(entity_index)) {
			// Check if entity is already deleted using a trie
			new bool:is_deleted = TrieKeyExists(g_tRemovedEntities, fmt("%d", entity_index))
			if(is_deleted)
			{
				restoreEntity(entity_index);
			}
			else
			{
				DeleteEntity(entity_index);
			}

			OpenEntityOptionsMenu(id, type_index);
		} else {
			//CC_SendMessage(id, "Entity no longer valid.");
			CC_SendMessage(id, "%L", id, "ENTITY_INVALID");
			OpenEntityOptionsMenu(id, type_index);
		}
	}

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public ApplyMapEntityToggle(type_index, bool:remove) {
	/*
	new ent_info[eEntityInfo];
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
	*/
}

stock ToggleNoclip(id)
{
	if(!get_user_noclip(id))
		set_user_noclip(id, true);
	else
		set_user_noclip(id, false);
}