public mysql_init() {
	if (g_bDebugMode)
		log_amx("[Entity DEBUG] Attempting to create DbTuple with host: %s, user: %s, db: %s", g_eSettings[SQL_HOST], g_eSettings[SQL_USER], g_eSettings[SQL_DATABASE]);

	g_iSqlTuple = SQL_MakeDbTuple(g_eSettings[SQL_HOST], g_eSettings[SQL_USER], g_eSettings[SQL_PASSWORD], g_eSettings[SQL_DATABASE]);
	if (g_iSqlTuple == Empty_Handle) {
		if (g_bDebugMode)
			log_amx("[Entity DEBUG] Failed to create DbTuple. Check SQL_HOST, SQL_USER, SQL_PASSWORD, and SQL_DATABASE in entity_remover.cfg.");
		return;
	}
	SQL_SetAffinity("mysql");

	new iErrorCode, szSqlError[128], Handle:iSqlConnection = SQL_Connect(g_iSqlTuple, iErrorCode, szSqlError, charsmax(szSqlError));
	if (iSqlConnection == Empty_Handle) {
		if (g_bDebugMode)
			log_amx("[Entity DEBUG] Connection failed (%i): %s", iErrorCode, szSqlError);
		g_iSqlTuple = Empty_Handle;
		return;
	} else {
		if (g_bDebugMode)
			log_amx("[Entity DEBUG] Connection successful.");
		SQL_FreeHandle(iSqlConnection);
	}
}

public DB_LoadEntities()
{
	if (g_iSqlTuple == Empty_Handle) {
		if (g_bDebugMode)
			log_amx("[Entity DEBUG] Cannot load from database: Invalid SQL tuple handle. Check database connection.");
		return;
	}
	
	new szQuery[128];
	formatex(szQuery, charsmax(szQuery), "SELECT classname, model FROM entity_remover WHERE map = '%s'", g_szMapName);
	SQL_ThreadQuery(g_iSqlTuple, "QueryLoadEntitiesHandler", szQuery);
}

public DB_DeleteMap()
{
	if (g_iSqlTuple == Empty_Handle) {
		if (g_bDebugMode)
			log_amx("[Entity DEBUG] Cannot delete from database: Invalid SQL tuple handle. Check database connection.");
		return;
	}

	new szQuery[128];
	formatex(szQuery, charsmax(szQuery), 
		"DELETE FROM entity_remover WHERE map = '%s'",
		g_szMapName
	);

	SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);
}

public QueryLoadEntitiesHandler(iFailState, Handle:iQuery, szError[], iErrorCode) {
	if (iFailState) {
		if (g_bDebugMode)
			check_and_log_query_error(iFailState, szError, iErrorCode);
		return;
	}

	new classname[32], model[64];
	while (SQL_MoreResults(iQuery)) {
		SQL_ReadResult(iQuery, 0, classname, sizeof(classname) - 1);
		SQL_ReadResult(iQuery, 1, model, sizeof(model) - 1);

		if (equali(model, ""))
		{
			new found = ArrayFindString(g_aMapClassnames, classname);
			if (found < 0)
			{
				if (g_bDebugMode)
					server_print("[Entity DEBUG] Entity Classname %s NOT FOUND!", classname);
				SQL_NextRow(iQuery);
				continue;
			}
			if (g_bDebugMode)
				server_print("[Entity DEBUG] Deleting Classname %s!", classname);
			DeleteClassname(found, false);
		}
		else
		{
			new entity_index = find_ent_by_model(0, classname, model);
			if (!entity_index)
			{
				if (g_bDebugMode)
					server_print("[Entity DEBUG] Entity Classname %s | Model %s NOT FOUND!", classname, model);
				SQL_NextRow(iQuery);
				continue;
			}
			if (g_bDebugMode)
				server_print("[Entity DEBUG] Deleting Entity Classname %s | Model %s!", classname, model);
			DeleteEntity(entity_index, false);
		}
		
		SQL_NextRow(iQuery);
	}
}

public DB_DeleteEntity(entity_info[eEntityInfo])
{
	new entity_index = entity_info[eId];
	new entity_classname[32];
	pev(entity_index, pev_classname, entity_classname, sizeof(entity_classname) - 1);

	new szQuery[256];
	formatex(szQuery, sizeof(szQuery) - 1,
		"INSERT IGNORE INTO entity_remover (map, classname, model) VALUES ('%s', '%s', '%s')", g_szMapName, entity_classname, entity_info[eModelId]);
	
	SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);
}

public DB_RestoreEntity(entity_info[eEntityInfo])
{
	new entity_index = entity_info[eId];
	new entity_classname[32];
	pev(entity_index, pev_classname, entity_classname, sizeof(entity_classname) - 1);

	new szQuery[256];
	formatex(szQuery, sizeof(szQuery) - 1,
		"DELETE FROM entity_remover WHERE map='%s' AND classname='%s' AND model='%s';", g_szMapName, entity_classname, entity_info[eModelId]);
	
	SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);
}

public DB_DeleteClassname(classname_info[eClassnameInfo])
{
	new szQuery[256];
	formatex(szQuery, sizeof(szQuery) - 1,
		"INSERT IGNORE INTO entity_remover (map, classname, model) VALUES ('%s', '%s', '')", g_szMapName, classname_info[eClassname]);
	
	SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);
}

public DB_RestoreClassname(classname_info[eClassnameInfo])
{
	new szQuery[256];
	formatex(szQuery, sizeof(szQuery) - 1,
		"DELETE FROM entity_remover WHERE map='%s' AND classname='%s' AND model='';", g_szMapName, classname_info[eClassname]);
	
	SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);
}

