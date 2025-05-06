# migrate_txt_to_sql

This script converts entity removal configurations for the `entity_remover` plugin from `.txt` files to a MySQL database. It was developed to migrate settings for multiple maps (e.g., `de_dust2.txt`) that were originally saved as text files during plugin usage. The goal was to transition to a database for improved management, consistency, and scalability of map-specific entity removal data.

## How It Works
The script reads `.txt` files containing entity removal data, where each line typically follows the format `<classname> <model>` (e.g., `func_breakable GLOBAL` or `func_wall models/props/de_dust2/crate.mdl`). It extracts the map name from the file name, processes each line into an SQL `INSERT` query, and generates a `.sql` file (e.g., `migrate_entity_remover.sql`) with the resulting queries for database import.