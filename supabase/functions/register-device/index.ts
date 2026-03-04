import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { isValidDeviceToken } from '../_shared/apns.ts';

/**
 * Register Device Edge Function
 * 
 * Securely registers or updates device tokens for push notifications
 * 
 * This function:
 * - Validates device token format
 * - Upserts device into user_devices table
 * - Marks old tokens as inactive
 * - Returns registration status
 */

interface RegisterDeviceRequest {
  userId: string;
  deviceToken: string;
  platform?: string;
  appVersion?: string;
  deviceModel?: string;
  osVersion?: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('📱 [Register Device] Processing device registration...');

    // Parse request body
    const body: RegisterDeviceRequest = await req.json();

    // Validate required fields
    if (!body.userId || !body.deviceToken) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: userId, deviceToken' }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        }
      );
    }

    // Validate device token format
    if (!isValidDeviceToken(body.deviceToken)) {
      return new Response(
        JSON.stringify({ error: 'Invalid device token format' }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        }
      );
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Check if device already exists
    const { data: existingDevice, error: checkError } = await supabase
      .from('user_devices')
      .select('id, is_active')
      .eq('user_id', body.userId)
      .eq('device_token', body.deviceToken)
      .maybeSingle();

    if (checkError && checkError.code !== 'PGRST116') { // PGRST116 is "not found" which is fine
      throw new Error(`Failed to check existing device: ${checkError.message}`);
    }

    let deviceId: string;

    if (existingDevice) {
      // Device exists - update it
      console.log(`🔄 [Register Device] Updating existing device for user ${body.userId}`);

      const { data: updated, error: updateError } = await supabase
        .from('user_devices')
        .update({
          platform: body.platform || 'ios',
          app_version: body.appVersion,
          device_model: body.deviceModel,
          os_version: body.osVersion,
          is_active: true,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existingDevice.id)
        .select('id')
        .single();

      if (updateError) {
        throw new Error(`Failed to update device: ${updateError.message}`);
      }

      deviceId = updated.id;

    } else {
      // New device - insert it
      console.log(`✨ [Register Device] Registering new device for user ${body.userId}`);

      // First, mark all other devices for this user as inactive (optional - depends on your needs)
      // Uncomment if you want only one active device per user:
      /*
      await supabase
        .from('user_devices')
        .update({ is_active: false })
        .eq('user_id', body.userId);
      */

      const { data: inserted, error: insertError } = await supabase
        .from('user_devices')
        .insert({
          user_id: body.userId,
          device_token: body.deviceToken,
          platform: body.platform || 'ios',
          app_version: body.appVersion,
          device_model: body.deviceModel,
          os_version: body.osVersion,
          is_active: true,
        })
        .select('id')
        .single();

      if (insertError) {
        throw new Error(`Failed to insert device: ${insertError.message}`);
      }

      deviceId = inserted.id;
    }

    const response = {
      success: true,
      deviceId,
      message: existingDevice ? 'Device updated successfully' : 'Device registered successfully',
      timestamp: new Date().toISOString(),
    };

    console.log(`✅ [Register Device] Success for user ${body.userId}`);

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('❌ [Register Device] Error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});


