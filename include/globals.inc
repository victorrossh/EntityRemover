// Menu PREFIX
#define MENU_PREFIX "\r[FWO] \d-\w"

new const IGNORE_CFG[] = "addons/amxmodx/configs/ignored_entities.cfg";
new const PLASMA_SPRITE[] = "sprites/plasma.spr";
new g_iPlasmaSprite;

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

enum eRenderInfo
{
	eSolid,
	eRenderMode,
	Float:eRenderAmt
};

enum eEntityInfo
{
	eId,
	eModelId[64],
	eRender[eRenderInfo]
};

enum eClassnameInfo 
{
	eClassname[32],
	eEntCount,
	Array:eEntities,
};

enum eUndoAction
{
    UA_Remove,
    UA_Restore
};

enum eUndoTarget
{
    UT_Entity,
    UT_Classname
};

enum eUndoRecord
{
    eUndoAction:urAction,    // UndoAction
    eUndoTarget:urTarget,    // UndoTarget
    urValue        			// entity id or classname index
};

new Array:g_aUndoHistory;

new Array:g_aMapEntites;
new Array:g_aMapClassnames;
new Array:g_aDeletedEntites;
new Array:g_aIgnoredClassnames;

new Trie:g_tRemovedEntities;
new Trie:g_tRemovedClassnames;

new g_szMapName[32];

new bool:g_bNoclip[MAX_PLAYERS];
new g_iLastClassIndex[MAX_PLAYERS];

//Debug mode
new bool:g_bDebugMode;