#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <xs>
#include <cromchat2>

#define PLUGIN "Entity Remover"
#define VERSION "2.0"
#define AUTHOR "ftl~"

// Path to save the configuration files
new const CONFIG_FOLDER[] = "addons/amxmodx/configs/entity_remover";
new const IGNORE_CFG[] = "addons/amxmodx/configs/ignored_entities.cfg";
new const PLASMA_SPRITE[] = "sprites/plasma.spr";
new g_plasma_sprite;
new Array:g_ignored_entities;

// Temporary array to store the map entities
new Array:g_map_entities;
new g_map_entity_count;

// We can add more entities that we want to be removed
// Global Variable
new const ENTITIES[][] = {
    "func_door",
    "func_button",
    "func_door_rotating",
    "func_breakable",
    "cycler"
};

enum _:EntityData {
    ent_index,
    ent_solid,
    ent_rendermode,
    Float:ent_renderamt,
    ent_classname[32],
    ent_model[32]
};

enum _:EntityInfo {
    ei_classname[32],
    ei_count,
    Array:ei_indices
};

new Array:g_map_entity_types; // Array of EntityInfo for unique classnames 
new g_map_entity_type_count;  // Count of unique types
new bool:g_remove_map_entities[4096];

new bool:g_noclip_enabled[33]; 

new bool:g_remove_entities[sizeof(ENTITIES)];
new Array:g_undo_stack[33];
new g_undo_size[33];
new Array:g_class;
new Array:g_model;
new g_total;

public plugin_precache() {
    register_forward(FM_Spawn, "FwdSpawn", 0);
    
    g_class = ArrayCreate(32, 1);
    g_model = ArrayCreate(32, 1);
    g_total = 0;

    // Initializes the temporary arrays
    g_map_entities = ArrayCreate(32, 1);
    g_map_entity_count = 0;
    g_map_entity_types = ArrayCreate(EntityInfo, 1); // New array unique types
    g_map_entity_type_count = 0;
    g_ignored_entities = ArrayCreate(32, 1);

    g_plasma_sprite = precache_model(PLASMA_SPRITE);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_clcmd("say /remove", "MainEntityMenu", ADMIN_IMMUNITY);
    register_clcmd("say_team /remove", "MainEntityMenu", ADMIN_IMMUNITY);

    for(new i = 1; i <= 32; i++) {
        g_undo_stack[i] = ArrayCreate(EntityData, 1);
    }
    load_ignored_entities();
    ScanMapEntities();
    load_map_config();

    //Chat prefix
    CC_SetPrefix("&x04[FWO]");
}

public plugin_cfg(){
    register_dictionary("entity_remover_ftl.txt");
}

public ScanMapEntities() {
    // Clear previous data
    ArrayClear(g_map_entities);
    ArrayClear(g_map_entity_types);
    g_map_entity_count = 0;
    g_map_entity_type_count = 0;

    // Scan all entities in the map
    new entity_index = 0;
    new entity_name[32];
    new max_entities = engfunc(EngFunc_NumberOfEntities);

    for (entity_index = 1; entity_index < max_entities; entity_index++) {
        if (pev_valid(entity_index)) {
            pev(entity_index, pev_classname, entity_name, sizeof(entity_name) - 1);

            // Check if the entity should be ignored.
            if (equali(entity_name, "player") || equali(entity_name, "worldspawn") || !entity_name[0] || // Empty string check
                ArrayFindString(g_ignored_entities, entity_name) != -1) {
                continue; 
            }

            // Check if classname already exists
            new found = -1;
            for (new i = 0; i < g_map_entity_type_count; i++) {
                new ent_info[EntityInfo];
                ArrayGetArray(g_map_entity_types, i, ent_info);
                if (equali(ent_info[ei_classname], entity_name)) {
                    found = i;
                    break;
                }
            }

            if (found == -1) {
                // New classname
                new ent_info[EntityInfo];
                copy(ent_info[ei_classname], 31, entity_name);
                ent_info[ei_count] = 1;
                ent_info[ei_indices] = ArrayCreate(1, 1);
                ArrayPushCell(ent_info[ei_indices], entity_index);
                ArrayPushArray(g_map_entity_types, ent_info);
                g_map_entity_type_count++;
                found = g_map_entity_type_count - 1;
            } else {
                // Existing classname, increment count
                new ent_info[EntityInfo];
                ArrayGetArray(g_map_entity_types, found, ent_info);
                ent_info[ei_count]++;
                ArrayPushCell(ent_info[ei_indices], entity_index);
                ArraySetArray(g_map_entity_types, found, ent_info);
            }

            g_map_entity_count++;
        }
    }

    for (new i = 0; i < g_map_entity_type_count; i++) {
        if (g_remove_map_entities[i]) {
            ApplyMapEntityToggle(i, true);
        }
    }
}

