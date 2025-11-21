import os
import re

# Path to the directory containing text files
directory = "entity_remover"

# Regex pattern to match quoted strings
pattern = r'"([^"]+)"'

# Iterate over all .txt files in the directory
for filename in os.listdir(directory):
    if filename.endswith(".txt"):
        map_name = os.path.splitext(filename)[0]  # Remove .txt extension
        filepath = os.path.join(directory, filename)
        with open(filepath, "r", encoding="utf-8") as file:
            for line in file:
                matches = re.findall(pattern, line)
                if len(matches) == 2:
                    classname, model = matches
                    if model == "GLOBAL":
                        model = ""  # Replace GLOBAL with empty string
                    # Create the INSERT statement
                    insert_stmt = f"INSERT INTO entity_remover (`map`, `classname`, `model`) VALUES ('{map_name}', '{classname}', '{model}');"
                    print(insert_stmt)
