#include <amxmodx>
#include <fakemeta>

public plugin_init() {
    register_plugin("Remove door entity", "1.0", "ftl~");
}

public plugin_cfg() {
    new mapname[32];
    get_mapname(mapname, charsmax(mapname));

    if (equali(mapname, "deathrun", 8) || equali(mapname, "deathrace", 9)) {
        remove_func_doors();
    }
}

public remove_func_doors() {
    new ent = -1;

    while ((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "func_door"))) {
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