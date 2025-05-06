import os

TXT_FOLDER = "C:/Users/victo/Desktop/entity_remover"  # Path to the folder containing .txt files
OUTPUT_SQL_FILE = "C:/Users/victo/Desktop/migrate_entity_remover.sql"  # File where the SQL queries will be saved

def escape_sql_string(value):
	return value.replace("'", "''").replace('"', '""')

def process_txt_file(filepath):
	queries = []
	map_name = os.path.splitext(os.path.basename(filepath))[0]

	with open(filepath, "r", encoding="utf-8") as f:
		for line in f:
			line = line.strip()
			if not line or line.startswith(";"):
				continue
			
			parts = line.split(maxsplit=1)
			if len(parts) != 2:
				print(f"Warning: Invalid line in {filepath}: {line}")
				continue
			
			classname, model = parts
			is_global = 1 if model == "GLOBAL" else 0
			ent_id = 0

			query = (
				f"INSERT INTO entity_remover (map, classname, model, ent_id, is_global) "
				f"VALUES ('{escape_sql_string(map_name)}', '{escape_sql_string(classname)}', "
				f"'{escape_sql_string(model)}', {ent_id}, {is_global})"
			)
			queries.append(query)

	return queries

def main():
	if not os.path.exists(TXT_FOLDER):
		print(f"Error: Folder {TXT_FOLDER} does not exist.")
		return

	all_queries = []
	for filename in os.listdir(TXT_FOLDER):
		if filename.endswith(".txt"):
			filepath = os.path.join(TXT_FOLDER, filename)
			print(f"Processing: {filepath}")
			queries = process_txt_file(filepath)
			all_queries.extend(queries)

	with open(OUTPUT_SQL_FILE, "w", encoding="utf-8") as sql_file:
		for query in all_queries:
			sql_file.write(query + ";\n")

	print(f"Queries generated. File saved to: {OUTPUT_SQL_FILE}")
	print(f"Total queries: {len(all_queries)}")

if __name__ == "__main__":
	main()