-- Add daily notification state columns to user_locations table
-- These columns track daily notification state for the new UV notification flow

ALTER TABLE user_locations
ADD COLUMN IF NOT EXISTS high_uv_notified_date DATE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS safe_uv_notified_date DATE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS ignored_until_date DATE DEFAULT NULL;

-- Add index for efficient querying of notification state
CREATE INDEX IF NOT EXISTS idx_user_locations_notification_dates
ON user_locations(high_uv_notified_date, safe_uv_notified_date, ignored_until_date);

-- Add comment for documentation
COMMENT ON COLUMN user_locations.high_uv_notified_date IS 'Date when high UV notification was sent (YYYY-MM-DD). Compared to today to determine if notification needed.';
COMMENT ON COLUMN user_locations.safe_uv_notified_date IS 'Date when UV all-clear notification was sent. Only sent after high UV notification on same day.';
COMMENT ON COLUMN user_locations.ignored_until_date IS 'If set to today, user has opted out of all notifications until tomorrow.';