public FwdSpawn(ent) {
    if(pev_valid(ent)) {
        set_task(0.1, "TaskDelayedCheck", ent);
    }
}

public TaskDelayedCheck(ent) {
    if(!pev_valid(ent)) return;
    
    new class[32], model[32];
    pev(ent, pev_classname, class, 31);
    pev(ent, pev_model, model, 31);
    
    // Check global entities
    for(new i = 0; i < sizeof(ENTITIES); i++) {
        if(g_remove_entities[i] && equali(class, ENTITIES[i])) {
            RemoveEntity(ent);
            return;
        }
    }
    
    // Check specific entities
    for(new i = 0; i < g_total; i++) {
        new saved_class[32], saved_model[32];
        ArrayGetString(g_class, i, saved_class, 31);
        ArrayGetString(g_model, i, saved_model, 31);
        
        if(equali(class, saved_class) && equali(model, saved_model)) {
            RemoveEntity(ent);
            return;
        }
    }
}

public MainEntityMenu(id, level, cid) {
    if (!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED;

    new menu = menu_create("\r[FWO] \d- \wEntity Menu:", "MainMenuHandler");
    new item_text[64];

    menu_additem(menu, "\wRemove Aimed Entity", "1");
    menu_additem(menu, "\wRemove Specific Entities", "2");
    menu_additem(menu, "\wMap Entities", "3");
    menu_additem(menu, "\wReset All Settings^n", "4");

    formatex(item_text, sizeof(item_text) - 1, "\wNoclip %s", g_noclip_enabled[id]?"\y[ON]^n":"\r[OFF]^n");
    menu_additem(menu, item_text, "5");

    menu_display(id, menu, 0);
    return PLUGIN_HANDLED;
}

public MainMenuHandler(id, menu, item) {
    if(item == MENU_EXIT) {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    switch(item) {
        case 0: OpenAimMenu(id);
        case 1: OpenEntityMenu(id);
        case 2: ShowMapEntities(id);
        case 3: ResetSettings(id);
        case 4: ToggleNoclip(id);
    }
    return PLUGIN_HANDLED;
}

public OpenAimMenu(id) {
    new menu = menu_create("\r[FWO] \d- \wRemove Aimed Entity:", "AimMenuHandler");

    menu_additem(menu, "\wRemove", "1");
    menu_additem(menu, "\wUndo", "2");

    menu_display(id, menu, 0);
}

public AimMenuHandler(id, menu, item) {
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
                
                new menu_title[128];
                formatex(menu_title, 127, "\r[FWO] \d- \wRemove Entity: \y%s?", class);
                OpenConfirmationMenu(id, ent, class);
            }
            else {
                //client_print_color(id, print_chat, "^4[FWO] ^1No entity found.");
                CC_SendMessage(id, "%L", id, "NO_ENTITY");
                MainEntityMenu(id, 0, 0);
            }
        }
        case 1: {
            UndoLastRemoval(id);
            MainEntityMenu(id, 0, 0);
        }
    }
    return PLUGIN_HANDLED;
}

