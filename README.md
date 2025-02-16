# Entity Remover Plugin for AMX Mod X

## **Description**
The **Entity Remover** plugin for AMX Mod X allows server administrators to remove various entities in the game, such as doors, buttons, and breakable objects. It provides a customizable menu interface for users to remove entities either by aiming at them or by enabling a mass removal of specific entity types. Additionally, it offers a feature to undo the last removal action.

## **Features**
- Remove entities like **func_door**, **func_button**, **func_door_rotating**, and **func_breakable**.
- **Aim and remove** specific entities from the game by pointing at them.
- **Undo** the last entity removal action.
- **Reset** all settings and configurations to their default values.
- **Save** specific entities configuration across map reloads.
- **Customizable entity list**: Easily add more entities to the removal list.

## **Configuration**
Configure the list of removable entities by editing the **ENTITIES** array in the code. The entities included by default are:
- `func_door`
- `func_button`
- `func_door_rotating`
- `func_breakable`

**Example (adding a new entity)**:  
If you want to remove walls, simply add `"func_wall"` to the array:

```cpp
new const ENTITIES[][] = {
    "func_door",
    "func_button",
    "func_door_rotating",
    "func_breakable",
    "func_wall"
};
```

## **Commands**
1. **/remove** - Opens the main entity removal menu.

## **Usage**
1. **Main Entity Menu**: Type `/remove` in chat to open the main entity menu. You will be able to choose from:
    - **Remove Aimed Entity**: Removes the entity you are currently aiming at.
    - **Remove Specific Entities**: Opens a list of predefined entities to remove.
    - **Reset All Settings**: Resets all entity removal settings to their default state.

2. **Remove Aimed Entity**: Aim at the entity you want to remove, and it will be removed automatically.

3. **Remove Specific Entities**: This menu allows you to toggle the removal of specific entities from the game (`func_door`, `func_button`, etc.). 
    - **Important**: When you activate and save any entity in this menu (`func_door`), all instances of that entity on the current map will be removed as soon as the map is reloaded or updated. For example, if you activate `func_door` in the `deathrun_arctic` map, all `func_door` entities will be deleted whenever the map is loaded again.

4. **Undo Last Removal**: You can undo the last entity removal by using the undo option in the removal menus.

5. **Save Specific Entity**: Entities that are removed are saved for future reference and can be restored if needed.

## **Configuration File**
The plugin automatically creates a configuration file for each map where specific entities are saved. The file is stored in: `addons/amxmodx/configs/entity_remover/<map_name>.txt`

## **How It Works**
- The plugin monitors entities in the game and removes them based on predefined conditions or user input.
- It saves removed entities to a file specific to the current map, allowing for persistent entity removal configurations.
- You can toggle the removal of entities globally or specifically using in-game menus.

## **Authors**
- **ftl~ツ**