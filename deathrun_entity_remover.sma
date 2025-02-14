#include <amxmodx>
#include <fakemeta>

#define PLUGIN "Deathrun Entity Remover"
#define VERSION "1.0"
#define AUTHOR "ftl~"

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
}

public plugin_cfg() {
    new mapname[32];
    get_mapname(mapname, charsmax(mapname));

    if (equali(mapname, "deathrun", 8) || equali(mapname, "deathrace", 9)) {
        remove_entities();
    }
}

public remove_entities() {
    remove_specific_entity("func_door");
    remove_specific_entity("func_button");
    remove_specific_entity("func_door_rotating");
    remove_specific_entity("func_breakable");
}

public remove_specific_entity(const classname[]) {
    new ent = -1;

    while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", classname))) {
        if (pev_valid(ent)) {
            RemoveEntity(ent);
        }
    }
}

public RemoveEntity(ent) {
    set_pev(ent, pev_rendermode, kRenderTransAlpha);
    set_pev(ent, pev_renderamt, 0);
    set_pev(ent, pev_solid, SOLID_NOT);
}