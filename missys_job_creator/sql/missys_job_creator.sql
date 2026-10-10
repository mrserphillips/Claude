CREATE TABLE IF NOT EXISTS `missys_job_creator_jobs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(32) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `job_type` VARCHAR(32) NULL,
  `default_duty` TINYINT(1) NOT NULL DEFAULT 1,
  `off_duty_pay` TINYINT(1) NOT NULL DEFAULT 0,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `settings_json` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_mjc_job_name` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `missys_job_creator_grades` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `job_id` INT UNSIGNED NOT NULL,
  `grade_level` INT NOT NULL,
  `name` VARCHAR(48) NOT NULL,
  `payment` INT NOT NULL DEFAULT 0,
  `is_boss` TINYINT(1) NOT NULL DEFAULT 0,
  `bank_auth` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_mjc_job_grade` (`job_id`,`grade_level`),
  CONSTRAINT `fk_mjc_grade_job` FOREIGN KEY (`job_id`) REFERENCES `missys_job_creator_jobs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `missys_job_creator_businesses` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `label` VARCHAR(64) NOT NULL,
  `job_name` VARCHAR(32) NOT NULL,
  `stash_id` VARCHAR(64) NOT NULL,
  `stash_slots` INT NOT NULL DEFAULT 80,
  `stash_weight` INT NOT NULL DEFAULT 250000,
  `revenue_account` VARCHAR(64) NULL,
  `stock_x` DOUBLE NULL,
  `stock_y` DOUBLE NULL,
  `stock_z` DOUBLE NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_mjc_business_job` (`job_name`),
  UNIQUE KEY `uq_mjc_business_stash` (`stash_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `missys_job_creator_npcs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `label` VARCHAR(64) NOT NULL,
  `model` VARCHAR(64) NOT NULL,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `heading` DOUBLE NOT NULL DEFAULT 0,
  `scenario` VARCHAR(96) NULL,
  `animation_json` LONGTEXT NULL,
  `interaction_label` VARCHAR(64) NOT NULL,
  `role_type` VARCHAR(16) NOT NULL DEFAULT 'none',
  `role_ref` VARCHAR(64) NULL,
  `role_grade` INT NOT NULL DEFAULT 0,
  `blip_json` LONGTEXT NULL,
  `access_json` LONGTEXT NULL,
  `hours_json` LONGTEXT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `missys_job_creator_shops` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `npc_id` INT UNSIGNED NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `stock_mode` VARCHAR(16) NOT NULL DEFAULT 'infinite',
  `business_job` VARCHAR(32) NULL,
  `stash_id` VARCHAR(64) NULL,
  `revenue_mode` VARCHAR(16) NOT NULL DEFAULT 'system',
  `revenue_json` LONGTEXT NULL,
  `ui_mode` VARCHAR(16) NOT NULL DEFAULT 'ox',
  `payment_type` VARCHAR(16) NOT NULL DEFAULT 'cash',
  `access_json` LONGTEXT NULL,
  `hours_json` LONGTEXT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mjc_shop_npc` (`npc_id`),
  CONSTRAINT `fk_mjc_shop_npc` FOREIGN KEY (`npc_id`) REFERENCES `missys_job_creator_npcs` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `missys_job_creator_shop_items` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `shop_id` INT UNSIGNED NOT NULL,
  `item_name` VARCHAR(64) NOT NULL,
  `buy_price` INT NOT NULL DEFAULT 0,
  `sell_price` INT NULL,
  `sort_order` INT NOT NULL DEFAULT 0,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_mjc_shop_item` (`shop_id`,`item_name`),
  CONSTRAINT `fk_mjc_item_shop` FOREIGN KEY (`shop_id`) REFERENCES `missys_job_creator_shops` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `missys_job_creator_activities` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `npc_id` INT UNSIGNED NOT NULL,
  `activity_key` VARCHAR(64) NOT NULL,
  `activity_type` VARCHAR(32) NOT NULL DEFAULT 'temporary',
  `config_json` LONGTEXT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `idx_mjc_activity_npc` (`npc_id`),
  CONSTRAINT `fk_mjc_activity_npc` FOREIGN KEY (`npc_id`) REFERENCES `missys_job_creator_npcs` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `missys_job_creator_business_ledger` (
  `account` VARCHAR(64) NOT NULL,
  `balance` BIGINT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`account`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE IF NOT EXISTS `missys_job_creator_points` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(32) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `point_type` VARCHAR(24) NOT NULL,
  `presentation_type` VARCHAR(16) NOT NULL DEFAULT 'target',
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `heading` DOUBLE NOT NULL DEFAULT 0,
  `radius` DOUBLE NOT NULL DEFAULT 2.0,
  `access_json` LONGTEXT NULL,
  `presentation_json` LONGTEXT NULL,
  `config_json` LONGTEXT NULL,
  `blip_json` LONGTEXT NULL,
  `hours_json` LONGTEXT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mjc_point_job` (`job_name`),
  KEY `idx_mjc_point_type` (`point_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `missys_job_creator_blips` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(32) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `sprite` INT NOT NULL DEFAULT 1,
  `colour` INT NOT NULL DEFAULT 0,
  `scale` DOUBLE NOT NULL DEFAULT 0.8,
  `short_range` TINYINT(1) NOT NULL DEFAULT 1,
  `access_json` LONGTEXT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mjc_blip_job` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `missys_job_creator_fleet` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `job_name` VARCHAR(32) NOT NULL,
  `model` VARCHAR(64) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `min_grade` INT NOT NULL DEFAULT 0,
  `plate_prefix` VARCHAR(8) NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mjc_fleet_job` (`job_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `missys_job_creator_migrations` (
  `migration_key` VARCHAR(64) NOT NULL,
  `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`migration_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
