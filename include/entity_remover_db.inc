public mysql_init() {
	#if defined DEBUG
		log_amx("Attempting to create DbTuple with host: %s, user: %s, db: %s", g_eSettings[SQL_HOST], g_eSettings[SQL_USER], g_eSettings[SQL_DATABASE]);
	#endif
	g_iSqlTuple = SQL_MakeDbTuple(g_eSettings[SQL_HOST], g_eSettings[SQL_USER], g_eSettings[SQL_PASSWORD], g_eSettings[SQL_DATABASE]);
	if (g_iSqlTuple == Empty_Handle) {
		#if defined DEBUG
			log_amx("Failed to create DbTuple. Check SQL_HOST, SQL_USER, SQL_PASSWORD, and SQL_DATABASE in entity_remover.cfg.");
		#endif
		return;
	}
	SQL_SetAffinity("mysql");

	new iErrorCode, szSqlError[128], Handle:iSqlConnection = SQL_Connect(g_iSqlTuple, iErrorCode, szSqlError, charsmax(szSqlError));
	if (iSqlConnection == Empty_Handle) {
		#if defined DEBUG
			log_amx("Connection failed (%i): %s", iErrorCode, szSqlError);
		#endif
		g_iSqlTuple = Empty_Handle;
		return;
	} else {
		#if defined DEBUG
			log_amx("Connection successful.");
		#endif
		SQL_FreeHandle(iSqlConnection);
	}
}

public DB_LoadMapConfig() {
	if (g_iSqlTuple == Empty_Handle) {
		#if defined DEBUG
			log_amx("Cannot load from database: Invalid SQL tuple handle. Check database connection.");
		#endif
		static iReturn;
		ExecuteForward(g_fwdDBLoaded, iReturn);
		return;
	}

	new map[32];
	get_mapname(map, sizeof(map) - 1);
	
	new szQuery[128];
	formatex(szQuery, charsmax(szQuery), "SELECT classname, model, ent_id, is_global FROM entity_remover WHERE map = '%s'", map);
	SQL_ThreadQuery(g_iSqlTuple, "QueryLoadMapConfigHandler", szQuery);
}

public QueryLoadMapConfigHandler(iFailState, Handle:iQuery, szError[], iErrorCode) {
	if (iFailState) {
		#if defined DEBUG
			check_and_log_query_error(iFailState, szError, iErrorCode);
		#endif
		return;
	}

	new classname[32], model[64], ent_id, is_global;
	while (SQL_MoreResults(iQuery)) {
		SQL_ReadResult(iQuery, 0, classname, sizeof(classname) - 1);
		SQL_ReadResult(iQuery, 1, model, sizeof(model) - 1);
		ent_id = SQL_ReadResult(iQuery, 2);
		is_global = SQL_ReadResult(iQuery, 3);

		if (is_global) {
			for (new i = 0; i < g_map_entity_type_count; i++) {
				new ent_info[EntityInfo];
				ArrayGetArray(g_map_entity_types, i, ent_info);
				if (equali(classname, ent_info[ei_classname])) {
					g_remove_map_entities[i] = true;
					ApplyMapEntityToggle(i, true);
					break;
				}
			}
		} else {
			ArrayPushString(g_class, classname);
			ArrayPushString(g_model, model);
			g_total++;
			
			if (ent_id > 0) {
				TrieSetCell(g_removed_entities, fmt("%d", ent_id), 1);
				if (pev_valid(ent_id)) {
					RemoveEntity(ent_id);
				}
			} else {
				new ent = 0;
				new temp_model[32];
				while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", classname)) != 0) {
					if (pev_valid(ent)) {
						pev(ent, pev_model, temp_model, sizeof(temp_model) - 1);
						if (equali(temp_model, model)) {
							TrieSetCell(g_removed_entities, fmt("%d", ent), 1);
							RemoveEntity(ent);
							break;
						}
					}
				}
			}
		}
		SQL_NextRow(iQuery);
	}

	static iReturn;
	ExecuteForward(g_fwdDBLoaded, iReturn);
}

public DB_SaveMapConfig() {
	if (g_iSqlTuple == Empty_Handle) {
		#if defined DEBUG
			log_amx("Cannot save to database: Invalid SQL tuple handle. Check database connection.");
		#endif
		return;
	}

	new map[32];
	get_mapname(map, sizeof(map) - 1);
	
	new szQuery[128];
	formatex(szQuery, charsmax(szQuery), "DELETE FROM entity_remover WHERE map = '%s'", map);
	SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);

	for (new i = 0; i < g_map_entity_type_count; i++) {
		if (g_remove_map_entities[i]) {
			new ent_info[EntityInfo];
			ArrayGetArray(g_map_entity_types, i, ent_info);
			
			new escaped_classname[64];
			SQL_QuoteString(Empty_Handle, escaped_classname, sizeof(escaped_classname) - 1, ent_info[ei_classname]);
			
			formatex(szQuery, sizeof(szQuery) - 1,
				"INSERT INTO entity_remover (map, classname, model, ent_id, is_global) VALUES ('%s', '%s', 'GLOBAL', 0, 1)",
				map, escaped_classname);
			SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);
		}
	}
	
	for (new i = 0; i < g_total; i++) {
		new class[32], model[64];
		ArrayGetString(g_class, i, class, sizeof(class) - 1);
		ArrayGetString(g_model, i, model, sizeof(model) - 1);
		
		new ent_id = 0;
		if (containi(model, ".") != -1) {
			for (new j = 0; j < g_map_entity_type_count; j++) {
				new ent_info[EntityInfo];
				ArrayGetArray(g_map_entity_types, j, ent_info);
				if (equali(class, ent_info[ei_classname])) {
					for (new k = 0; k < ent_info[ei_count]; k++) {
						new temp_id = ArrayGetCell(ent_info[ei_indices], k);
						new temp_model[32];
						pev(temp_id, pev_model, temp_model, sizeof(temp_model) - 1);
						if (equali(model, temp_model) && TrieKeyExists(g_removed_entities, fmt("%d", temp_id))) {
							ent_id = temp_id;
							break;
						}
					}
					break;
				}
			}
		}
		
		new escaped_class[64], escaped_model[128];
		SQL_QuoteString(Empty_Handle, escaped_class, sizeof(escaped_class) - 1, class);
		SQL_QuoteString(Empty_Handle, escaped_model, sizeof(escaped_model) - 1, model);
		
		formatex(szQuery, sizeof(szQuery) - 1,
			"INSERT INTO entity_remover (map, classname, model, ent_id, is_global) VALUES ('%s', '%s', '%s', %d, 0)",
			map, escaped_class, escaped_model, ent_id);
		SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);
	}
}

