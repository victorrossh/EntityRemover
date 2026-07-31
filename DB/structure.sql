CREATE TABLE IF NOT EXISTS `entity_remover` (
	`id` INT NOT NULL AUTO_INCREMENT,
	`map` VARCHAR(32) NOT NULL,
	`classname` VARCHAR(32) NOT NULL,
	`model` VARCHAR(64) NOT NULL,
	PRIMARY KEY (`id`),
	INDEX `map_classname` (`map`, `classname`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
