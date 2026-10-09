-- =====================================================================
--  Velora City — Starter Pack (velora_starterpack)
--  Run once against your server database (the same one oxmysql uses).
--  The resource also creates these tables automatically on start when
--  Config.Database.autoCreate = true. Running this file is safe either way.
-- =====================================================================

-- One row per character (citizenid). The UNIQUE key is the hard guarantee
-- that a character can never hold two claims / two paths.
CREATE TABLE IF NOT EXISTS `velora_starterpack_claims` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`     VARCHAR(50)  NOT NULL,
    `license`       VARCHAR(100) NULL DEFAULT NULL,
    `char_name`     VARCHAR(100) NULL DEFAULT NULL,
    `path`          VARCHAR(32)  NOT NULL,
    `status`        ENUM('pending', 'completed') NOT NULL DEFAULT 'pending',
    `needs_review`  TINYINT(1)   NOT NULL DEFAULT 0,
    `attempts`      INT UNSIGNED NOT NULL DEFAULT 0,
    `lock_token`    VARCHAR(64)  NULL DEFAULT NULL,
    `lock_at`       DATETIME     NULL DEFAULT NULL,
    `opened_by`     VARCHAR(100) NULL DEFAULT NULL,
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `completed_at`  DATETIME     NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_vsp_claims_citizenid` (`citizenid`),
    KEY `idx_vsp_claims_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Per-reward progress. Each reward "step" (an item stack, a single
-- non-stackable unit, cash, bank) is recorded so a retry never re-grants
-- something that was already delivered.
CREATE TABLE IF NOT EXISTS `velora_starterpack_rewards` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`   VARCHAR(50)  NOT NULL,
    `step_key`    VARCHAR(96)  NOT NULL,
    `status`      ENUM('granting', 'granted', 'review') NOT NULL DEFAULT 'granting',
    `amount`      INT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_vsp_rewards_step` (`citizenid`, `step_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Audit trail: claims, completions, admin resets and gives.
CREATE TABLE IF NOT EXISTS `velora_starterpack_history` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`   VARCHAR(50)  NOT NULL,
    `action`      VARCHAR(32)  NOT NULL,
    `path`        VARCHAR(32)  NULL DEFAULT NULL,
    `actor`       VARCHAR(100) NULL DEFAULT NULL,
    `details`     TEXT         NULL DEFAULT NULL,
    `created_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_vsp_history_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- OPTIONAL: mark every EXISTING character as already claimed, so only
-- characters created after installation receive the starter pack.
-- Uncomment and run once if you are installing on a live server.
-- ---------------------------------------------------------------------
-- INSERT IGNORE INTO `velora_starterpack_claims` (`citizenid`, `path`, `status`, `opened_by`, `completed_at`)
-- SELECT `citizenid`, 'legacy', 'completed', 'install-script', NOW() FROM `players`;
