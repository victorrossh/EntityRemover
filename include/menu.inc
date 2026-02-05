public MainEntityMenu(id, level, cid) {
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	if (!is_user_alive(id)) {
		CC_SendMessage(id, "%L", id, "MUST_BE_ALIVE");
		return PLUGIN_HANDLED;
	}

	g_bNoclip[id] = bool:get_user_noclip(id);

	new szTitle[128];
	formatex(szTitle, charsmax(szTitle), "%L", id, "MENU_MAIN_TITLE", MENU_PREFIX);

	new menu = menu_create(szTitle, "MainMenuHandler");
	new szItem[64];

	formatex(szItem, charsmax(szItem), "%L", id, "MENU_OPTION_REMOVE_AIMED");
	menu_additem(menu, szItem, "1");

	formatex(szItem, charsmax(szItem), "%L", id, "MENU_OPTION_MAP_ENTITIES");
	menu_additem(menu, szItem, "2");

	formatex(szItem, charsmax(szItem), "%L", id, "MENU_OPTION_RESET_SETTINGS");
	menu_additem(menu, szItem, "3");

	formatex(szItem, charsmax(szItem), "%L", id, "MENU_OPTION_UNDO");
	menu_additem(menu, szItem, "4");

	formatex(szItem, sizeof(szItem) - 1, "\wNoclip %s", g_bNoclip[id]?"\y[ON]^n":"\r[OFF]^n");
	menu_additem(menu, szItem, "5");

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
		case 0: {
			new ent = GetAimAtEnt(id);
			if(pev_valid(ent)) {
				new class[32];
				pev(ent, pev_classname, class, 31);
			
				OpenConfirmationMenu(id, ent, class);
			}
		}
		case 1: ShowMapEntities(id);
		case 2: {
			ResetSettings();
		}
		case 3: UndoAction(id);
		case 4: ToggleNoclip(id);
	}
	return PLUGIN_HANDLED;
}

public UndoAction(id)
{
	if(!ArraySize(g_aUndoHistory))
	{
		MainEntityMenu(id, 0, 0);
		return;
	}

	new temp_ur[eUndoRecord];
	new last_item = ArraySize(g_aUndoHistory) - 1;

	ArrayGetArray(g_aUndoHistory, last_item, temp_ur);

	switch(temp_ur[urAction])
	{
		case UA_Remove:
		{
			switch(temp_ur[urTarget])
			{
				case UT_Entity:	RestoreEntity(temp_ur[urValue], true, false);
				case UT_Classname:	RestoreClassname(temp_ur[urValue], true, false);
			}
		}
		case UA_Restore:
		{
			switch(temp_ur[urTarget])
			{
				case UT_Entity:	DeleteEntity(temp_ur[urValue], true, false);
				case UT_Classname:	DeleteClassname(temp_ur[urValue], true, false);
			}
		}
	}

	ArrayDeleteItem(g_aUndoHistory, last_item);

	new message[128];
	GetUndoMessage(temp_ur, message, charsmax(message));

	CC_SendMessage(id, "%s", message);

	MainEntityMenu(id, 0, 0);
}

stock GetUndoMessage(const undoRecord[urAction], msg[], msgLen)
{
	new action_msg[32];
	new target_msg[32];
	new info[32];

	switch(undoRecord[urAction])
	{
		case UA_Remove: formatex(action_msg, charsmax(action_msg), "Restored");
		case UA_Restore: formatex(action_msg, charsmax(action_msg), "Removed");
	}

	switch(undoRecord[urTarget])
	{
		case UT_Entity: 
		{
			formatex(target_msg, charsmax(target_msg), "entity");
			new model[32];
			pev(undoRecord[urValue], pev_classname, info, charsmax(info));
			pev(undoRecord[urValue], pev_model, model, charsmax(model));
			formatex(info, charsmax(info), "%s %s", info, model);
		}
		case UT_Classname:
		{
			formatex(target_msg, charsmax(target_msg), "classname");
			new classname_info[eClassnameInfo];
			ArrayGetArray(g_aMapEntites, undoRecord[urValue], classname_info);
			formatex(info, charsmax(info), classname_info[eClassname]);
		}
	}

	formatex(msg, msgLen, "Undo: %s %s %s", action_msg, target_msg, info);

}

public OpenAimMenu(id) {
	new szTitle[128];
	formatex(szTitle, charsmax(szTitle), "%L", id, "MENU_AIM_TITLE", MENU_PREFIX);

	new menu = menu_create(szTitle, "AimMenuHandler");
	new szItem[64];

	formatex(szItem, charsmax(szItem), "%L", id, "MENU_OPTION_REMOVE");
	menu_additem(menu, szItem, "1");

	menu_display(id, menu, 0);
}

public OpenConfirmationMenu(id, ent, const class[]) {
	new szTitle[128];
	formatex(szTitle, charsmax(szTitle), "%L", id, "MENU_CONFIRM_TITLE", MENU_PREFIX, class);

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
	formatex(szTitle, charsmax(szTitle), "%L", id, "MENU_MAP_TITLE", MENU_PREFIX);

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
	
	g_iLastClassIndex[id] = type_index;

	OpenClassOptionsMenu(id, type_index);

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public OpenClassOptionsMenu(id, type_index) {
	new classname_info[eClassnameInfo];
	ArrayGetArray(g_aMapEntites, type_index, classname_info);
	
	new szTitle[64];
	formatex(szTitle, charsmax(szTitle), "%L", id, "MENU_OPTIONS_TITLE", MENU_PREFIX, classname_info[eClassname]);
	new menu = menu_create(szTitle, "ClassOptionsHandler");

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
			new bool:is_removed = classname_removed | TrieKeyExists(g_tRemovedEntities, fmt("%d", entity_index));

			formatex(item_name, sizeof(item_name) - 1, is_removed ? "%L %L" : "%L", LANG_PLAYER, "MENU_OPTION_ENTITY", entity_index, LANG_PLAYER, "MENU_STATUS_REMOVED");
			menu_additem(menu, item_name, fmt("%d", type_index * 1000 + entity_index));
		}
	}

	menu_display(id, menu, 0);
}

