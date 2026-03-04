# Supabase Integration Guide

## Overview

Time to Burn now uses Supabase as its backend to provide:
- **Server-side UV monitoring** with smart interval checking
- **Location-based updates** when user moves significantly (>5km)
- **Push notifications** when UV crosses user's threshold
- **User authentication** with Sign in with Apple and email/password
- **Secure device token management** for APNs

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Configuration](#configuration)
3. [Database Schema](#database-schema)
4. [Edge Functions](#edge-functions)
5. [Testing](#testing)
6. [Troubleshooting](#troubleshooting)
7. [Architecture](#architecture)

---

## Initial Setup

### Step 1: Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com) and sign up/login
2. Click "New Project"
3. Choose or create an organization
4. Set project details:
   - **Name**: `time-to-burn-backend`
   - **Database Password**: Generate and save securely
   - **Region**: Choose closest to your target users (e.g., `us-west-1`)
5. Wait 2-3 minutes for project provisioning

### Step 2: Get API Credentials

1. Go to **Project Settings > API**
2. Copy and save these credentials:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **Project API keys**:
     - `anon` (public) key - for client app
     - `service_role` key - for Edge Functions only

### Step 3: Configure Database

1. Go to **SQL Editor** in Supabase Dashboard
2. Create a new query
3. Copy and paste the SQL from the [Database Schema](#database-schema) section below
4. Click "Run" to execute

### Step 4: Install Supabase CLI

```bash
npm install -g supabase
```

### Step 5: Link Project

```bash
cd "/Users/steven/Library/Mobile Documents/com~apple~CloudDocs/Projects/Coding/Time to Burn"
supabase link --project-ref YOUR_PROJECT_REF
```

Get `YOUR_PROJECT_REF` from Project Settings > General > Reference ID

---

## Configuration

### iOS App Configuration

1. Open `Time to Burn/Config/SupabaseConfig.swift`
2. Replace placeholders with your credentials:

```swift
struct SupabaseConfig {
    static let projectURL = "https://YOUR_PROJECT_ID.supabase.co"
    static let anonKey = "YOUR_ANON_KEY_HERE"
}
```

3. Build and run the app - you should see initialization logs in console

### APNs Configuration

#### 1. Get APNs Credentials from Apple Developer

1. Go to [Apple Developer](https://developer.apple.com/account)
2. **Certificates, Identifiers & Profiles > Keys**
3. Click "+" to create a new key
4. Name: `TimeToBurn APNs Key`
5. Enable **Apple Push Notifications service (APNs)**
6. Click "Continue" and "Register"
7. **Download the .p8 file** (you can only download once!)
8. Save the **Key ID** and **Team ID**

#### 2. Configure APNs Secrets in Supabase

```bash
# Read the .p8 file content
cat /path/to/AuthKey_XXXXX.p8

# Set secrets in Supabase
supabase secrets set APNS_KEY_ID=YOUR_KEY_ID
supabase secrets set APNS_TEAM_ID=YOUR_TEAM_ID
supabase secrets set APNS_KEY_FILE="$(cat /path/to/AuthKey_XXXXX.p8)"
supabase secrets set APNS_BUNDLE_ID=com.yourapp.timetoburn
supabase secrets set APNS_PRODUCTION=false  # true for production
```

---

## Database Schema

Execute this SQL in Supabase SQL Editor:

```sql
-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- User profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    skin_type TEXT DEFAULT 'Type II',
    uv_threshold INT DEFAULT 6,
    notification_enabled BOOLEAN DEFAULT true,
    smart_intervals_enabled BOOLEAN DEFAULT true,
    location_tracking_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User devices table
CREATE TABLE IF NOT EXISTS user_devices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios',
    app_version TEXT,
    device_model TEXT,
    os_version TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User location history table
CREATE TABLE IF NOT EXISTS user_locations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    location_name TEXT,
    current_uv_index INT,
    adjusted_uv_index INT,
    environmental_factors JSONB,
    last_notified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Notification log table
CREATE TABLE IF NOT EXISTS notification_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    notification_type TEXT NOT NULL,
    uv_index INT,
    threshold INT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_token ON user_devices(device_token);
CREATE INDEX IF NOT EXISTS idx_user_devices_active ON user_devices(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_user_locations_user_id ON user_locations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_locations_updated_at ON user_locations(updated_at);
CREATE INDEX IF NOT EXISTS idx_notification_logs_user_id ON notification_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_sent_at ON notification_logs(sent_at);

-- Enable Row Level Security (RLS)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own profile" ON user_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON user_profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON user_profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can view own devices" ON user_devices FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own devices" ON user_devices FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own devices" ON user_devices FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own devices" ON user_devices FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own locations" ON user_locations FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own locations" ON user_locations FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own locations" ON user_locations FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own notification logs" ON notification_logs FOR SELECT USING (auth.uid() = user_id);

-- Functions for automated updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_devices_updated_at BEFORE UPDATE ON user_devices 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_locations_updated_at BEFORE UPDATE ON user_locations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

---

## Edge Functions

### Deploy Edge Functions

```bash
# Deploy all functions
supabase functions deploy uv-monitor
supabase functions deploy location-update
supabase functions deploy register-device
```

### Setup Cron Job for UV Monitoring

1. Go to **Database > Extensions** in Supabase Dashboard
2. Enable `pg_cron` extension
3. Go to **SQL Editor** and run:

```sql
-- Run UV monitor every 30 minutes
SELECT cron.schedule(
    'uv-monitor-job',
    '*/30 * * * *',  -- Every 30 minutes
    $$
    SELECT net.http_post(
        url:='https://YOUR_PROJECT_URL.supabase.co/functions/v1/uv-monitor',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb
    );
    $$
);
```

Replace:
- `YOUR_PROJECT_URL` with your Supabase project URL
- `YOUR_SERVICE_ROLE_KEY` with your service role key

### Edge Function URLs

Once deployed, your functions are available at:

- **UV Monitor**: `https://YOUR_PROJECT_URL.supabase.co/functions/v1/uv-monitor`
- **Location Update**: `https://YOUR_PROJECT_URL.supabase.co/functions/v1/location-update`
- **Register Device**: `https://YOUR_PROJECT_URL.supabase.co/functions/v1/register-device`

---

## Testing

### 1. Test Authentication

```swift
// In your app, try signing in
Task {
    try await AuthenticationManager.shared.signInWithEmail(
        email: "test@example.com",
        password: "password123"
    )
}
```

Check console for:
- ✅ `[AuthenticationManager] ✅ Email Sign In successful`
- ✅ `[SupabaseService] ✅ Existing session found`

### 2. Test Location Sync

1. Run the app
2. Grant location permissions
3. Check console for:
   - ✅ `[BackgroundSyncService] Starting sync...`
   - ✅ `[SupabaseService] Location data synced successfully`

### 3. Test Push Notifications

1. Set a low UV threshold (e.g., 3) in app settings
2. Wait for UV to cross threshold
3. Check Supabase Dashboard:
   - **Table Editor > notification_logs** - should show new entry
   - **Edge Functions > Logs** - check for notification send logs

### 4. Verify Database

```sql
-- Check user profiles
SELECT * FROM user_profiles;

-- Check device registrations
SELECT * FROM user_devices WHERE is_active = true;

-- Check location updates
SELECT * FROM user_locations ORDER BY updated_at DESC LIMIT 10;

-- Check notification logs
SELECT * FROM notification_logs ORDER BY sent_at DESC LIMIT 10;
```

---

## Troubleshooting

### Issue: "Configuration not set" error

**Problem**: SupabaseConfig.swift still has placeholder values

**Solution**:
1. Open `Time to Burn/Config/SupabaseConfig.swift`
2. Replace `YOUR_SUPABASE_PROJECT_URL` and `YOUR_SUPABASE_ANON_KEY` with real values
3. Rebuild the app

### Issue: Push notifications not sending

**Problem**: APNs credentials not configured or invalid

**Solution**:
1. Verify APNs secrets are set:
   ```bash
   supabase secrets list
   ```
2. Check Edge Function logs:
   ```bash
   supabase functions logs uv-monitor
   ```
3. Ensure device token is registered:
   ```sql
   SELECT * FROM user_devices WHERE is_active = true;
   ```

### Issue: "Row Level Security" error

**Problem**: RLS policies preventing access

**Solution**:
1. Verify user is authenticated
2. Check RLS policies in Supabase Dashboard
3. Ensure `auth.uid()` matches `user_id` in queries

### Issue: Location not syncing

**Problem**: BackgroundSyncService not triggering

**Solution**:
1. Check if user moved >5km (significant change threshold)
2. Verify time since last sync (smart intervals)
3. Check console logs:
   ```
   [BackgroundSyncService] Sync not needed yet
   ```

### Issue: Cron job not running

**Problem**: pg_cron extension or job not configured

**Solution**:
1. Verify `pg_cron` is enabled in Extensions
2. Check cron job status:
   ```sql
   SELECT * FROM cron.job;
   ```
3. Check cron logs:
   ```sql
   SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;
   ```

---

## Architecture

### Data Flow

```
┌─────────────┐
│   iOS App   │
└──────┬──────┘
       │
       │ 1. Fetch UV from WeatherKit
       │ 2. Calculate environmental factors
       │ 3. Detect location changes
       │
       ▼
┌──────────────────────┐
│ BackgroundSyncService│
└──────────┬───────────┘
           │
           │ Smart Sync (based on UV proximity)
           │
           ▼
┌────────────────────┐
│ SupabaseService    │
└──────────┬─────────┘
           │
           │ REST API
           │
           ▼
┌─────────────────────────┐
│ Supabase Backend        │
│                         │
│ ┌─────────────────────┐ │
│ │ user_locations      │ │
│ │ user_profiles       │ │
│ │ user_devices        │ │
│ │ notification_logs   │ │
│ └─────────────────────┘ │
│                         │
│ ┌─────────────────────┐ │
│ │ Edge Functions      │ │
│ │ - uv-monitor (cron) │ │
│ │ - location-update   │ │
│ │ - register-device   │ │
│ └─────────────────────┘ │
└───────────┬─────────────┘
            │
            │ APNs HTTP/2
            │
            ▼
    ┌──────────────┐
    │ Apple Push   │
    │ Notification │
    │ Service      │
    └──────┬───────┘
           │
           ▼
    ┌─────────────┐
    │  iOS Device │
    │ Notification│
    └─────────────┘
```

### Smart Interval Logic

The system uses smart intervals to balance accuracy with battery life:

| UV Proximity to Threshold | Sync Interval | Check Frequency |
|---------------------------|---------------|-----------------|
| At threshold (±0)         | 15 minutes    | Every 15 min    |
| Very close (±1)           | 30 minutes    | Every 30 min    |
| Close (±2-3)              | 1 hour        | Every hour      |
| Far (>3)                  | 2 hours       | Every 2 hours   |

### Notification Rate Limiting

- Maximum 1 notification per hour per user
- Prevents spam while ensuring timely alerts
- Configurable in Edge Functions

---

## Security Checklist

- [x] Supabase credentials in `.gitignore`
- [x] RLS policies enabled and tested
- [x] APNs credentials stored as secrets (not in code)
- [x] Service role key never exposed to client
- [x] Rate limiting implemented for notifications
- [x] User data encrypted at rest (Supabase default)
- [ ] Test with real users before production
- [ ] Monitor Edge Function logs regularly
- [ ] Set up alerts for Edge Function failures

---

## Support & Resources

- **Supabase Docs**: [https://supabase.com/docs](https://supabase.com/docs)
- **APNs Documentation**: [https://developer.apple.com/documentation/usernotifications](https://developer.apple.com/documentation/usernotifications)
- **Edge Functions Guide**: [https://supabase.com/docs/guides/functions](https://supabase.com/docs/guides/functions)

---

## Next Steps

1. Complete [Initial Setup](#initial-setup)
2. Deploy [Edge Functions](#edge-functions)
3. Run [Testing](#testing) procedures
4. Monitor logs and adjust intervals as needed
5. Gather user feedback on notification timing
6. Optimize based on usage patterns

---

Last updated: November 2025


