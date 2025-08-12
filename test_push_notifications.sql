-- 🧪 Push Notification Test Script
-- Run these queries in Supabase SQL Editor to test your setup

-- 1. Check if user_devices table exists and has data
SELECT 
    'user_devices table check' as test_name,
    COUNT(*) as device_count,
    COUNT(DISTINCT user_id) as unique_users
FROM user_devices;

-- 2. Check if notification_history table exists
SELECT 
    'notification_history table check' as test_name,
    COUNT(*) as notification_count
FROM notification_history;

-- 3. Get your user ID (replace 'your-email@example.com' with your actual email)
SELECT 
    'user lookup' as test_name,
    id as user_id,
    email
FROM auth.users 
WHERE email = 'your-email@example.com';

-- 4. Check if you have registered devices (replace USER_ID with your actual user ID)
SELECT 
    'device registration check' as test_name,
    device_token,
    platform,
    app_version,
    is_active,
    created_at
FROM user_devices 
WHERE user_id = 'USER_ID'::uuid;

-- 5. Test sending a UV alert notification (replace USER_ID with your actual user ID)
-- WARNING: This will send an actual notification to your device!
SELECT 
    'UV alert test' as test_name,
    send_uv_alert_notification(
        'USER_ID'::uuid,
        10,
        'Test Location'
    ) as result;

-- 6. Test sending a timer reminder (replace USER_ID with your actual user ID)
-- WARNING: This will send an actual notification to your device!
SELECT 
    'Timer reminder test' as test_name,
    send_timer_reminder_notification(
        'USER_ID'::uuid,
        5
    ) as result;

-- 7. Check recent notification history
SELECT 
    'notification history' as test_name,
    title,
    body,
    notification_type,
    success,
    sent_at
FROM notification_history 
ORDER BY sent_at DESC 
LIMIT 5;

-- 8. Test custom notification (replace USER_ID with your actual user ID)
-- WARNING: This will send an actual notification to your device!
SELECT 
    'Custom notification test' as test_name,
    send_push_notification_to_user(
        'USER_ID'::uuid,
        'Test Notification',
        'This is a test notification from Supabase!',
        '{"type": "test", "timestamp": ' || extract(epoch from now()) || '}'::jsonb
    ) as result;

-- 9. Check database functions exist
SELECT 
    'function existence check' as test_name,
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN (
    'send_push_notification_to_user',
    'send_uv_alert_notification',
    'send_timer_reminder_notification',
    'send_daily_summary_notification',
    'send_sunscreen_reminder_notification'
);

-- 10. Check table structure
SELECT 
    'table structure check' as test_name,
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name IN ('user_devices', 'notification_history')
ORDER BY table_name, ordinal_position; 