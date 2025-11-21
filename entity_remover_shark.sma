#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta_util>
#include <sqlx>
#include <fun>
#include <cromchat2>

#define DEBUG 0

#include "include/globals.inc"
#include "include/db.inc"
#include "include/menu.inc"


public plugin_init()
{
	register_clcmd("say /remove", "MainEntityMenu", ADMIN_IMMUNITY);
	register_clcmd("say_team /remove", "MainEntityMenu", ADMIN_IMMUNITY);

	register_event("HLTV", "EventNewRound", "a", "1=0", "2=0");
}

public plugin_precache()
{
	get_mapname(g_szMapName, charsmax(g_szMapName));
	LOAD_SETTINGS();
	mysql_init();

	g_iPlasmaSprite = precache_model(PLASMA_SPRITE);
}

public plugin_cfg()
{
	register_dictionary("entity_remover_ftl.txt");

	//init arrays
	g_aMapClassnames = ArrayCreate(32);
	g_aMapEntites = ArrayCreate(eClassnameInfo);
	g_aDeletedEntites = ArrayCreate(eEntityInfo);
	g_aIgnoredClassnames = ArrayCreate(32);

	g_aUndoHistory = ArrayCreate(eUndoRecord);

	g_tRemovedEntities = TrieCreate();
	TrieClear(g_tRemovedEntities);

	g_tRemovedClassnames = TrieCreate();
	TrieClear(g_tRemovedClassnames);
	
	load_ignored_entities();

	ScanMapEntities();

#if DEBUG
	TEST_SCANMAP();
#endif

	DB_LoadEntities();
}

public plugin_end()
{
	ArrayDestroy(g_aIgnoredClassnames);
	ArrayDestroy(g_aDeletedEntites);
	ArrayDestroy(g_aMapEntites);
	ArrayDestroy(g_aMapClassnames);

	ArrayDestroy(g_aUndoHistory);

	TrieDestroy(g_tRemovedClassnames);
	TrieDestroy(g_tRemovedEntities);
}

public EventNewRound()
{
	new size = ArraySize(g_aDeletedEntites);
	new entity_info[eEntityInfo];
	new entity_index;
	for(new i;i<size;i++)
	{
		ArrayGetArray(g_aDeletedEntites, i, entity_info);
		entity_index = entity_info[eId];

		set_pev(entity_index, pev_rendermode, kRenderTransAlpha);
		set_pev(entity_index, pev_renderamt, 0.0);
		set_pev(entity_index, pev_solid, SOLID_NOT);
	}

	new classname[64];

	new TrieIter:trieIter = TrieIterCreate(g_tRemovedClassnames);

	while(!TrieIterEnded(trieIter))
	{
		TrieIterGetKey(trieIter, classname, charsmax(classname));
		new found = ArrayFindString(g_aMapClassnames, classname);
		DeleteClassname(found, false);

		TrieIterNext(trieIter);
	}
}

public LOAD_SETTINGS() {
	new szFilename[256];
	get_configsdir(szFilename, charsmax(szFilename));
	add(szFilename, charsmax(szFilename), "/entity_remover.cfg");
	new iFilePointer = fopen(szFilename, "rt");
	new szData[256], szKey[32], szValue[256];

	if (iFilePointer) {
		while (!feof(iFilePointer)) {
			fgets(iFilePointer, szData, charsmax(szData));
			trim(szData);

			switch (szData[0]) {
				case EOS, '#', ';': continue;
			}

			strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');
			trim(szKey); trim(szValue);

			if (equal(szKey, "SQL_TYPE")) {
				format(g_eSettings[SQL_TYPE], charsmax(g_eSettings[SQL_TYPE]), szValue);
			}
			if (equal(szKey, "SQL_HOST")) {
				format(g_eSettings[SQL_HOST], charsmax(g_eSettings[SQL_HOST]), szValue);
			}
			if (equal(szKey, "SQL_USER")) {
				format(g_eSettings[SQL_USER], charsmax(g_eSettings[SQL_USER]), szValue);
			}
			if (equal(szKey, "SQL_PASSWORD")) {
				format(g_eSettings[SQL_PASSWORD], charsmax(g_eSettings[SQL_PASSWORD]), szValue);
			}
			if (equal(szKey, "SQL_DATABASE")) {
				format(g_eSettings[SQL_DATABASE], charsmax(g_eSettings[SQL_DATABASE]), szValue);
			}
		}
		fclose(iFilePointer);
	}
}

