# Entity Remover Plugin for AMX Mod X

## **Description**

The **Entity Remover** plugin for AMX Mod X is a powerful tool designed to help server administrators manage and remove entities in the game dynamically. It provides an intuitive menu interface for users to remove entities either by aiming at them or by enabling mass removal of specific entity types. The plugin scans the map for entities manually, allowing for precise control over entity removal.

## **Features**

- **Dynamic Entity Scanning:** Scans the map for entities and categorizes them by classname.
- **Aim and Remove:** Remove specific entities by aiming at them.
- **Undo Functionality:** Revert the last entity removal action.
- **Global Entity Removal:** Toggle the removal of all instances of a specific entity type across the map.
- **Persistent Configurations:** Save entity removal settings for specific maps.
- **Dynamic Menu:** Automatically detects and lists available entities for removal.
- **Noclip Assistance:** Automatically enables noclip to help users locate entities.
- **Customizable Ignored Entities:** Define a list of entities to ignore during scanning.

## **Configuration**

The plugin allows you to customize the list of ignored entities by editing the `ignored_entities.cfg` file. By default, entities like `player` and `worldspawn` are ignored.

### **Ignored Entities File**

The `ignored_entities.cfg` file should be placed in:
```addons/amxmodx/configs/ignored_entities.cfg```

Example content:
```
player
worldspawn
trigger_hurt
```


## Commands

- `/remove`: Opens the main entity removal menu.

## **Usage**

### **Main Entity Menu**

Type `/remove` in the chat to open the main menu. The menu provides the following options:

- **Remove Aimed Entity:** Removes the entity you are currently aiming at.
- **Map Entities:** Opens a list of all detected entities on the map for mass removal.
- **Reset All Settings:** Resets all entity removal settings to their default state.
- **Toggle Noclip:** Enables or disables noclip to help locate entities.

### **Remove Aimed Entity**
Aim at the entity you want to remove and select the "Remove" option in the menu.

The plugin will save the entity's properties (e.g., classname, model) for future reference.

### **Map Entities**
This menu lists all detected entities on the map, grouped by their classname.

- You can toggle the removal of all instances of a specific entity type (e.g., all `func_door` entities).
- Selecting an individual entity will create a plasma line to guide you to its location.

### **Undo Last Removal**
Use the "Undo" option in the menu to revert the last entity removal action.

### **Save Specific Entity**
Removed entities are saved in a configuration file specific to the current map. This ensures that the removal persists across map reloads.

### **Configuration File**
The plugin automatically creates a configuration file for each map where specific entities are saved. The file is stored in:
```addons/amxmodx/configs/entity_remover/<map_name>.txt```


#### **File Format**

The configuration file stores entities in the following format:

- For global entity removal: `"classname" "GLOBAL"`
- For specific entity removal: `"classname" "ID"`

Example:
```
"func_button" "GLOBAL"
"func_conveyor" "GLOBAL"
"func_door_rotating" "*126"
"func_door_rotating" "*8"
```


## **How It Works**

- **Entity Scanning:** The plugin scans the map for all valid entities and categorizes them by classname.
- **Menu Generation:** A dynamic menu is created based on the detected entities.
- **Entity Removal:** Entities are removed by setting their rendermode to transparent and their solid property to `SOLID_NOT`.
- **Persistence:** Removed entities are saved to a configuration file, ensuring that the changes persist across map reloads.
- **Undo Functionality:** The plugin stores the properties of removed entities, allowing users to restore them if needed.

## **Credits & Inspiration**

This plugin was inspired by the original **Entity Remover** plugin by Exolent:  
[Entity Remover by Exolent](https://forums.alliedmods.net/showthread.php?t=74680)

The original plugin allowed administrators to remove specific entities in any map using admin commands, including an **undo** function for accidental removals.  
This version expands upon Exolent's idea by introducing:

- **Dynamic entity scanning:** Manual scanning of map entities for precise control.
- **Mass entity removal:** Remove all instances of a specific entity type.
- **Automatic menu generation:** The plugin detects available entities and creates a menu dynamically.
- **Item-by-item removal menu:** Precisely select and delete entities directly from a list.

## **Authors**
- **ftl~ツ**