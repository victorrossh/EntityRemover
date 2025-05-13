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
- **Persistence:** Configurations are saved based on the mode:
  - **MySQL Mode:** Queries are generated and executed to store data in the database.
  - **.txt Mode:** Data is written to a map-specific `.txt` file.
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

Set the saving mode by defining `USE_SQL` in the plugin source:
- `#define USE_SQL 1`: Enables MySQL for configuration storage.
- `#define USE_SQL 0`: Uses `.txt` files for configuration storage (default).

#### MySQL Configuration (USE_SQL 1)
If using MySQL, configure the connection details in `entity_remover.cfg` located in:
```addons/amxmodx/configs/entity_remover.cfg```

Example content:
```
SQL_TYPE=mysql
SQL_HOST=your_host
SQL_USER=your_user
SQL_PASSWORD=your_password
SQL_DATABASE=your_database
```

#### .txt Configuration (USE_SQL 0)
Configurations are saved as `.txt` files in:
```addons/amxmodx/configs/entity_remover/<map_name>.txt```

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
- **.txt**: Saved in the map-specific `.txt` file.

-------

## **File Format (.txt Mode)**

The configuration file stores entities in the following format:
- For global entity removal: `"classname" "GLOBAL"`
- For specific entity removal (no model path with `.mdl` or `.spr`): `"classname" "ent_id"`
- For specific entity removal (with model path like `.mdl` or `.spr`): `"classname" "model" "ent_id"`

Example:
```
"func_button" "GLOBAL"
"func_conveyor" "GLOBAL"
"func_door_rotating" "*126"
"func_door_rotating" "*8"
"func_door_rotating" "models/props/door.mdl" "126"
"func_door_rotating" "models/props/door.mdl" "8"
```

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
