-- ============================================
-- COMPLETE RLS POLICY FIX FOR ALL TABLES
-- Run this in Supabase SQL Editor
-- ============================================

-- ============================================
-- STEP 1: VERIFY TABLE STRUCTURES
-- ============================================

-- Check user_profiles columns
SELECT 'user_profiles' as table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'user_profiles'
ORDER BY ordinal_position;

-- Check user_devices columns
SELECT 'user_devices' as table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'user_devices'
ORDER BY ordinal_position;

-- Check user_locations columns
SELECT 'user_locations' as table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'user_locations'
ORDER BY ordinal_position;

-- ============================================
-- STEP 2: DROP ALL EXISTING POLICIES
-- ============================================

-- user_profiles policies
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_select_policy" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_insert_policy" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_update_policy" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_select_own" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_insert_own" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_update_own" ON user_profiles;
DROP POLICY IF EXISTS "service_role_all_access" ON user_profiles;
DROP POLICY IF EXISTS "Enable read access for own profile" ON user_profiles;
DROP POLICY IF EXISTS "Enable insert for own profile" ON user_profiles;
DROP POLICY IF EXISTS "Enable update for own profile" ON user_profiles;

-- user_devices policies
DROP POLICY IF EXISTS "Users can view own devices" ON user_devices;
DROP POLICY IF EXISTS "Users can insert own devices" ON user_devices;
DROP POLICY IF EXISTS "Users can update own devices" ON user_devices;
DROP POLICY IF EXISTS "Users can delete own devices" ON user_devices;
DROP POLICY IF EXISTS "Users can view their own devices" ON user_devices;
DROP POLICY IF EXISTS "Users can insert their own devices" ON user_devices;
DROP POLICY IF EXISTS "Users can update their own devices" ON user_devices;
DROP POLICY IF EXISTS "Users can delete their own devices" ON user_devices;
DROP POLICY IF EXISTS "user_devices_select_own" ON user_devices;
DROP POLICY IF EXISTS "user_devices_insert_own" ON user_devices;
DROP POLICY IF EXISTS "user_devices_update_own" ON user_devices;
DROP POLICY IF EXISTS "user_devices_delete_own" ON user_devices;
DROP POLICY IF EXISTS "service_role_all_access" ON user_devices;

-- user_locations policies
DROP POLICY IF EXISTS "Users can view own locations" ON user_locations;
DROP POLICY IF EXISTS "Users can insert own locations" ON user_locations;
DROP POLICY IF EXISTS "Users can update own locations" ON user_locations;
DROP POLICY IF EXISTS "Users can view their own locations" ON user_locations;
DROP POLICY IF EXISTS "Users can insert their own locations" ON user_locations;
DROP POLICY IF EXISTS "Users can update their own locations" ON user_locations;
DROP POLICY IF EXISTS "user_locations_select_own" ON user_locations;
DROP POLICY IF EXISTS "user_locations_insert_own" ON user_locations;
DROP POLICY IF EXISTS "user_locations_update_own" ON user_locations;
DROP POLICY IF EXISTS "service_role_all_access" ON user_locations;

-- notification_logs policies
DROP POLICY IF EXISTS "Users can view own notification logs" ON notification_logs;
DROP POLICY IF EXISTS "Users can insert own notification logs" ON notification_logs;
DROP POLICY IF EXISTS "user_notification_logs_select_own" ON notification_logs;
DROP POLICY IF EXISTS "user_notification_logs_insert_own" ON notification_logs;
DROP POLICY IF EXISTS "service_role_all_access" ON notification_logs;

-- ============================================
-- STEP 3: ENABLE RLS ON ALL TABLES
-- ============================================

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 4: CREATE NEW POLICIES FOR user_profiles
-- ============================================

-- For user_profiles, the 'id' column IS the user's auth.uid()
CREATE POLICY "user_profiles_select_own"
ON user_profiles FOR SELECT
TO authenticated
USING (auth.uid() = id);

CREATE POLICY "user_profiles_insert_own"
ON user_profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

CREATE POLICY "user_profiles_update_own"
ON user_profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- ============================================
-- STEP 5: CREATE NEW POLICIES FOR user_devices
-- ============================================

-- For user_devices, we check user_id column
CREATE POLICY "user_devices_select_own"
ON user_devices FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "user_devices_insert_own"
ON user_devices FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_devices_update_own"
ON user_devices FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_devices_delete_own"
ON user_devices FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ============================================
-- STEP 6: CREATE NEW POLICIES FOR user_locations
-- ============================================

-- For user_locations, we check user_id column
CREATE POLICY "user_locations_select_own"
ON user_locations FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "user_locations_insert_own"
ON user_locations FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_locations_update_own"
ON user_locations FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ============================================
-- STEP 7: CREATE NEW POLICIES FOR notification_logs
-- ============================================

-- For notification_logs, we check user_id column
CREATE POLICY "notification_logs_select_own"
ON notification_logs FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "notification_logs_insert_own"
ON notification_logs FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- ============================================
-- STEP 8: ADD SERVICE ROLE POLICIES (for edge functions)
-- ============================================

-- Service role can access all data (needed for edge functions and cron jobs)
CREATE POLICY "service_role_user_profiles"
ON user_profiles FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

CREATE POLICY "service_role_user_devices"
ON user_devices FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

CREATE POLICY "service_role_user_locations"
ON user_locations FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

CREATE POLICY "service_role_notification_logs"
ON notification_logs FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================
-- STEP 9: VERIFY ALL POLICIES
-- ============================================

SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename IN ('user_profiles', 'user_devices', 'user_locations', 'notification_logs')
ORDER BY tablename, policyname;

-- ============================================
-- STEP 10: CHECK AUTH.USERS FOR EXISTING USERS
-- ============================================

SELECT id, email, created_at, last_sign_in_at
FROM auth.users
ORDER BY created_at DESC;

-- ============================================
-- STEP 11: MANUAL TEST INSERT (if needed)
-- Uncomment and replace YOUR_USER_ID with actual UUID from above query
-- ============================================

/*
-- Test inserting a user profile manually
INSERT INTO user_profiles (id, email, skin_type, uv_threshold, notification_enabled, smart_intervals_enabled, location_tracking_enabled)
VALUES (
    'YOUR_USER_ID'::uuid,
    'test@example.com',
    'Type II',
    6,
    true,
    true,
    true
);

-- Check if it worked
SELECT * FROM user_profiles;
*/

-- ============================================
-- TROUBLESHOOTING: Check what auth.uid() returns
-- ============================================

-- This function helps debug what auth.uid() returns
CREATE OR REPLACE FUNCTION public.debug_auth_uid()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT auth.uid();
$$;

-- Grant access to the debug function
GRANT EXECUTE ON FUNCTION public.debug_auth_uid() TO authenticated;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
SELECT 'RLS policies have been reset and recreated successfully!' as status;