public DB_SaveSpecificEntity(const class[], const model[], ent) {
	if (g_iSqlTuple == Empty_Handle) {
		#if defined DEBUG
			log_amx("Cannot save specific entity to database: Invalid SQL tuple handle. Check database connection.");
		#endif
		return;
	}

	new save_str[64];
	copy(save_str, sizeof(save_str) - 1, model);
	ArrayPushString(g_class, class);
	ArrayPushString(g_model, save_str);
	g_total++;
	
	if (ent > 0 && pev_valid(ent)) {
		RemoveEntity(ent);
		TrieSetCell(g_removed_entities, fmt("%d", ent), 1);
	}

	new map[32];
	get_mapname(map, sizeof(map) - 1);
	
	new escaped_class[64], escaped_model[128];
	SQL_QuoteString(Empty_Handle, escaped_class, sizeof(escaped_class) - 1, class);
	SQL_QuoteString(Empty_Handle, escaped_model, sizeof(escaped_model) - 1, model);
	
	new szQuery[256];
	formatex(szQuery, sizeof(szQuery) - 1,
		"INSERT INTO entity_remover (map, classname, model, ent_id, is_global) VALUES ('%s', '%s', '%s', %d, 0)",
		map, escaped_class, escaped_model, ent);
	
	SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);
}

public DB_RemoveSavedEntity(const model[], ent_id) {
	if (g_iSqlTuple == Empty_Handle) {
		#if defined DEBUG
			log_amx("Cannot remove entity from database: Invalid SQL tuple handle. Check database connection.");
		#endif
		return;
	}

	for (new i = 0; i < g_total; i++) {
		new saved_str[64];
		ArrayGetString(g_model, i, saved_str, sizeof(saved_str) - 1);
		
		if (equali(model, saved_str)) {
			ArrayDeleteItem(g_class, i);
			ArrayDeleteItem(g_model, i);
			g_total--;
			TrieDeleteKey(g_removed_entities, fmt("%d", ent_id));
			break;
		}
	}

	new map[32];
	get_mapname(map, sizeof(map) - 1);
	
	new escaped_model[128];
	SQL_QuoteString(Empty_Handle, escaped_model, sizeof(escaped_model) - 1, model);
	
	new szQuery[256];
	formatex(szQuery, sizeof(szQuery) - 1,
		"DELETE FROM entity_remover WHERE map = '%s' AND model = '%s' AND ent_id = %d AND is_global = 0",
		map, escaped_model, ent_id);
	
	SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);
}

public DB_ResetSettings(id) {
	if (g_iSqlTuple == Empty_Handle) {
		#if defined DEBUG
			log_amx("Cannot reset settings in database: Invalid SQL tuple handle. Check database connection.");
		#endif
		return;
	}

	for (new i = 0; i < g_map_entity_type_count; i++) {
		if (g_remove_map_entities[i]) {
			g_remove_map_entities[i] = false;
			ApplyMapEntityToggle(i, false);
		}
	}
	
	if (g_total > 0) {
		new ent = 0;
		new class[32], model[32];
		new max_entities = engfunc(EngFunc_NumberOfEntities);
		
		for (ent = 1; ent < max_entities; ent++) {
			if (pev_valid(ent)) {
				pev(ent, pev_classname, class, sizeof(class) - 1);
				pev(ent, pev_model, model, sizeof(model) - 1);
				
				if (TrieKeyExists(g_removed_entities, fmt("%d", ent))) {
					set_pev(ent, pev_rendermode, kRenderNormal);
					set_pev(ent, pev_renderamt, 255.0);
					set_pev(ent, pev_solid, SOLID_BSP);
				}
			}
		}
		
		ArrayClear(g_class);
		ArrayClear(g_model);
		g_total = 0;
	}
	TrieClear(g_removed_entities);
	
	new map[32];
	get_mapname(map, sizeof(map) - 1);
	
	new szQuery[128];
	formatex(szQuery, sizeof(szQuery) - 1,
		"DELETE FROM entity_remover WHERE map = '%s'",
		map);
	
	SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);
}

public QueryHandler(iFailState, Handle:iQuery, szError[], iErrorCode) {
	#if defined DEBUG
		check_and_log_query_error(iFailState, szError, iErrorCode);
	#endif
}

check_and_log_query_error(iFailState, const szError[], iErrorCode) {
	switch (iFailState) {
		case TQUERY_CONNECT_FAILED: log_amx("Connection failed (%i): %s", iErrorCode, szError);
		case TQUERY_QUERY_FAILED: log_amx("Query failed (%i): %s", iErrorCode, szError);
	}
}