public ScanMapEntities() 
{
	new entity = 0;
	new entity_classname[32];
	new max_entities = engfunc(EngFunc_NumberOfEntities);

	#if DEBUG
	server_print("NUMBER OF ENTITIES: %d", max_entities);
	#endif

	for (entity = 1; entity < max_entities; entity++) {
		if (!pev_valid(entity)) continue;
		pev(entity, pev_classname, entity_classname, sizeof(entity_classname) - 1);

		// Check if the entity should be ignored.
		if (equali(entity_classname, "player") || equali(entity_classname, "worldspawn") || !entity_classname[0] || // Empty string check
			ArrayFindString(g_aIgnoredClassnames, entity_classname) != -1) {
			continue;
		}

		new entity_info[eEntityInfo];
		new render_info[eRenderInfo]
			
		entity_info[eId] = entity;
		pev(entity, pev_model, entity_info[eModelId], 31);

		render_info[eSolid] = pev(entity, pev_solid);
		render_info[eRenderMode] = pev(entity, pev_rendermode);
		pev(entity, pev_renderamt, render_info[eRenderAmt]);

		entity_info[eRender] = render_info;
		
		new classname_info[eClassnameInfo];

		new found = ArrayFindString(g_aMapClassnames, entity_classname);

		if (found == -1) {
			// New classname
			classname_info[eEntCount] = 1;
			classname_info[eEntities] = ArrayCreate(eEntityInfo);
			copy(classname_info[eClassname], 31, entity_classname);

			ArrayPushArray(classname_info[eEntities], entity_info);
			ArrayPushArray(g_aMapEntites, classname_info);

			ArrayPushString(g_aMapClassnames, entity_classname);

		} else {
			// Existing classname
			ArrayGetArray(g_aMapEntites, found, classname_info);
			classname_info[eEntCount]++;

			ArrayPushArray(classname_info[eEntities], entity_info);

			ArraySetArray(g_aMapEntites, found, classname_info);
		}

	}
}

stock DeleteClassname(classname_index, update_database = true, add_to_undo = true)
{
	new classname_info[eClassnameInfo];
	ArrayGetArray(g_aMapEntites, classname_index, classname_info);
	
	new entity_info[eEntityInfo];

	new size = ArraySize(classname_info[eEntities]);
	for(new i;i<size;i++)
	{
		ArrayGetArray(classname_info[eEntities], i, entity_info);

		set_pev(entity_info[eId], pev_rendermode, kRenderTransAlpha);
		set_pev(entity_info[eId], pev_renderamt, 0.0);
		set_pev(entity_info[eId], pev_solid, SOLID_NOT);
	}
	
	if(update_database)
	{
		DB_DeleteClassname(classname_info);
	}

	if(add_to_undo)
	{
		new ur_temp[eUndoRecord];
		ur_temp[urAction] = UA_Remove;
		ur_temp[urTarget] = UT_Classname;
		ur_temp[urValue] = classname_index;

		ArrayPushArray(g_aUndoHistory, ur_temp);
	}

	TrieSetCell(g_tRemovedClassnames, classname_info[eClassname], 1);

	
}

stock RestoreClassname(classname_index, update_database = true, add_to_undo = true)
{
	new classname_info[eClassnameInfo];
	ArrayGetArray(g_aMapEntites, classname_index, classname_info);

	new entity_info[eEntityInfo];

	new size = ArraySize(classname_info[eEntities]);

	for(new i;i<size;i++)
	{
		ArrayGetArray(classname_info[eEntities], i, entity_info);

		if(TrieKeyExists(g_tRemovedEntities, fmt("%d", entity_info[eId])))
			continue;

		set_pev(entity_info[eId], pev_rendermode, entity_info[eRender][eRenderMode]);
		set_pev(entity_info[eId], pev_renderamt, entity_info[eRender][eRenderAmt]);
		set_pev(entity_info[eId], pev_solid, entity_info[eRender][eSolid]);
	}
	
	if(update_database)
	{
		DB_RestoreClassname(classname_info);
	}

	if(add_to_undo)
	{
		new ur_temp[eUndoRecord];
		ur_temp[urAction] = UA_Restore;
		ur_temp[urTarget] = UT_Classname;
		ur_temp[urValue] = classname_index;

		ArrayPushArray(g_aUndoHistory, ur_temp);
	}

	TrieDeleteKey(g_tRemovedClassnames, classname_info[eClassname]);
}

stock DeleteEntity(entity_index, update_database = true, add_to_undo = true)
{
	new entity_info[eEntityInfo];
	getEntityInfo(entity_index, entity_info);
	ArrayPushArray(g_aDeletedEntites, entity_info);

	set_pev(entity_index, pev_rendermode, kRenderTransAlpha);
	set_pev(entity_index, pev_renderamt, 0.0);
	set_pev(entity_index, pev_solid, SOLID_NOT);

	if(update_database)
	{
		DB_DeleteEntity(entity_info);
	}

	if(add_to_undo)
	{
		new ur_temp[eUndoRecord];
		ur_temp[urAction] = UA_Remove;
		ur_temp[urTarget] = UT_Entity;
		ur_temp[urValue] = entity_index;

		ArrayPushArray(g_aUndoHistory, ur_temp);
	}
		
	TrieSetCell(g_tRemovedEntities, fmt("%d", entity_index), 1);
}