public ClassOptionsHandler(id, menu, item) {
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

		OpenClassOptionsMenu(id, type_index);
	} else if (item >= 1) { 
		if (pev_valid(entity_index)) {
			OpenEntityOptionsMenu(id, type_index * 1000 + entity_index);
		} else {
			//CC_SendMessage(id, "Entity no longer valid.");
			CC_SendMessage(id, "%L", id, "ENTITY_INVALID");
			OpenClassOptionsMenu(id, type_index);
		}
	}

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public OpenEntityOptionsMenu(id, info){
	new type_index = info / 1000;
	new entity_index = info % 1000;
	
	new classname_info[eClassnameInfo];
	ArrayGetArray(g_aMapEntites, type_index, classname_info);

	new szTitle[64];
	formatex(szTitle, charsmax(szTitle), "%L - Entity %d", id, "MENU_OPTIONS_TITLE", MENU_PREFIX, classname_info[eClassname], entity_index);
	new menu = menu_create(szTitle, "EntityOptionsHandler");

	new szItem[64];
	new bool:is_removed = TrieKeyExists(g_tRemovedEntities, fmt("%d", entity_index));

	formatex(szItem, charsmax(szItem), is_removed ? "Toggle %L" : "Toggle", LANG_PLAYER, "MENU_STATUS_REMOVED");
	menu_additem(menu, szItem, fmt("%d", type_index * 1000 + entity_index));

	menu_additem(menu, "Teleport", fmt("%d", type_index * 1000 + entity_index));

	//menu_additem(menu, "Highlight", fmt("%d", type_index * 1000 + entity_index));


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
		OpenClassOptionsMenu(id, g_iLastClassIndex[id]);
		return PLUGIN_HANDLED;
	}

	new info[16], dummy;
	menu_item_getinfo(menu, item, dummy, info, sizeof(info) - 1, _, _, _);
	new type_index = str_to_num(info) / 1000;
	new entity_index = str_to_num(info) % 1000;

	if(item == 0){
		// Check if entity is already deleted using a trie
		new bool:is_deleted = TrieKeyExists(g_tRemovedEntities, fmt("%d", entity_index))
		if(is_deleted)
		{
			RestoreEntity(entity_index);
		}
		else
		{
			DeleteEntity(entity_index);
		}
	}

	if(item == 1){
		TeleportPlayerToEnt(id, entity_index);
		CreateGuideLine(id, entity_index);
	}

	if(item == 2){
		//TODO Highlight
	}

	OpenEntityOptionsMenu(id, type_index * 1000 + entity_index);

	return PLUGIN_HANDLED;
}

stock ToggleNoclip(id)
{
	if(!get_user_noclip(id))
		set_user_noclip(id, true);
	else
		set_user_noclip(id, false);
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

public CreateGuideLine(id, ent_id) {
	new Float:player_origin[3], Float:ent_origin[3];
	
	// Get the player's position
	pev(id, pev_origin, player_origin);
	player_origin[2] += 10.0; // Adjust the line to be created at the player's eye level
	
	// Get the entity's position
	get_brush_entity_origin(ent_id,  ent_origin);
	
	if (!g_bNoclip[id]) { 
		g_bNoclip[id] = true;
		set_pev(id, pev_movetype, MOVETYPE_NOCLIP);
		//CC_SendMessage(id, "Noclip &x06activated&x01, follow the plasma to visualize the desired entity.");
		CC_SendMessage(id, "%L", id, "NOCLIP_TO_PLASMA");
	}
	
	// Create the beam between segment_start and segment_end
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMPOINTS);						  // Temporary entity type: line between two points
	engfunc(EngFunc_WriteCoord, player_origin[0]);	  // Origin X
	engfunc(EngFunc_WriteCoord, player_origin[1]);	  // Origin Y
	engfunc(EngFunc_WriteCoord, player_origin[2]);	  // Origin Z
	engfunc(EngFunc_WriteCoord, ent_origin[0]);		// Destination X
	engfunc(EngFunc_WriteCoord, ent_origin[1]);		// Destination Y
	engfunc(EngFunc_WriteCoord, ent_origin[2]);		// Destination Z
	write_short(g_iPlasmaSprite);					   // Precached sprite index
	write_byte(0);									  // Frame start
	write_byte(0);									  // Frame rate
	write_byte(200);									// Time the line remains active (set_task in frames), 20 seconds = 200
	write_byte(20);									 // Line width
	write_byte(0);									  // Noise
	write_byte(255);									// Color R (red)
	write_byte(0);									  // Color G (green)
	write_byte(0);									  // Color B (blue)
	write_byte(200);									// Brightness
	write_byte(0);									  // Scroll speed
	message_end();
}

stock SetUserAgl(id, Float:agl[3])
{
	entity_set_vector(id, EV_VEC_angles, agl);
	entity_set_int(id, EV_INT_fixangle, 1);
}