public OpenConfirmationMenu(id, ent, const class[]) {
    new title[128];
    formatex(title, charsmax(title), "\r[FWO] \d- \wRemove Entity: \y%s?", class);
    new menu = menu_create(title, "ConfirmationMenuHandler");

    menu_additem(menu, "\wYes", "1");
    menu_additem(menu, "\wNo", "2");
    
    menu_display(id, menu, 0);
    
    // Store entity data
    new ent_data[EntityData];
    ent_data[ent_index] = ent;
    pev(ent, pev_solid, ent_data[ent_solid]);
    pev(ent, pev_rendermode, ent_data[ent_rendermode]);
    pev(ent, pev_renderamt, ent_data[ent_renderamt]);
    pev(ent, pev_classname, ent_data[ent_classname], 31);
    pev(ent, pev_model, ent_data[ent_model], 31);
    
    ArrayPushArray(g_undo_stack[id], ent_data);
    g_undo_size[id] = ArraySize(g_undo_stack[id]);
}

public ConfirmationMenuHandler(id, menu, item) {
    if(item == 0) {
        new ent_data[EntityData];
        ArrayGetArray(g_undo_stack[id], g_undo_size[id]-1, ent_data);
        
        if(pev_valid(ent_data[ent_index])) {
            RemoveEntity(ent_data[ent_index]);
            SaveSpecificEntity(ent_data[ent_classname], ent_data[ent_model]);
            //client_print_color(id, print_chat, "^4[FWO] ^1Entity removed: ^3%s", ent_data[ent_classname]);
            CC_SendMessage(id, "%L", id, "ENTITY_REMOVED", ent_data[ent_classname]);
        }
    }
    MainEntityMenu(id, 0, 0);
    return PLUGIN_HANDLED;
}

public UndoLastRemoval(id) {
    if(g_undo_size[id] > 0) {
        new ent_data[EntityData];
        ArrayGetArray(g_undo_stack[id], g_undo_size[id]-1, ent_data);
        ArrayDeleteItem(g_undo_stack[id], g_undo_size[id]-1);
        g_undo_size[id]--;
        
        if(pev_valid(ent_data[ent_index])) {
            set_pev(ent_data[ent_index], pev_solid, SOLID_BSP);
            set_pev(ent_data[ent_index], pev_rendermode, ent_data[ent_rendermode]);
            set_pev(ent_data[ent_index], pev_renderamt, ent_data[ent_renderamt]);
            
            RemoveSavedEntity(ent_data[ent_model]);
            //client_print_color(id, print_chat, "^4[FWO] ^1Last removal undone: ^3%s", ent_data[ent_classname]);
            CC_SendMessage(id, "%L", id, "LAST_REMOVAL_UNDONE", ent_data[ent_classname]);
        }
    }
    else {
        //client_print_color(id, print_chat, "^4[FWO] ^1No removals to undo.");
        CC_SendMessage(id, "%L", id, "NO_REMOVALS");
    }
    MainEntityMenu(id, 0, 0);
    return PLUGIN_HANDLED;
}

public ShowMapEntities(id) {
    new menu = menu_create("\r[FWO] \d- \wMap Entities:", "map_entities_handler");

    if (g_map_entity_type_count > 0) {
        new entity_item[64];
        for (new i = 0; i < g_map_entity_type_count; i++) {
            new ent_info[EntityInfo];
            ArrayGetArray(g_map_entity_types, i, ent_info);
            formatex(entity_item, sizeof(entity_item) - 1, "%s (%dx)", ent_info[ei_classname], ent_info[ei_count]);
            menu_additem(menu, entity_item, fmt("%d", i));
        }
    } else {
        menu_additem(menu, "No entities found", "");
    }

    menu_display(id, menu, 0);
}