stock RestoreEntity(entity_index, update_database = true, add_to_undo = true)
{
	new entity_info[eEntityInfo];
	new size = ArraySize(g_aDeletedEntites);

	new found = -1;
	for(new i;i<size;i++)
	{
		ArrayGetArray(g_aDeletedEntites, i, entity_info);
		if(entity_info[eId] == entity_index)
		{
			found = i;
			break;
		}
	}

	if(found < 0)
	{
		server_print("[DEBUG] Deleted entity cannot be found!");
		return;
	}

	ArrayDeleteItem(g_aDeletedEntites, found);

	set_pev(entity_index, pev_rendermode, entity_info[eRender][eRenderMode]);
	set_pev(entity_index, pev_renderamt, entity_info[eRender][eRenderAmt]);
	set_pev(entity_index, pev_solid, entity_info[eRender][eSolid]);


	if(update_database)
	{
		DB_RestoreEntity(entity_info);
	}

	if(add_to_undo)
	{
		new ur_temp[eUndoRecord];
		ur_temp[urAction] = UA_Restore;
		ur_temp[urTarget] = UT_Entity;
		ur_temp[urValue] = entity_index;

		ArrayPushArray(g_aUndoHistory, ur_temp);
	}
		
	TrieDeleteKey(g_tRemovedEntities,fmt("%d", entity_index));
}

stock ResetSettings()
{
	new size = ArraySize(g_aDeletedEntites);
	new entity_info[eEntityInfo];
	new entity_index;
	for(new i;i<size;i++)
	{
		ArrayGetArray(g_aDeletedEntites, i, entity_info);
		entity_index = entity_info[eId];

		set_pev(entity_index, pev_rendermode, entity_info[eRender][eRenderMode]);
		set_pev(entity_index, pev_renderamt, entity_info[eRender][eRenderAmt]);
		set_pev(entity_index, pev_solid, entity_info[eRender][eSolid]);
	}

	ArrayClear(g_aDeletedEntites);
	ArrayClear(g_aUndoHistory);
	TrieClear(g_tRemovedEntities);

	new classname[64];

	new TrieIter:trieIter = TrieIterCreate(g_tRemovedClassnames);

	new Array:aClassnames = ArrayCreate(32);

	while(!TrieIterEnded(trieIter))
	{
		TrieIterGetKey(trieIter, classname, charsmax(classname));
		
		ArrayPushString(aClassnames, classname);

		TrieIterNext(trieIter);
	}

	for(new i=0;i<ArraySize(aClassnames);i++)
	{
		ArrayGetString(aClassnames, i, classname, charsmax(classname));
		new found = ArrayFindString(g_aMapClassnames, classname);
		RestoreClassname(found, false);
	}
	DB_DeleteMap();
}

stock getEntityInfo(entity_index, entity_info[eEntityInfo])
{
	new entity_classname[32];
	pev(entity_index, pev_classname, entity_classname, charsmax(entity_classname));

	new render_info[eRenderInfo]
			
	entity_info[eId] = entity_index;
	pev(entity_index, pev_model, entity_info[eModelId], charsmax(entity_info[eModelId]));

	render_info[eSolid] = pev(entity_index, pev_solid);
	render_info[eRenderMode] = pev(entity_index, pev_rendermode);
	pev(entity_index, pev_renderamt, render_info[eRenderAmt]);

	entity_info[eRender] = render_info;
}

stock getEntityInfoFromArray(entity_index, entity_info[eEntityInfo])
{
	new classname[32];
	pev(entity_index, pev_classname, entity_classname, charsmax(entity_classname));

	new size = ArraySize(g_aMapEntites);

	new classname_info[eClassnameInfo];

	for(new i=0;i<size;i++)
	{
		ArrayGetArray(g_aMapEntites, i, classname_info);
		if(equali(classname_info[eClassname], classname) != -1)
			break;
	}
	size = ArraySize(classname_info[eEntities]);
	for(new i=0;i<size;i++)
	{
		ArrayGetArray(classname_info, i, entity_info);
		if(entity_info[eId] == entity_index)
			break;
	}
}

stock TEST_SCANMAP()
{
	new classname_info[eClassnameInfo];
	new entity_info[eEntityInfo];

	for(new i;i<ArraySize(g_aMapEntites);i++)
	{
		ArrayGetArray(g_aMapEntites, i, classname_info);
		server_print("%s - %d", classname_info[eClassname], classname_info[eEntCount]);

		for(new j;j<ArraySize(classname_info[eEntities]);j++)
		{
			ArrayGetArray(classname_info[eEntities], j, entity_info);
			server_print("%d - %s", entity_info[eId], entity_info[eModelId]);
		}
	}
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

public load_ignored_entities() {
	ArrayClear(g_aIgnoredClassnames);

	if (file_exists(IGNORE_CFG)) {
		new file = fopen(IGNORE_CFG, "rt");
		if (file) {
			new line[32];
			while (fgets(file, line, 31)) {
				trim(line);
				if (line[0] && !equali(line, "")) {
					ArrayPushString(g_aIgnoredClassnames, line);
				}
			}
			fclose(file);
		}
	}
}