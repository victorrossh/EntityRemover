# Entity Remover Plugin for AMX Mod X

## **Description**

The **Entity Remover** plugin for AMX Mod X is a powerful tool designed to help server administrators manage and remove entities in the game dynamically. It provides an intuitive menu interface for users to remove entities by aiming at them or enabling mass removal of specific entity types. The plugin scans the map for entities manually, allowing precise control over entity removal. It supports saving configurations in both MySQL and `.txt` file formats, offering flexibility based on server needs.

-------

## **Features**

- **Dynamic Entity Scanning:** Scans the map for entities and categorizes them by classname.  
- **Aim and Remove:** Remove specific entities by aiming at them.  
- **Undo Functionality:** Revert the last entity removal action.  
- **Global Entity Removal:** Toggle the removal of all instances of a specific entity type across the map.  
- **Individual Entity Removal:** Remove specific instances of entities directly from the global menu.  
- **Removed Entity Indicators:** Visual indication of which entities have been removed.  
- **Persistent Configurations:** Save entity removal settings for specific maps in MySQL or `.txt` files.  
- **Dynamic Menu:** Automatically detects and lists available entities for removal.  
- **Noclip Assistance:** Automatically enables noclip to help users locate entities.  
- **Customizable Ignored Entities:** Define a list of entities to ignore during scanning.

-------

## **How It Works**

- **Entity Scanning:** The plugin scans the map for all valid entities and categorizes them by classname.
- **Menu Generation:** A dynamic menu is created based on the detected entities.
- **Entity Removal:** Entities are removed by setting their rendermode to transparent and their solid property to `SOLID_NOT`.
- **Persistence:** Configurations are saved through either MySQL or text files. Text mode stores removals in `configs/entity_remover/<map>.txt`.
- **Undo Functionality:** The plugin stores the properties of removed entities, allowing users to restore them if needed.

-------

## **Configuration**

The plugin allows customization of ignored entities via the `ignored_entities.cfg` file. Additionally, you can configure the data saving mode (MySQL or `.txt`) and MySQL settings.

### Ignored Entities File
The `ignored_entities.cfg` file should be placed in:
```addons/amxmodx/configs/ignored_entities.cfg```

Example content:
```
player
worldspawn
trigger_hurt
```

### Data Saving Mode

Set `SQL_TYPE` in `addons/amxmodx/configs/entity_remover.cfg`:
- `SQL_TYPE = "mysql"`: use MySQL.
- `SQL_TYPE = "text"` (or `"txt"`): use map-specific text files. MySQL settings are not required in text mode.

#### MySQL Configuration
If using MySQL, configure the connection details in `entity_remover.cfg` located in:
```addons/amxmodx/configs/entity_remover.cfg```

Example content:
```
SQL_TYPE="mysql"
SQL_HOST=your_host
SQL_USER=your_user
SQL_PASSWORD=your_password
SQL_DATABASE=your_database
```

#### Text Configuration
Configurations are saved as `.txt` files in:
```addons/amxmodx/configs/entity_remover/<map_name>.txt```

Example:
```
SQL_TYPE="text"
```

-------

## **Commands**

- `/remove`: Opens the main entity removal menu.

-------

## **Usage**

### Main Entity Menu
Type `/remove` in the chat to open the main menu. The menu provides the following options:
- **Remove Aimed Entity:** Removes the entity you are currently aiming at.
- **Map Entities:** Opens a list of all detected entities on the map for mass removal.
- **Reset All Settings:** Resets all entity removal settings to their default state.
- **Toggle Noclip:** Enables or disables noclip to help locate entities.

### Remove Aimed Entity
Aim at the entity you want to remove and select the "Remove" option in the menu. The plugin saves the entity's properties for future reference.

### Map Entities
This menu lists all detected entities on the map, grouped by their classname.
- You can toggle the removal of all instances of a specific entity type (e.g., all `func_door` entities).
- Each individual entity in the list shows its current status (removed or not) with a visual indicator.
- Selecting an individual entity creates a plasma line to guide you to its location.
- You can remove specific instances of entities directly from this menu.

### Undo Last Removal
Use the "Undo" option in the menu to revert the last entity removal action.

### Save Specific Entity
Removed entities are saved according to the configured mode:
- **MySQL**: Stored in the `entity_remover` table.
- **Text**: Saved in the map-specific `.txt` file.

-------

## **File Format (.txt Mode)**

The configuration file stores entities in the following format:
- For global entity removal: `"classname" "GLOBAL"`
- For a specific entity removal: `"classname" "model"`

The model is the persistent identifier for an individual removal. An empty model in MySQL represents a global classname removal.

Example:
```
"func_button" "GLOBAL"
"func_conveyor" "GLOBAL"
"func_door_rotating" "*126"
"func_door_rotating" "*8"
"func_door_rotating" "models/props/door.mdl"
```

-------

## **Manual Testing Checklist**

- With `SQL_TYPE="mysql"`, remove and restore an individual entity; after a map change/restart, confirm the removal persists until restored and its database row is then cleared.
- With `SQL_TYPE="text"`, repeat the same flow and confirm `configs/entity_remover/<map>.txt` is created, updated, and loaded on the next map load.
- Toggle a classname globally, reload the map, then restore it; verify all matching entities and the global saved record change as expected.
- Verify entities with empty model values are treated as global removals only.
- Aim at nothing and choose **Remove Aimed Entity**; verify the message is shown and the main menu remains open.
- Use **Undo** with no history; verify the no-removals message appears.
- Remove and restore entities from the map menu; verify the feedback identifies the classname and does not display a transient entity ID.
- Toggle noclip from the main menu; verify the menu reopens. On a fresh menu session, teleport to an entity and verify noclip is enabled before teleporting and the plasma guide line appears.
- Reset all settings; verify the current map's entities are restored, saved settings are cleared, and the reset message appears.
- Test the entity toggle option with every supported client language. `MENU_OPTION_TOGGLE_ENTITY` currently has an English phrase only, so the remaining language sections still need translations.

-------

## **Credits & Inspiration**

This plugin was inspired by the original **Entity Remover** plugin by Exolent:  
[Entity Remover by Exolent](https://forums.alliedmods.net/showthread.php?t=74680)

The original plugin allowed administrators to remove specific entities in any map using admin commands, including an **undo** function for accidental removals.  
This version expands upon Exolent's idea by introducing:
- **Dynamic entity scanning:** Manual scanning of map entities for precise control.
- **Mass entity removal:** Remove all instances of a specific entity type.
- **Automatic menu generation:** The plugin detects available entities and creates a menu dynamically.
- **Item-by-item removal menu:** Precisely select and delete entities directly from a list.
- **Dual storage support:** Configurable MySQL or `.txt` storage.

-------

## **Authors**

- **ftl~ツ**
