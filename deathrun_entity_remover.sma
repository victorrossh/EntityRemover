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

// Stack to handle undo functionality
new Array:g_undo_stack[33];
new g_undo_size[33];

// Structure to store entity data for undo
enum _:EntityData {
    ent_index,
    Float:ent_origin[3],
    Float:ent_angles[3],
    ent_classname[32]
};

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_clcmd("say /remove", "MainEntityMenu", ADMIN_IMMUNITY);
    register_clcmd("say_team /remove", "MainEntityMenu", ADMIN_IMMUNITY);

    // Initialize undo stacks for each player
    for (new i = 1; i <= 32; i++) {
        g_undo_stack[i] = ArrayCreate(EntityData);
        g_undo_size[i] = 0;
    }

    load_map_config();
}

public plugin_cfg() {
    remove_selected_entities();
}

public MainEntityMenu(id, level, cid) {
    if (!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED;

    new menu = menu_create("\r[FWO] \d- \wEntity Menu:", "MainMenuHandler");

    menu_additem(menu, "\wRemove Aimed Entity", "1");
    menu_additem(menu, "\wRemove Specific Entities", "2");
    menu_additem(menu, "\wReset All Settings", "3");

    menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
    menu_display(id, menu, 0);

    return PLUGIN_HANDLED;
}

public MainMenuHandler(id, menu, item) {
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        return;
    }

    new data[6], name[64], access, callback;
    menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);

    switch (str_to_num(data)) {
        case 1: OpenAimMenu(id);
        case 2: OpenEntityMenu(id);
        case 3: ResetSettings(id);
    }

    menu_destroy(menu);
}

public OpenAimMenu(id) {
    new menu = menu_create("\r[FWO] \d- \wRemove Aimed Entity:", "AimMenuHandler");

    menu_additem(menu, "\wRemove", "1");
    menu_additem(menu, "\wUndo", "2");

    menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
    menu_display(id, menu, 0);
}

public AimMenuHandler(id, menu, item) {
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        return;
    }

    new data[6], name[64], access, callback;
    menu_item_getinfo(menu, item, access, data, charsmax(data), name, charsmax(name), callback);

    switch (str_to_num(data)) {
        case 1: {
            new ent = GetAimAtEnt(id);
            if (pev_valid(ent)) {
                pev(ent, pev_classname, g_target_class[id], charsmax(g_target_class[]));
                g_target_ent[id] = ent;
                OpenConfirmationMenu(id);
            } else {
                client_print_color(id, print_chat, "^4[FWO] ^1No entity found.");
            }
        }
        case 2: {
            UndoLastRemoval(id);
        }
    }

    menu_destroy(menu);
}

public OpenConfirmationMenu(id) {
    new title[128];
    formatex(title, charsmax(title), "\r[FWO] \d- \wRemove Entity: \y%s?", g_target_class[id]);

    new menu = menu_create(title, "ConfirmationMenuHandler");

    menu_additem(menu, "\wYes", "1");
    menu_additem(menu, "\wNo", "2");

    menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
    menu_display(id, menu, 0);
}

public ConfirmationMenuHandler(id, menu, item) {
    if (item == 0) { // "Yes"
        if (pev_valid(g_target_ent[id])) {
            new ent_data[EntityData];
            ent_data[ent_index] = g_target_ent[id];
            pev(g_target_ent[id], pev_origin, ent_data[ent_origin]);
            pev(g_target_ent[id], pev_angles, ent_data[ent_angles]);
            copy(ent_data[ent_classname], charsmax(ent_data[ent_classname]), g_target_class[id]);

            RemoveEntity(g_target_ent[id]);
            client_print_color(id, print_chat, "^4[FWO] ^1Entity removed: ^3%s", g_target_class[id]);

            // Save the removed entity for undo
            ArrayPushArray(g_undo_stack[id], ent_data);
            g_undo_size[id]++;

            // Save the removed entity to the map config
            save_removed_entity(g_target_ent[id], g_target_class[id]);
        } else {
            client_print_color(id, print_chat, "^4[FWO] ^1Invalid entity.");
        }
    }

    menu_destroy(menu);
}

public UndoLastRemoval(id) {
    if (g_undo_size[id] > 0) {
        new ent_data[EntityData];
        ArrayGetArray(g_undo_stack[id], g_undo_size[id] - 1, ent_data);
        ArrayDeleteItem(g_undo_stack[id], g_undo_size[id] - 1);
        g_undo_size[id]--;

        new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, ent_data[ent_classname]));
        if (pev_valid(ent)) {
            set_pev(ent, pev_origin, ent_data[ent_origin]);
            set_pev(ent, pev_angles, ent_data[ent_angles]);
            set_pev(ent, pev_solid, SOLID_BSP);
            set_pev(ent, pev_movetype, MOVETYPE_PUSH);
            dllfunc(DLLFunc_Spawn, ent);

            client_print_color(id, print_chat, "^4[FWO] ^1Last removal undone: ^3%s", ent_data[ent_classname]);
        } else {
            client_print_color(id, print_chat, "^4[FWO] ^1Failed to restore entity.");
        }
    } else {
        client_print_color(id, print_chat, "^4[FWO] ^1No removals to undo.");
    }
}

public ResetSettings(id) {
    for (new i = 0; i < sizeof(ENTITIES); i++) {
        g_remove_entities[i] = false;
    }

    new mapname[32];
    get_mapname(mapname, charsmax(mapname));

    new filepath[256];
    formatex(filepath, charsmax(filepath), "%s/%s.txt", CONFIG_FOLDER, mapname);

    if (file_exists(filepath)) {
        delete_file(filepath);
    }

    client_print_color(id, print_chat, "^4[FWO] ^1All settings have been reset.");
}

public OpenEntityMenu(id) {
    new menu = menu_create("\r[FWO] \d- \wRemove Specific Entities:", "EntityMenuHandler");

    for (new i = 0; i < sizeof(ENTITIES); i++) {
        new item[64];
        formatex(item, charsmax(item), "%s [%s]%s", ENTITIES[i], g_remove_entities[i] ? "\yON" : "\rOFF", i == sizeof(ENTITIES) - 1 ? "^n" : "");
        menu_additem(menu, item, "", 0);
    }

    menu_additem(menu, "\wSave", "save");

    menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
    menu_display(id, menu, 0);
}

public EntityMenuHandler(id, menu, item) {
    if (item == sizeof(ENTITIES)) {
        // "Save" option
        save_map_config();
        menu_destroy(menu);
        client_print_color(id, print_chat, "^4[FWO] ^1Settings saved.");
        return;
    }

    g_remove_entities[item] = !g_remove_entities[item];

    OpenEntityMenu(id);
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
    formatex(filepath, charsmax(filepath), "%s/%s.txt", CONFIG_FOLDER, mapname);

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
        // Remove the entity from the .txt file
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
    formatex(filepath, charsmax(filepath), "%s/%s.txt", CONFIG_FOLDER, mapname);

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

public save_removed_entity(ent, const classname[]) {
    new mapname[32];
    get_mapname(mapname, charsmax(mapname));

    new filepath[256];
    formatex(filepath, charsmax(filepath), "%s/%s.txt", CONFIG_FOLDER, mapname);

    new file = fopen(filepath, "at");
    if (!file) {
        return;
    }

    // Save the entity with its index
    fprintf(file, "^"%s^" ^"*%d^"^n", classname, ent);

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
