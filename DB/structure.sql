CREATE TABLE IF NOT EXISTS `entity_remover` (
	`id` INT NOT NULL AUTO_INCREMENT,
	`map` VARCHAR(32) NOT NULL,
	`classname` VARCHAR(32) NOT NULL,
	`model` VARCHAR(64) NOT NULL,
	`ent_id` INT NOT NULL DEFAULT 0,
	`is_global` TINYINT(1) NOT NULL DEFAULT 0,
	PRIMARY KEY (`id`),
	INDEX `map_classname` (`map`, `classname`),
	INDEX `map_ent_id` (`map`, `ent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;