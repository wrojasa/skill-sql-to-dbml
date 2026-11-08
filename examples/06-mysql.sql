CREATE TABLE `usuario` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `email` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `rol` enum('admin','editor','lector') NOT NULL DEFAULT 'lector',
  `permisos` set('leer','escribir','borrar') DEFAULT NULL,
  `creado_en` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_usuario_email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=42 DEFAULT CHARSET=utf8mb4 COMMENT='Usuarios del portal';

CREATE TABLE `perfil` (
  `usuario_id` int(11) unsigned NOT NULL,
  `bio` text COMMENT 'Texto libre del perfil',
  `avatar_url` varchar(255) DEFAULT NULL,
  UNIQUE KEY `uq_perfil_usuario` (`usuario_id`),
  CONSTRAINT `fk_perfil_usuario` FOREIGN KEY (`usuario_id`) REFERENCES `usuario` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `articulo` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `autor_id` int(11) unsigned DEFAULT NULL,
  `titulo` varchar(200) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_articulo_autor` (`autor_id`),
  FULLTEXT KEY `ft_articulo_titulo` (`titulo`),
  CONSTRAINT `fk_articulo_autor` FOREIGN KEY (`autor_id`) REFERENCES `usuario` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
