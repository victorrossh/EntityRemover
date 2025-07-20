public mysql_init() {
	#if DEBUG
		log_amx("Attempting to create DbTuple with host: %s, user: %s, db: %s", g_eSettings[SQL_HOST], g_eSettings[SQL_USER], g_eSettings[SQL_DATABASE]);
	#endif
	g_iSqlTuple = SQL_MakeDbTuple(g_eSettings[SQL_HOST], g_eSettings[SQL_USER], g_eSettings[SQL_PASSWORD], g_eSettings[SQL_DATABASE]);
	if (g_iSqlTuple == Empty_Handle) {
		#if DEBUG
			log_amx("Failed to create DbTuple. Check SQL_HOST, SQL_USER, SQL_PASSWORD, and SQL_DATABASE in entity_remover.cfg.");
		#endif
		return;
	}
	SQL_SetAffinity("mysql");

	new iErrorCode, szSqlError[128], Handle:iSqlConnection = SQL_Connect(g_iSqlTuple, iErrorCode, szSqlError, charsmax(szSqlError));
	if (iSqlConnection == Empty_Handle) {
		#if DEBUG
			log_amx("Connection failed (%i): %s", iErrorCode, szSqlError);
		#endif
		g_iSqlTuple = Empty_Handle;
		return;
	} else {
		#if DEBUG
			log_amx("Connection successful.");
		#endif
		SQL_FreeHandle(iSqlConnection);
	}
}

public DB_LoadEntities()
{
	if (g_iSqlTuple == Empty_Handle) {
		#if DEBUG
			log_amx("Cannot load from database: Invalid SQL tuple handle. Check database connection.");
		#endif
	}
	
	new szQuery[128];
	formatex(szQuery, charsmax(szQuery), "SELECT classname, model FROM entity_remover_test WHERE map = '%s'", g_szMapName);
	SQL_ThreadQuery(g_iSqlTuple, "QueryLoadEntitiesHandler", szQuery);
}

public QueryLoadEntitiesHandler(iFailState, Handle:iQuery, szError[], iErrorCode) {
	if (iFailState) {
		#if defined DEBUG
			check_and_log_query_error(iFailState, szError, iErrorCode);
		#endif
		return;
	}

	new classname[32], model[64];
	while (SQL_MoreResults(iQuery)) {
		SQL_ReadResult(iQuery, 0, classname, sizeof(classname) - 1);
		SQL_ReadResult(iQuery, 1, model, sizeof(model) - 1);

		if(equali(model, ""))
		{
			new found = ArrayFindString(g_aMapClassnames, classname);
			if(found < 0)
			{
				#if DEBUG
				server_print("[DEBUG] Entity Classname %s NOT FOUND!", classname);
				#endif

				continue;
			}
			#if DEBUG
				server_print("[DEBUG] Deleting Classname %s!", classname);
			#endif
			DeleteClassname(found, false);
		}
		else
		{
			new entity_index = find_ent_by_model(0, classname, model);
			if(!entity_index)
			{
				#if DEBUG
				server_print("[DEBUG] Entity Classname %s | Model %s NOT FOUND!", classname, model);
				#endif
				continue;
			}
			#if DEBUG
				server_print("[DEBUG] Deleting Entity Classname %s | Model %s!", classname, model);
			#endif
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
		"INSERT IGNORE INTO entity_remover_test (map, classname, model) VALUES ('%s', '%s', '%s')", g_szMapName, entity_classname, entity_info[eModelId]);
	
	SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);
}

public DB_RestoreEntity(entity_info[eEntityInfo])
{
	new entity_index = entity_info[eId];
	new entity_classname[32];
	pev(entity_index, pev_classname, entity_classname, sizeof(entity_classname) - 1);

	new szQuery[256];
	formatex(szQuery, sizeof(szQuery) - 1,
		"DELETE FROM entity_remover_test WHERE map='%s' AND classname='%s' AND model='%s';", g_szMapName, entity_classname, entity_info[eModelId]);
	
	SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);
}

public DB_DeleteClassname(classname_info[eClassnameInfo])
{
	new szQuery[256];
	formatex(szQuery, sizeof(szQuery) - 1,
		"INSERT IGNORE INTO entity_remover_test (map, classname, model) VALUES ('%s', '%s', '')", g_szMapName, classname_info[eClassname]);
	
	SQL_ThreadQuery(g_iSqlTuple, "QueryHandler", szQuery);
}

public DB_RestoreClassname(classname_info[eClassnameInfo])
{
	new szQuery[256];
	formatex(szQuery, sizeof(szQuery) - 1,
		"DELETE FROM entity_remover_test WHERE map='%s' AND classname='%s' AND model='';", g_szMapName, classname_info[eClassname]);
	
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