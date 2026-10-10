CREATE TABLE IF NOT EXISTS `qbcrafting_recipes` (
  `id` varchar(48) NOT NULL,
  `data` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `qbcrafting_stations` (
  `id` varchar(48) NOT NULL,
  `data` longtext NOT NULL,
  `locations` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `qbcrafting_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `source` int(11) NOT NULL,
  `name` varchar(64) NOT NULL,
  `identifier` varchar(64) NOT NULL,
  `action` varchar(64) NOT NULL,
  `details` text NOT NULL,
  PRIMARY KEY (`id`),
  KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
