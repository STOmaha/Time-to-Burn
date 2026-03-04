-- ============================================
-- FIX USER PROFILES RLS AND TABLE STRUCTURE
-- Run this in Supabase SQL Editor
-- ============================================

-- Step 1: Check current table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'user_profiles'
ORDER BY ordinal_position;

-- Step 2: Drop ALL existing policies for user_profiles (with different possible names)
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_select_policy" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_insert_policy" ON user_profiles;
DROP POLICY IF EXISTS "user_profiles_update_policy" ON user_profiles;
DROP POLICY IF EXISTS "Enable read access for own profile" ON user_profiles;
DROP POLICY IF EXISTS "Enable insert for own profile" ON user_profiles;
DROP POLICY IF EXISTS "Enable update for own profile" ON user_profiles;

-- Step 3: Ensure RLS is enabled
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Step 4: Create new, properly named policies
-- IMPORTANT: For INSERT, we use 'id' because that's the column name in user_profiles
-- The user can only insert a row where the profile id matches their auth uid

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

-- Step 5: Also add service role access (for edge functions)
CREATE POLICY "service_role_all_access"
ON user_profiles FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Step 6: Verify policies are created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'user_profiles';

-- Step 7: Test insert (replace with your actual user ID from auth.users)
-- First, check what users exist in auth.users
SELECT id, email, created_at FROM auth.users;

-- Step 8: If you have a user ID, test manual insert (uncomment and run):
-- INSERT INTO user_profiles (id, email, skin_type, uv_threshold, notification_enabled, smart_intervals_enabled, location_tracking_enabled)
-- VALUES (
--     'YOUR_USER_ID_HERE'::uuid,
--     'user@example.com',
--     'Type II',
--     6,
--     true,
--     true,
--     true
-- );

-- Step 9: Check user_profiles after insert
SELECT * FROM user_profiles;

-- ============================================
-- DEBUGGING QUERIES
-- ============================================

-- Check if there are any constraint violations:
SELECT conname, contype, conrelid::regclass, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'user_profiles'::regclass;

-- Check foreign key relationship:
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM
    information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name='user_profiles';
