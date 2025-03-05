#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <xs>
#include <cromchat2>

#define PLUGIN "Entity Remover"
#define VERSION "1.0"
#define AUTHOR "ftl~"

// Path to save the configuration files
new const CONFIG_FOLDER[] = "addons/amxmodx/configs/entity_remover";

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

    // Initializes the temporary array to store the map entities
    g_map_entities = ArrayCreate(32, 1);
    g_map_entity_count = 0;
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_clcmd("say /remove", "MainEntityMenu", ADMIN_IMMUNITY);
    register_clcmd("say_team /remove", "MainEntityMenu", ADMIN_IMMUNITY);

    for(new i = 1; i <= 32; i++) {
        g_undo_stack[i] = ArrayCreate(EntityData, 1);
    }
    create_config_folder();
    ScanMapEntities();
    load_map_config();

    //Chat prefix
    CC_SetPrefix("&x04[FWO]");
}

public plugin_cfg(){
    register_dictionary("entity_remover_ftl.txt");
}

public ScanMapEntities() {
    new entity_index = -1;
    new entity_name[32];

    // Clears the temporary array before scanning
    ArrayClear(g_map_entities);
    g_map_entity_count = 0;

    // Scans all the entities on the map
    while ((entity_index = find_ent_by_class(entity_index, ""))) {
        pev(entity_index, pev_classname, entity_name, sizeof(entity_name) - 1);

        // Debug: Displays the name of the entity found
        server_print("[FWO] Entidade encontrada: %s", entity_name);

        // Adds the entity's name to the temporary array
        ArrayPushString(g_map_entities, entity_name);
        g_map_entity_count++;
    }

    // Debug: Displays the number of entities found
    server_print("[FWO] Total de entidades encontradas no mapa: %d", g_map_entity_count);

        // In case no entity is found
    if (g_map_entity_count == 0) {
        server_print("[FWO] Nenhuma entidade encontrada.");
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

    menu_additem(menu, "\wRemove Aimed Entity", "1");
    menu_additem(menu, "\wRemove Specific Entities", "2");
    menu_additem(menu, "\wMap Entities", "3");
    menu_additem(menu, "\wReset All Settings", "4");

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
    }
    return PLUGIN_HANDLED;
}

public ShowMapEntities(id) {
    new menu = menu_create("\r[FWO] \d- \wMap Entities:", "map_entities_handler");

    if (g_map_entity_count > 0) {
        new entity_name[32];
        for (new i = 0; i < g_map_entity_count; i++) {
            ArrayGetString(g_map_entities, i, entity_name, sizeof(entity_name) - 1);
            menu_additem(menu, entity_name, "");
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

    // Gets the entity's name to display in the menu
    new entity_name[32];
    ArrayGetString(g_map_entities, item, entity_name, sizeof(entity_name) - 1);

    // Takes us to the submenu when an entity is selected
    OpenEntityOptionsMenu(id, entity_name);

    return PLUGIN_HANDLED;
}

public OpenEntityOptionsMenu(id, const entity_name[]) {
    new menu = menu_create("\r[FWO] \d- \wEntity Options:", "entity_options_handler");

    menu_additem(menu, "Remove All", entity_name); // Removes all entities of this type
    menu_additem(menu, "Remove One", entity_name); // Removes only the selected entity
    menu_additem(menu, "Save for Auto-Removal", entity_name); // Save

    menu_display(id, menu, 0);
}

public entity_options_handler(id, menu, item) {
    if (item == MENU_EXIT) {
        menu_destroy(menu);
        return;
    }

    // Gets the name of the selected entity
    new entity_name[32];
    menu_item_getinfo(menu, item, _, entity_name, sizeof(entity_name) - 1, _, _, _);

    switch (item) {
        case 0: {
            // Removes all entities of this type
            RemoveAllEntitiesOfType(entity_name);
            client_print_color(id, print_chat, "^4[FWO] ^1Removed all entities of type: ^4%s.", entity_name);
        }
        case 1: {
            // Removes just one entity of this type
            RemoveOneEntityOfType(entity_name);
            client_print_color(id, print_chat, "^4[FWO] ^1Removed one entity of type: ^4%s.", entity_name);
        }
        case 2: {
            // Saves the entity for automatic removal
            SaveEntityForAutoRemoval(entity_name);
            client_print_color(id, print_chat, "^4[FWO] ^1Saved entity for auto-removal: ^4%s.", entity_name);
        }
    }

    // Updates the entity list after removal
    ScanMapEntities();
    return;
}

public RemoveAllEntitiesOfType(const entity_name[]) {
    new entity_index = -1;
    while ((entity_index = find_ent_by_class(entity_index, entity_name))) {
        RemoveEntity(entity_index);
    }
}

public RemoveOneEntityOfType(const entity_name[]) {
    new entity_index = find_ent_by_class(-1, entity_name);
    if (entity_index > 0) {
        RemoveEntity(entity_index);
    }
}

public SaveEntityForAutoRemoval(const entity_name[]) {
    ArrayPushString(g_class, entity_name);
    ArrayPushString(g_model, "*");
    g_total++;

    save_map_config();
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

public create_config_folder() {
    mkdir(CONFIG_FOLDER);
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
                    // Specific entity
                    new class[32], model[32];
                    parse(line, class, 31, model, 31);
                    replace(class, 31, "^"", "");
                    replace(model, 31, "^"", "");
                    
                    if(equali(model, "GLOBAL")) {
                        // Global entity
                        for(new i = 0; i < sizeof(ENTITIES); i++) {
                            if(equali(class, ENTITIES[i])) {
                                g_remove_entities[i] = true;
                                break;
                            }
                        }
                    }
                    else {
                        // Specific entity
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
    if(file) {
        // Save global entities
        for(new i = 0; i < sizeof(ENTITIES); i++) {
            if(g_remove_entities[i]) {
                fprintf(file, "^"%s^" ^"GLOBAL^"^n", ENTITIES[i]);
            }
        }
        
        // Save specific entities
        for(new i = 0; i < g_total; i++) {
            new class[32], model[32];
            ArrayGetString(g_class, i, class, 31);
            ArrayGetString(g_model, i, model, 31);
            
            fprintf(file, "^"%s^" ^"%s^"^n", class, model);
        }
        fclose(file);
    }
}