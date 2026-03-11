---
name: trigger-uv-check
description: Manually trigger UV monitor edge function and check results
---

# Trigger UV Check

Manually trigger the uv-monitor edge function for testing push notifications.

## Prerequisites
- `SUPABASE_SERVICE_ROLE_KEY` environment variable set
- Supabase CLI installed (`npm install -g supabase`)

## Steps

### 1. Check current user state
```bash
# Run diagnostic query to see notification eligibility
supabase db execute --project-ref svkrlwzwnirhgbyardze "
SELECT
  up.id as user_id,
  ul.current_uv_index,
  ul.adjusted_uv_index,
  up.uv_threshold,
  up.notification_enabled,
  ul.last_notified_at,
  CASE
    WHEN up.notification_enabled = false THEN 'Notifications disabled'
    WHEN ul.current_uv_index IS NULL AND ul.adjusted_uv_index IS NULL THEN 'UV data NULL'
    WHEN COALESCE(ul.adjusted_uv_index, ul.current_uv_index) < up.uv_threshold THEN 'UV below threshold'
    WHEN ul.last_notified_at > NOW() - INTERVAL '1 hour' THEN 'Rate limited'
    ELSE 'SHOULD SEND'
  END as status
FROM user_profiles up
LEFT JOIN user_locations ul ON up.id = ul.user_id
WHERE up.notification_enabled = true;
"
```

### 2. Reset rate limiting (optional, for testing)
```bash
supabase db execute --project-ref svkrlwzwnirhgbyardze "
UPDATE user_locations
SET last_notified_at = NULL
WHERE user_id = 'd8fc98fb-c646-4afb-a8d1-d9335a7d1a5c';
"
```

### 3. Set test UV value above threshold (optional)
```bash
supabase db execute --project-ref svkrlwzwnirhgbyardze "
UPDATE user_locations
SET current_uv_index = 8, adjusted_uv_index = 9, updated_at = NOW()
WHERE user_id = 'd8fc98fb-c646-4afb-a8d1-d9335a7d1a5c';
"
```

### 4. Trigger the Edge Function
```bash
curl -s -X POST 'https://svkrlwzwnirhgbyardze.supabase.co/functions/v1/uv-monitor' \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H 'Content-Type: application/json' \
  -d '{}' | jq .
```

### 5. Check function logs
```bash
supabase functions logs uv-monitor --project-ref svkrlwzwnirhgbyardze --limit 20
```

## Expected Output

Success:
```json
{
  "success": true,
  "usersProcessed": 1,
  "notificationsSent": 1,
  "timestamp": "2026-03-10T..."
}
```

If `notificationsSent: 0`, check logs for:
- `Skipping user ... - UV data is NULL` - App needs to sync location
- `Skipping user ... - notified Xh ago` - Rate limited
- `No active devices for user` - Device token missing
- APNs errors (403, 400, 410) - Check APNs secrets
