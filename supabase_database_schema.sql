-- =====================================================
-- Time to Burn - Supabase Database Schema
-- Run this in Supabase Dashboard → SQL Editor
-- =====================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. USER PROFILES TABLE (Extended user data)
-- =====================================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2. USER LOCATIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS user_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    altitude DOUBLE PRECISION DEFAULT 0,
    location_name TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 3. UV MONITORING DATA TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS uv_monitoring_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    location_id UUID REFERENCES user_locations(id) ON DELETE CASCADE,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    base_uv_index INTEGER NOT NULL,
    adjusted_uv_index INTEGER NOT NULL,
    risk_score DOUBLE PRECISION NOT NULL,
    risk_level TEXT NOT NULL,
    environmental_factors JSONB NOT NULL,
    risk_factors JSONB,
    recommendations JSONB,
    cloud_cover DOUBLE PRECISION,
    cloud_condition TEXT,
    time_to_burn INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 4. USER PREFERENCES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    uv_change_threshold INTEGER DEFAULT 2,
    minimum_risk_level TEXT DEFAULT 'moderate',
    notification_enabled BOOLEAN DEFAULT true,
    widget_update_interval INTEGER DEFAULT 1800, -- 30 minutes in seconds
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 5. NOTIFICATION HISTORY TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS notification_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    notification_type TEXT NOT NULL,
    message TEXT NOT NULL,
    uv_data JSONB,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    delivered BOOLEAN DEFAULT false
);

-- =====================================================
-- 6. UV CALCULATION CACHE TABLE (For performance)
-- =====================================================
CREATE TABLE IF NOT EXISTS uv_calculation_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    location_hash TEXT NOT NULL UNIQUE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    altitude DOUBLE PRECISION NOT NULL,
    calculation_result JSONB NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- User locations indexes
CREATE INDEX IF NOT EXISTS idx_user_locations_user_id ON user_locations(user_id);
CREATE INDEX IF NOT EXISTS idx_user_locations_active ON user_locations(is_active);

-- UV monitoring data indexes
CREATE INDEX IF NOT EXISTS idx_uv_monitoring_user_id ON uv_monitoring_data(user_id);
CREATE INDEX IF NOT EXISTS idx_uv_monitoring_recorded_at ON uv_monitoring_data(recorded_at);
CREATE INDEX IF NOT EXISTS idx_uv_monitoring_location_id ON uv_monitoring_data(location_id);

-- User preferences indexes
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_preferences(user_id);

-- Notification history indexes
CREATE INDEX IF NOT EXISTS idx_notification_history_user_id ON notification_history(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_history_delivered ON notification_history(delivered);
CREATE INDEX IF NOT EXISTS idx_notification_history_sent_at ON notification_history(sent_at);

-- UV calculation cache indexes
CREATE INDEX IF NOT EXISTS idx_uv_calculation_cache_location_hash ON uv_calculation_cache(location_hash);
CREATE INDEX IF NOT EXISTS idx_uv_calculation_cache_expires_at ON uv_calculation_cache(expires_at);

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE uv_monitoring_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE uv_calculation_cache ENABLE ROW LEVEL SECURITY;

-- User profiles policies
CREATE POLICY "Users can view own profile" ON user_profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON user_profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- User locations policies
CREATE POLICY "Users can view own locations" ON user_locations
    FOR ALL USING (auth.uid() = user_id);

-- UV monitoring data policies
CREATE POLICY "Users can view own UV data" ON uv_monitoring_data
    FOR ALL USING (auth.uid() = user_id);

-- User preferences policies
CREATE POLICY "Users can view own preferences" ON user_preferences
    FOR ALL USING (auth.uid() = user_id);

-- Notification history policies
CREATE POLICY "Users can view own notifications" ON notification_history
    FOR ALL USING (auth.uid() = user_id);

-- UV calculation cache policies (read-only for all authenticated users)
CREATE POLICY "Authenticated users can read UV cache" ON uv_calculation_cache
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert UV cache" ON uv_calculation_cache
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- =====================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to tables with updated_at
CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON user_profiles 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_locations_updated_at 
    BEFORE UPDATE ON user_locations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_preferences_updated_at 
    BEFORE UPDATE ON user_preferences 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- FUNCTIONS FOR DATA MANAGEMENT
-- =====================================================

-- Function to get latest UV data for a user
CREATE OR REPLACE FUNCTION get_latest_uv_data(user_uuid UUID)
RETURNS TABLE (
    id UUID,
    adjusted_uv_index INTEGER,
    risk_score DOUBLE PRECISION,
    risk_level TEXT,
    recorded_at TIMESTAMP WITH TIME ZONE,
    time_to_burn INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        umd.id,
        umd.adjusted_uv_index,
        umd.risk_score,
        umd.risk_level,
        umd.recorded_at,
        umd.time_to_burn
    FROM uv_monitoring_data umd
    WHERE umd.user_id = user_uuid
    ORDER BY umd.recorded_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean up expired UV cache entries
CREATE OR REPLACE FUNCTION cleanup_expired_uv_cache()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM uv_calculation_cache 
    WHERE expires_at < NOW();
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- SCHEDULED TASKS (Using pg_cron if available)
-- =====================================================

-- Note: pg_cron extension needs to be enabled by Supabase admin
-- This is for reference - you may need to use edge functions instead

-- Clean up expired UV cache entries every hour
-- SELECT cron.schedule('cleanup-uv-cache', '0 * * * *', 'SELECT cleanup_expired_uv_cache();');

-- =====================================================
-- SAMPLE DATA FOR TESTING (Optional)
-- =====================================================

-- Insert sample user preferences (will be created when user signs up)
-- INSERT INTO user_preferences (user_id, uv_change_threshold, minimum_risk_level, notification_enabled, widget_update_interval)
-- VALUES ('00000000-0000-0000-0000-000000000000', 2, 'moderate', true, 1800);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check if tables were created successfully
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('user_profiles', 'user_locations', 'uv_monitoring_data', 'user_preferences', 'notification_history', 'uv_calculation_cache');

-- Check if RLS is enabled
-- SELECT schemaname, tablename, rowsecurity FROM pg_tables WHERE tablename IN ('user_profiles', 'user_locations', 'uv_monitoring_data', 'user_preferences', 'notification_history', 'uv_calculation_cache');

-- Check if policies were created
-- SELECT schemaname, tablename, policyname FROM pg_policies WHERE tablename IN ('user_profiles', 'user_locations', 'uv_monitoring_data', 'user_preferences', 'notification_history', 'uv_calculation_cache');

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

-- This schema is now ready for the Time to Burn app!
-- Next steps:
-- 1. Configure authentication providers in Supabase Dashboard
-- 2. Test the authentication flow
-- 3. Start using the SupabaseService in your iOS app 