-- SoleCraftPH v5: login throttling. Safe to re-run.
CREATE TABLE IF NOT EXISTS `login_attempts` (
  `id`           INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  -- Both are recorded so one attacker cannot dodge the limit by rotating
  -- usernames, and one victim cannot be locked out by an attacker elsewhere.
  `ip`           VARCHAR(45) NOT NULL,
  `username`     VARCHAR(150) NOT NULL,
  `succeeded`    TINYINT(1) NOT NULL DEFAULT 0,
  `attempted_at` TIMESTAMP NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_attempt_ip`   (`ip`, `attempted_at`),
  KEY `idx_attempt_user` (`username`, `attempted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
