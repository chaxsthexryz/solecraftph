-- Saved delivery addresses. Until now a customer had exactly one, the single
-- users.address text column, so ordering to work instead of home meant
-- retyping and then retyping back.
--
-- The address stays one text block rather than being split into street /
-- barangay / city, because orders.customer_address is already one block and
-- everything downstream — the confirmation email, the admin order view, the
-- receipt — reads it that way. Splitting it here would mean rewriting all of
-- those to put it back together.
CREATE TABLE IF NOT EXISTS addresses (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    user_id        INT NOT NULL,
    label          VARCHAR(40)  NOT NULL DEFAULT 'Home',
    recipient_name VARCHAR(120) NOT NULL DEFAULT '',
    phone          VARCHAR(40)  NOT NULL DEFAULT '',
    address        TEXT         NOT NULL,
    -- Filled by "use my location". Nullable: most addresses will never have a
    -- pin, and an address without one must stay perfectly usable.
    latitude       DECIMAL(10, 7) NULL,
    longitude      DECIMAL(10, 7) NULL,
    is_default     TINYINT(1)   NOT NULL DEFAULT 0,
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_user (user_id),
    KEY idx_user_default (user_id, is_default)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Everyone who already had an address keeps it, as their default "Home".
-- Without this a customer opens the new screen and finds it empty, having
-- given you their address months ago.
INSERT INTO addresses (user_id, label, recipient_name, phone, address, is_default)
SELECT u.id,
       'Home',
       COALESCE(u.full_name, ''),
       COALESCE(u.phone, ''),
       u.address,
       1
FROM users u
WHERE u.address IS NOT NULL
  AND u.address <> ''
  AND NOT EXISTS (SELECT 1 FROM addresses a WHERE a.user_id = u.id);