stock SaveDeletedEntity(entity_info[eEntityInfo])
{
	if (UsingTextStorage()) Text_AddEntity(entity_info);
	else DB_DeleteEntity(entity_info);
}

stock RemoveSavedEntity(entity_info[eEntityInfo])
{
	if (UsingTextStorage()) Text_RemoveEntity(entity_info);
	else DB_RestoreEntity(entity_info);
}

stock SaveDeletedClassname(classname_info[eClassnameInfo])
{
	if (UsingTextStorage()) Text_AddClassname(classname_info);
	else DB_DeleteClassname(classname_info);
}

stock RemoveSavedClassname(classname_info[eClassnameInfo])
{
	if (UsingTextStorage()) Text_RemoveClassname(classname_info);
	else DB_RestoreClassname(classname_info);
}

stock ClearSavedEntities()
{
	if (UsingTextStorage()) Text_ClearEntities();
	else DB_DeleteMap();
}

stock Text_GetPath()
{
	new directory[192];
	get_configsdir(directory, charsmax(directory));
	add(directory, charsmax(directory), "/entity_remover");
	mkdir(directory);
	format(g_szStoragePath, charsmax(g_szStoragePath), "%s/%s.txt", directory, g_szMapName);
}

stock Text_LoadEntities()
{
	Text_GetPath();
	new file = fopen(g_szStoragePath, "rt");
	if (!file) return;

	new line[192], classname[32], model[64], entity_id[12], global[4];
	while (!feof(file))
	{
		fgets(file, line, charsmax(line));
		trim(line);
		if (!line[0]) continue;
		parse(line, classname, charsmax(classname), model, charsmax(model), entity_id, charsmax(entity_id), global, charsmax(global));
		if (equal(model, "GLOBAL") || str_to_num(global))
		{
			new index = ArrayFindString(g_aMapClassnames, classname);
			if (index >= 0) DeleteClassname(index, false, false);
		}
		else
		{
			new index = find_ent_by_model(0, classname, model);
			if (pev_valid(index)) DeleteEntity(index, false, false);
		}
	}
	fclose(file);
}

stock Text_ReadLines(Array:lines)
{
	Text_GetPath();
	new file = fopen(g_szStoragePath, "rt"), line[192];
	if (!file) return;
	while (!feof(file))
	{
		fgets(file, line, charsmax(line));
		trim(line);
		if (line[0]) ArrayPushString(lines, line);
	}
	fclose(file);
}

stock Text_WriteLines(Array:lines)
{
	Text_GetPath();
	new file = fopen(g_szStoragePath, "wt"), line[192];
	for (new i = 0; i < ArraySize(lines); i++)
	{
		ArrayGetString(lines, i, line, charsmax(line));
		fprintf(file, "%s^n", line);
	}
	fclose(file);
}

stock Text_AddEntity(entity_info[eEntityInfo])
{
	new Array:lines = ArrayCreate(192), line[192], classname[32];
	Text_ReadLines(lines);
	pev(entity_info[eId], pev_classname, classname, charsmax(classname));
	formatex(line, charsmax(line), "%c%s%c %c%s%c", 34, classname, 34, 34, entity_info[eModelId], 34);
	if (ArrayFindString(lines, line) == -1) ArrayPushString(lines, line);
	Text_WriteLines(lines);
	ArrayDestroy(lines);
}

stock Text_AddClassname(classname_info[eClassnameInfo])
{
	new Array:lines = ArrayCreate(192), line[192];
	Text_ReadLines(lines);
	formatex(line, charsmax(line), "%c%s%c %cGLOBAL%c", 34, classname_info[eClassname], 34, 34, 34);
	if (ArrayFindString(lines, line) == -1) ArrayPushString(lines, line);
	Text_WriteLines(lines);
	ArrayDestroy(lines);
}

stock Text_RemoveEntity(entity_info[eEntityInfo])
{
	new classname[32];
	pev(entity_info[eId], pev_classname, classname, charsmax(classname));
	Text_Remove(false, classname, entity_info[eModelId]);
}
stock Text_RemoveClassname(classname_info[eClassnameInfo]) { Text_Remove(true, classname_info[eClassname], "GLOBAL"); }

stock Text_Remove(bool:is_global, const classname[], const target_model[])
{
	new Array:lines = ArrayCreate(192), Array:kept = ArrayCreate(192), line[192], saved_class[32], model[64], saved_id[12], global[4];
	Text_ReadLines(lines);
	for (new i = 0; i < ArraySize(lines); i++)
	{
		ArrayGetString(lines, i, line, charsmax(line));
		parse(line, saved_class, charsmax(saved_class), model, charsmax(model), saved_id, charsmax(saved_id), global, charsmax(global));
		if ((is_global && (str_to_num(global) || equal(model, "GLOBAL")) && equal(saved_class, classname)) || (!is_global && equal(saved_class, classname) && equal(model, target_model))) continue;
		ArrayPushString(kept, line);
	}
	Text_WriteLines(kept);
	ArrayDestroy(lines); ArrayDestroy(kept);
}

stock Text_ClearEntities()
{
	Text_GetPath();
	delete_file(g_szStoragePath);
}


public QueryHandler(iFailState, Handle:iQuery, szError[], iErrorCode) {
	if (g_bDebugMode)
		check_and_log_query_error(iFailState, szError, iErrorCode);
}

check_and_log_query_error(iFailState, const szError[], iErrorCode) {
	switch (iFailState) {
		case TQUERY_CONNECT_FAILED: log_amx("[Entity DEBUG] Connection failed (%i): %s", iErrorCode, szError);
		case TQUERY_QUERY_FAILED: log_amx("[Entity DEBUG] Query failed (%i): %s", iErrorCode, szError);
	}
}
