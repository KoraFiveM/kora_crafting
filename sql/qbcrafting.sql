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
