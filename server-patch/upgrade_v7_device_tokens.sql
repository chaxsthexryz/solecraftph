-- Which devices a customer is signed in on, so a status change can reach a
-- closed app. One row per FCM token; the token is the natural key because a
-- device keeps it across sign-ins, and whoever signed in last owns it.
CREATE TABLE IF NOT EXISTS device_tokens (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    token      VARCHAR(255) NOT NULL,
    platform   VARCHAR(16) NOT NULL DEFAULT 'android',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_token (token),
    KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
