-- Velora Jam Co. database tables
-- The resource also creates these automatically on start (CREATE TABLE IF NOT EXISTS),
-- so running this file is optional.

CREATE TABLE IF NOT EXISTS `velora_jamco_players` (
    `citizenid` VARCHAR(64) NOT NULL,
    `stats` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `velora_jamco_recipes` (
    `citizenid` VARCHAR(64) NOT NULL,
    `recipe_id` VARCHAR(64) NOT NULL,
    `best_quality` INT NOT NULL DEFAULT 0,
    `crafted` INT NOT NULL DEFAULT 0,
    `discovered_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `recipe_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Crash / restart recovery (ingredients and deposits owed back) and the kitchen cooling rack
CREATE TABLE IF NOT EXISTS `velora_jamco_pending` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(64) NOT NULL,
    `kind` VARCHAR(16) NOT NULL,
    `payload` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `velora_jamco_logs` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(64) NOT NULL,
    `action` VARCHAR(48) NOT NULL,
    `data` LONGTEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`),
    KEY `action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
