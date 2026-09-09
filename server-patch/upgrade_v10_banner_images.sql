-- Promotional banner images.
--
-- The banners table already carried title, subtitle, link_url, sort_order and
-- is_active, and drove the thin text strip across the top of the homepage.
-- This adds the picture, so the same row can instead be a full-width promo
-- banner — the Foot Locker "MID-SEASON SALE / UP TO 50% OFF" shape, where the
-- artwork carries the message and the row carries where it links to.
--
-- Reusing the banners table rather than inventing a promo table: it already has
-- every field a promo banner needs except the image, and an admin screen that
-- creates, orders, activates and deletes them.
--
-- Empty string rather than NULL: every existing banner stays exactly what it is
-- today, a text strip, and "has an image" is a plain !== '' test with no null
-- handling on either side.
ALTER TABLE banners
    ADD COLUMN image_url VARCHAR(255) NOT NULL DEFAULT '' AFTER subtitle;
