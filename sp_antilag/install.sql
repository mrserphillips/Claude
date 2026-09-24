CREATE TABLE IF NOT EXISTS `sp_antilag` (
  `plate` varchar(16) NOT NULL,
  `flame_colour` varchar(16) NOT NULL DEFAULT 'stock',
  `pops_bangs` tinyint(1) NOT NULL DEFAULT 1,
  `settings` longtext NULL,
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Upgrading from V4.3 or older? No manual step needed: the resource adds the
-- flame_colour, pops_bangs and settings (V5.0) columns automatically on start.