public map_entities_handler(id, menu, item) {
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new info[8], dummy;
    menu_item_getinfo(menu, item, dummy, info, sizeof(info) - 1, _, _, _);
    new type_index = str_to_num(info);

    OpenEntityOptionsMenu(id, type_index);

    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

public OpenEntityOptionsMenu(id, type_index) {
    new ent_info[EntityInfo];
    ArrayGetArray(g_map_entity_types, type_index, ent_info);
    
    new menu_title[64];
    formatex(menu_title, sizeof(menu_title) - 1, "\r[FWO] \d- \w%s Options:", ent_info[ei_classname]);
    new menu = menu_create(menu_title, "entity_options_handler");

    new item[64], status[8];
    format(status, 7, g_remove_map_entities[type_index] ? "\y[ON]" : "\r[OFF]");
    formatex(item, sizeof(item) - 1, "%s %s", ent_info[ei_classname], status);
    menu_additem(menu, item, fmt("%d", type_index));
    
    // Uniques entites 
    for (new i = 0; i < ent_info[ei_count]; i++) {
        new item_name[32];
        formatex(item_name, sizeof(item_name) - 1, "Entity #%d", i + 1);
        menu_additem(menu, item_name, fmt("%d %d", type_index, ArrayGetCell(ent_info[ei_indices], i)));
    }

    menu_display(id, menu, 0);
}

public entity_options_handler(id, menu, item) {
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        ShowMapEntities(id);
        return PLUGIN_HANDLED;
    }

    new info[16], dummy;
    menu_item_getinfo(menu, item, dummy, info, sizeof(info) - 1, _, _, _);
    new type_index = str_to_num(info);

    if (item >= 0 && item < g_map_entity_type_count) {
        new ent_info[EntityInfo];
        ArrayGetArray(g_map_entity_types, type_index, ent_info);
        
        if (item == 0) { // Toggle Remove All
            g_remove_map_entities[type_index] = !g_remove_map_entities[type_index];
            ApplyMapEntityToggle(type_index, g_remove_map_entities[type_index]);
            new status[32];
            formatex(status, charsmax(status), "%L", id, g_remove_map_entities[type_index] ? "MSG_GLOBAL_REMOVED" : "MSG_GLOBAL_RESTORED");
            CC_SendMessage(id, "%L", id, "GLOBAL_ENTITY_TOGGLED", ent_info[ei_classname], status);
            SaveMapEntityState(type_index); // Saves directly to the .txt
            OpenEntityOptionsMenu(id, type_index);
        } else if (item >= 1) { 
            new ent_array_index = item - 1;
            if (ent_array_index >= 0 && ent_array_index < ent_info[ei_count]) {
                new ent_id = ArrayGetCell(ent_info[ei_indices], ent_array_index);
                if (pev_valid(ent_id)) {
                    CreateGuideLine(id, ent_id);
                    OpenAimMenu(id);
                    //CC_SendMessage(id, "Follow the plasma line to the entity.");
                    CC_SendMessage(id, "%L", id, "FOLLOW_PLASMA");
                } else {
                    //CC_SendMessage(id, "Entity no longer valid.");
                    CC_SendMessage(id, "%L", id, "ENTITY_INVALID");
                    OpenEntityOptionsMenu(id, type_index);
                }
            }
        }
    }

    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

public SaveMapEntityState(type_index) {
    new map[32];
    get_mapname(map, 31);
    
    new filepath[256];
    formatex(filepath, 255, "%s/%s.txt", CONFIG_FOLDER, map);
    
    new temp_filepath[256];
    formatex(temp_filepath, 255, "%s/%s_temp.txt", CONFIG_FOLDER, map);
    
    new ent_info[EntityInfo];
    ArrayGetArray(g_map_entity_types, type_index, ent_info);
    new classname[32];
    copy(classname, 31, ent_info[ei_classname]);

    // Read the current file and rewrite it, adding or removing the entry
    new file = fopen(filepath, "rt");
    new temp_file = fopen(temp_filepath, "wt");
    
    if (file && temp_file) {
        new line[128], found = 0;
        while (fgets(file, line, 127)) {
            trim(line);
            if (contain(line, "^"") != -1) {
                new class[32], model[32];
                parse(line, class, 31, model, 31);
                replace(class, 31, "^"", "");
                replace(model, 31, "^"", "");
                
                // Do not copy the line if it is the entity we are modifying
                if (equali(class, classname) && equali(model, "GLOBAL")) {
                    found = 1;
                    if (g_remove_map_entities[type_index]) {
                        fprintf(temp_file, "^"%s^" ^"GLOBAL^"^n", classname);
                    }
                    continue;
                }
                fprintf(temp_file, "%s^n", line);
            }
        }
        
        // If not found and it is ON, add the entry
        if (!found && g_remove_map_entities[type_index]) {
            fprintf(temp_file, "^"%s^" ^"GLOBAL^"^n", classname);
        }
        
        fclose(file);
        fclose(temp_file);
        
        delete_file(filepath);
        rename_file(temp_filepath, filepath, 1);
    } else {
        if (temp_file) fclose(temp_file);
        if (file) fclose(file);
        
        // If the file doesn't exist, create a new one
        file = fopen(filepath, "wt");
        if (file) {
            if (g_remove_map_entities[type_index]) {
                fprintf(file, "^"%s^" ^"GLOBAL^"^n", classname);
            }
            fclose(file);
        }
    }
}

public ApplyMapEntityToggle(type_index, bool:remove) {
    new ent_info[EntityInfo];
    ArrayGetArray(g_map_entity_types, type_index, ent_info);

    for (new i = 0; i < ent_info[ei_count]; i++) {
        new ent = ArrayGetCell(ent_info[ei_indices], i);
        if (pev_valid(ent)) {
            if (remove) {
                RemoveEntity(ent);
            } else {
                set_pev(ent, pev_rendermode, kRenderNormal);
                set_pev(ent, pev_renderamt, 255.0);
                set_pev(ent, pev_solid, SOLID_BSP);
            }
        }
    }
}

public SaveSpecificEntity(const class[], const model[]) {
    ArrayPushString(g_class, class);
    ArrayPushString(g_model, model);
    g_total++;
    
    new map[32];
    get_mapname(map, 31);
    
    new filepath[256];
    formatex(filepath, 255, "%s/%s.txt", CONFIG_FOLDER, map);
    
    new file = fopen(filepath, "at");
    if(file) {
        fprintf(file, "^"%s^" ^"%s^"^n", class, model);
        fclose(file);
    }
}

public RemoveSavedEntity(const model[]) {
    for(new i = 0; i < g_total; i++) {
        new saved_model[32];
        ArrayGetString(g_model, i, saved_model, 31);
        
        if(equali(model, saved_model)) {
            ArrayDeleteItem(g_class, i);
            ArrayDeleteItem(g_model, i);
            g_total--;
            save_map_config();
            break;
        }
    }
}

public ResetSettings(id) {
    for(new i = 0; i < sizeof(ENTITIES); i++) {
        if(g_remove_entities[i]) {
            g_remove_entities[i] = false;
            ApplyGlobalEntityToggle(i, false); // Restore entities when resetting
        }
    }
    
    new map[32];
    get_mapname(map, 31);
    
    new filepath[256];
    formatex(filepath, 255, "%s/%s.txt", CONFIG_FOLDER, map);
    
    if(file_exists(filepath)) {
        delete_file(filepath);
    }

    //client_print_color(id, print_chat, "^4[FWO] ^1All settings have been reset.");
    CC_SendMessage(id, "%L", id, "ALL_SETTINGS_RESET");
    MainEntityMenu(id, 0, 0);
}

public OpenEntityMenu(id) {
    new menu = menu_create("\r[FWO] \d- \wRemove Specific Entities:", "EntityMenuHandler");
    
    for(new i = 0; i < sizeof(ENTITIES); i++) {
        new item[64], status[8];
        format(status, 7, g_remove_entities[i] ? "\y[ON]" : "\r[OFF]");
        formatex(item, charsmax(item), "%s %s%s", ENTITIES[i], status, i == sizeof(ENTITIES) - 1 ? "^n" : "");
        menu_additem(menu, item);
    }
    
    menu_additem(menu, "\wSave", "save");
    menu_display(id, menu, 0);
}

public EntityMenuHandler(id, menu, item) {
    if(item == MENU_EXIT) {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    if(item == sizeof(ENTITIES)) {
        save_map_config();
        //client_print_color(id, print_chat, "^4[FWO] ^1Settings saved.");
        CC_SendMessage(id, "%L", id, "SETTINGS_SAVED");
        MainEntityMenu(id, 0, 0);
    }
    else if(item >= 0 && item < sizeof(ENTITIES)) {
        g_remove_entities[item] = !g_remove_entities[item];
        ApplyGlobalEntityToggle(item, g_remove_entities[item]);
        new status[32];
        formatex(status, charsmax(status), "%L", id, g_remove_entities[item] ? "MSG_GLOBAL_REMOVED" : "MSG_GLOBAL_RESTORED");
        CC_SendMessage(id, "%L", id, "GLOBAL_ENTITY_TOGGLED", ENTITIES[item], status);
        OpenEntityMenu(id);
    }
    return PLUGIN_HANDLED;
}

// Apply ON/OFF toggle instantly
// Note: If I want to clean up the code and remove this function in the future, I can move its logic into EntityMenuHandler.
public ApplyGlobalEntityToggle(entity_idx, bool:remove) {
    new ent = -1;
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", ENTITIES[entity_idx])) != 0) {
        if(pev_valid(ent)) {
            if(remove) {
                RemoveEntity(ent);
            } else {
                set_pev(ent, pev_rendermode, kRenderNormal);
                set_pev(ent, pev_renderamt, 255.0);
                set_pev(ent, pev_solid, SOLID_BSP);
            }
        }
    }
}

public RemoveEntity(ent) {
    set_pev(ent, pev_rendermode, kRenderTransAlpha);
    set_pev(ent, pev_renderamt, 0.0);
    set_pev(ent, pev_solid, SOLID_NOT);
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

public ToggleNoclip(id) {
    g_noclip_enabled[id] = !g_noclip_enabled[id];
    /*if (g_noclip_enabled[id]) {
        set_pev(id, pev_movetype, MOVETYPE_NOCLIP);
        CC_SendMessage(id, "Noclip: &x06ON&x01.");
    } else {
        set_pev(id, pev_movetype, MOVETYPE_WALK);
        CC_SendMessage(id, "Noclip: &x07OFF&x01.");
    }*/
    MainEntityMenu(id, ADMIN_IMMUNITY, 0);
}

public CreateGuideLine(id, ent_id) {
    new Float:player_origin[3], Float:ent_origin[3];
    
    // Get the player's position
    pev(id, pev_origin, player_origin);
    player_origin[2] += 10.0; // Adjust the line to be created at the player's eye level
    
    // Get the entity's position
    pev(ent_id, pev_origin, ent_origin);
    
    if (!g_noclip_enabled[id]) { 
        g_noclip_enabled[id] = true;
        set_pev(id, pev_movetype, MOVETYPE_NOCLIP);
        //CC_SendMessage(id, "Noclip &x06activated&x01, follow the plasma to visualize the desired entity.");
        CC_SendMessage(id, "%L", id, "NOCLIP_TO_PLASMA");
    }
    
    // Calculate the distance between the player and the entity
    new Float:distance = vector_distance(player_origin, ent_origin);
    
    // The maximum range the line can reach (For example: If the player is too far from the entity, the plasma will travel across the map to the entity)
    new Float:max_segment_length = 9999999.0;
    
    // Calculate the number of segments needed
    new num_segments = floatround(distance / max_segment_length, floatround_ceil);
    
    new Float:segment_start[3], Float:segment_end[3];
    segment_start = player_origin; // Start at the player
    
    for (new i = 1; i <= num_segments; i++) {
        // Calculate the end point of the current segment
        for (new j = 0; j < 3; j++) {
            segment_end[j] = player_origin[j] + (ent_origin[j] - player_origin[j]) * (float(i) / float(num_segments));
        }
        
        // Create the beam between segment_start and segment_end
        message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
        write_byte(TE_BEAMPOINTS);                          // Temporary entity type: line between two points
        engfunc(EngFunc_WriteCoord, segment_start[0]);      // Origin X
        engfunc(EngFunc_WriteCoord, segment_start[1]);      // Origin Y
        engfunc(EngFunc_WriteCoord, segment_start[2]);      // Origin Z
        engfunc(EngFunc_WriteCoord, segment_end[0]);        // Destination X
        engfunc(EngFunc_WriteCoord, segment_end[1]);        // Destination Y
        engfunc(EngFunc_WriteCoord, segment_end[2]);        // Destination Z
        write_short(g_plasma_sprite);                       // Precached sprite index
        write_byte(0);                                      // Frame start
        write_byte(0);                                      // Frame rate
        write_byte(200);                                    // Time the line remains active (set_task in frames), 20 seconds = 200
        write_byte(20);                                     // Line width
        write_byte(0);                                      // Noise
        write_byte(255);                                    // Color R (red)
        write_byte(0);                                      // Color G (green)
        write_byte(0);                                      // Color B (blue)
        write_byte(200);                                    // Brightness
        write_byte(0);                                      // Scroll speed
        message_end();
        
        // Update the starting point for the next segment
        segment_start = segment_end;
    }
}

public create_config_folder() {
    mkdir(CONFIG_FOLDER);
}

public load_ignored_entities() {
    ArrayClear(g_ignored_entities);

    if (file_exists(IGNORE_CFG)) {
        new file = fopen(IGNORE_CFG, "rt");
        if (file) {
            new line[32];
            while (fgets(file, line, 31)) {
                trim(line);
                if (line[0] && !equali(line, "")) {
                    ArrayPushString(g_ignored_entities, line);
                }
            }
            fclose(file);
        }
    }
}

public load_map_config() {
    new map[32];
    get_mapname(map, 31);
    
    new filepath[256];
    formatex(filepath, 255, "%s/%s.txt", CONFIG_FOLDER, map);
    
    if(file_exists(filepath)) {
        new file = fopen(filepath, "rt");
        if(file) {
            new line[128];
            while(fgets(file, line, 127)) {
                trim(line);
                
                if(contain(line, "^"") != -1) {
                    new class[32], model[32];
                    parse(line, class, 31, model, 31);
                    replace(class, 31, "^"", "");
                    replace(model, 31, "^"", "");
                    
                    if(equali(model, "GLOBAL")) {
                        // Global entity (menu2)
                        for (new i = 0; i < sizeof(ENTITIES); i++) {
                            if (equali(class, ENTITIES[i])) {
                                g_remove_entities[i] = true;
                                break;
                            }
                        }
                        // Global entity (menu3))
                        for (new i = 0; i < g_map_entity_type_count; i++) {
                            new ent_info[EntityInfo];
                            ArrayGetArray(g_map_entity_types, i, ent_info);
                            if (equali(class, ent_info[ei_classname])) {
                                g_remove_map_entities[i] = true;
                                ApplyMapEntityToggle(i, true); // Apply immediately
                                break;
                            }
                        }
                    } else {
                        ArrayPushString(g_class, class);
                        ArrayPushString(g_model, model);
                        g_total++;
                    }
                }
            }
            fclose(file);
        }
    }
}

public save_map_config() {
    new map[32];
    get_mapname(map, 31);
    
    new filepath[256];
    formatex(filepath, 255, "%s/%s.txt", CONFIG_FOLDER, map);
    
    new file = fopen(filepath, "wt");
    if (file) {
        // Save global entities (menu 2)
        for(new i = 0; i < sizeof(ENTITIES); i++) {
            if(g_remove_entities[i]) {
                fprintf(file, "^"%s^" ^"GLOBAL^"^n", ENTITIES[i]);
            }
        }
        
        // Save specific entities (menu 1)
        for(new i = 0; i < g_total; i++) {
            new class[32], model[32];
            ArrayGetString(g_class, i, class, 31);
            ArrayGetString(g_model, i, model, 31);
            fprintf(file, "^"%s^" ^"%s^"^n", class, model);
        }
        
        // Save map entities (menu 3)
        for (new i = 0; i < g_map_entity_type_count; i++) {
            new ent_info[EntityInfo];
            ArrayGetArray(g_map_entity_types, i, ent_info);
            if (g_remove_map_entities[i]) {
                fprintf(file, "^"%s^" ^"GLOBAL^"^n", ent_info[ei_classname]);
            }
        }
        
        fclose(file);
    }
}