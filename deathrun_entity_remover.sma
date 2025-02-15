#include <amxmodx>
#include <fakemeta>
#include <amxmisc>
#include <xs>

#define PLUGIN "Entity Remover"
#define VERSION "1.0"
#define AUTHOR "ftl~"

// Path to save the configuration files
new const CONFIG_FOLDER[] = "addons/amxmodx/configs/entity_remover";

// We can add more entities that we want to be removed
new const ENTITIES[][] = {
    "func_door",
    "func_button",
    "func_door_rotating",
    "func_breakable"
};

new bool:g_remove_entities[sizeof(ENTITIES)];

// Variables to handle the entity being targeted
new g_target_ent[33];
new g_target_class[33][32];

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_clcmd("say /remove", "OpenRemoveMenu");
    register_clcmd("say_team /remove", "OpenRemoveMenu");

    load_map_config();
}

public plugin_cfg() {
    remove_selected_entities();
}

public OpenRemoveMenu(id) {
    new menu = menu_create("\r[FWO] \d- \wEntity remove:", "RemoveMenuHandler");

    for (new i = 0; i < sizeof(ENTITIES); i++) {
        new item[64];
        formatex(item, charsmax(item), "%s [%s]", ENTITIES[i], g_remove_entities[i] ? "\yON" : "\rOFF");
        menu_additem(menu, item, "", 0);
    }

    menu_additem(menu, "Remove Targeted Entity", "", 0);
    menu_additem(menu, "Save", "", 0);
    menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);

    menu_display(id, menu, 0);
}

public RemoveMenuHandler(id, menu, item) {
    if (item == sizeof(ENTITIES)) {
        new ent = GetAimAtEnt(id);
        if (pev_valid(ent)) {
            pev(ent, pev_classname, g_target_class[id], charsmax(g_target_class[]));
            g_target_ent[id] = ent;
            OpenConfirmationMenu(id);
        } else {
            client_print_color(id, print_chat, "^4[FWO] ^1No entity found.");
        }
        menu_destroy(menu);
        return;
    }

    if (item == sizeof(ENTITIES) + 1) {
        save_map_config();
        menu_destroy(menu);
        client_print_color(id, print_chat, "^4[FWO] ^1Settings saved.");
        return;
    }

    g_remove_entities[item] = !g_remove_entities[item];

    OpenRemoveMenu(id);
    menu_destroy(menu);
}

public OpenConfirmationMenu(id) {
    new menu = menu_create("\r[FWO] \d- \wRemove Entity?", "ConfirmationMenuHandler");

    new title[128];
    formatex(title, charsmax(title), "\wRemove \y%s\w?", g_target_class[id]);
    menu_additem(menu, title, "1");

    menu_additem(menu, "\wYes", "2");
    menu_additem(menu, "\wNo", "3");

    menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
    menu_display(id, menu, 0);
}

public ConfirmationMenuHandler(id, menu, item) {
    if (item == 1) {
        if (pev_valid(g_target_ent[id])) {
            RemoveEntity(g_target_ent[id]);
            client_print_color(id, print_chat, "^4[FWO] ^1Entity removed: ^3%s", g_target_class[id]);
        } else {
            client_print_color(id, print_chat, "^4[FWO] ^1Invalid entity.");
        }
    }

    menu_destroy(menu);
}

public remove_selected_entities() {
    for (new i = 0; i < sizeof(ENTITIES); i++) {
        if (g_remove_entities[i]) {
            remove_specific_entity(ENTITIES[i]);
        }
    }
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

public load_map_config() {
    new mapname[32];
    get_mapname(mapname, charsmax(mapname));

    new filepath[256];
    formatex(filepath, charsmax(filepath), "%s/%s.cfg", CONFIG_FOLDER, mapname);

    if (!file_exists(filepath)) {
        // If the file is not found, all entities will be set as not removed
        for (new i = 0; i < sizeof(ENTITIES); i++) {
            g_remove_entities[i] = false;
        }
        return;
    }

    new file = fopen(filepath, "rt");
    if (!file) {
        return;
    }

    new line[64];
    while (fgets(file, line, charsmax(line))) {
        // Remove the entity from the .cfg file
        trim(line);

        // Checks if the line corresponds to an entity
        for (new i = 0; i < sizeof(ENTITIES); i++) {
            if (equali(line, ENTITIES[i])) {
                g_remove_entities[i] = true;
                break;
            }
        }
    }

    fclose(file);
}

public save_map_config() {
    new mapname[32];
    get_mapname(mapname, charsmax(mapname));

    new filepath[256];
    formatex(filepath, charsmax(filepath), "%s/%s.cfg", CONFIG_FOLDER, mapname);

    new file = fopen(filepath, "wt");
    if (!file) {
        return;
    }

    for (new i = 0; i < sizeof(ENTITIES); i++) {
        if (g_remove_entities[i]) {
            fputs(file, ENTITIES[i]);
            fputs(file, "^n");
        }
    }

    fclose(file);
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

    engfunc(EngFunc_TraceLine, start, dest, 0, id, 0);
    return get_tr2(0, TR_pHit);
}