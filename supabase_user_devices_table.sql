-- Create user_devices table for push notification device tokens
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

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_token ON user_devices(device_token);
CREATE INDEX IF NOT EXISTS idx_user_devices_active ON user_devices(is_active) WHERE is_active = true;

-- Create unique constraint to prevent duplicate device tokens per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_devices_unique_user_token ON user_devices(user_id, device_token);

-- Enable Row Level Security (RLS)
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own devices" ON user_devices
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own devices" ON user_devices
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own devices" ON user_devices
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own devices" ON user_devices
    FOR DELETE USING (auth.uid() = user_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_user_devices_updated_at 
    BEFORE UPDATE ON user_devices 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Create function to get active devices for a user
CREATE OR REPLACE FUNCTION get_user_active_devices(user_uuid UUID)
RETURNS TABLE (
    device_token TEXT,
    platform TEXT,
    app_version TEXT,
    device_model TEXT,
    os_version TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ud.device_token,
        ud.platform,
        ud.app_version,
        ud.device_model,
        ud.os_version
    FROM user_devices ud
    WHERE ud.user_id = user_uuid 
    AND ud.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON user_devices TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_user_active_devices(UUID) TO anon, authenticated; 