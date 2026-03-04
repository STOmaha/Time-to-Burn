import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendBatchAPNsNotifications, createUVThresholdNotification, createSafeUVNotification } from '../_shared/apns.ts';

/**
 * Location Update Edge Function
 * 
 * Called by the app when:
 * 1. User moves significantly (>5km)
 * 2. UV data is synced to backend
 * 
 * This function:
 * - Receives location and UV data
 * - Checks if UV crossed threshold
 * - Sends immediate notification if needed
 * - Returns recommended sync interval
 */

interface LocationUpdateRequest {
  userId: string;
  latitude: number;
  longitude: number;
  locationName?: string;
  currentUV: number;
  adjustedUV: number;
  environmentalFactors: any;
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
    console.log('📍 [Location Update] Processing location update...');

    // Parse request body
    const body: LocationUpdateRequest = await req.json();
    
    // Validate required fields
    if (!body.userId || body.latitude === undefined || body.longitude === undefined) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: userId, latitude, longitude' }),
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

    // Get user profile with threshold
    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('uv_threshold, notification_enabled, smart_intervals_enabled')
      .eq('id', body.userId)
      .single();

    if (profileError || !profile) {
      throw new Error(`Failed to fetch user profile: ${profileError?.message}`);
    }

    // Get user's last location to check previous UV state
    const { data: lastLocation, error: lastLocationError } = await supabase
      .from('user_locations')
      .select('current_uv_index, adjusted_uv_index, last_notified_at')
      .eq('user_id', body.userId)
      .order('updated_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    const threshold = profile.uv_threshold;
    const currentUV = body.adjustedUV || body.currentUV;
    const previousUV = lastLocation?.adjusted_uv_index || lastLocation?.current_uv_index;

    // Check if UV crossed threshold
    const nowAboveThreshold = currentUV >= threshold;
    const wasAboveThreshold = previousUV !== null && previousUV !== undefined && previousUV >= threshold;
    const thresholdCrossed = nowAboveThreshold !== wasAboveThreshold;

    console.log(`📊 [Location Update] User ${body.userId}: UV ${currentUV} vs threshold ${threshold}`);
    console.log(`   Previous UV: ${previousUV}, Crossed: ${thresholdCrossed}`);

    let notificationSent = false;

    // Send notification if threshold crossed and notifications enabled
    if (thresholdCrossed && profile.notification_enabled) {
      // Check rate limiting (max 1 notification per hour)
      const lastNotified = lastLocation?.last_notified_at ? new Date(lastLocation.last_notified_at) : null;
      const hoursSinceLastNotification = lastNotified
        ? (Date.now() - lastNotified.getTime()) / (1000 * 60 * 60)
        : Infinity;

      if (hoursSinceLastNotification >= 1) {
        // Get user's active devices
        const { data: devices, error: devicesError } = await supabase
          .from('user_devices')
          .select('device_token')
          .eq('user_id', body.userId)
          .eq('is_active', true)
          .eq('platform', 'ios');

        if (!devicesError && devices && devices.length > 0) {
          // Get APNs configuration
          const apnsConfig = {
            keyId: Deno.env.get('APNS_KEY_ID')!,
            teamId: Deno.env.get('APNS_TEAM_ID')!,
            keyFile: Deno.env.get('APNS_KEY_FILE')!,
            bundleId: Deno.env.get('APNS_BUNDLE_ID')!,
            production: Deno.env.get('APNS_PRODUCTION') === 'true',
          };

          // Create notification
          const notification = nowAboveThreshold
            ? createUVThresholdNotification(currentUV, threshold, body.locationName || 'your location')
            : createSafeUVNotification(currentUV, threshold, body.locationName || 'your location');

          // Send notifications
          const deviceTokens = devices.map(d => d.device_token);
          const result = await sendBatchAPNsNotifications(deviceTokens, notification, apnsConfig);

          if (result.successful > 0) {
            notificationSent = true;

            // Log notification
            await supabase.from('notification_logs').insert({
              user_id: body.userId,
              notification_type: nowAboveThreshold ? 'threshold_exceeded' : 'threshold_safe',
              uv_index: currentUV,
              threshold: threshold,
              latitude: body.latitude,
              longitude: body.longitude,
            });

            console.log(`✅ [Location Update] Sent notification to user ${body.userId}`);
          }
        }
      } else {
        console.log(`⏭️  [Location Update] Rate limit: Last notified ${hoursSinceLastNotification.toFixed(1)}h ago`);
      }
    }

    // Calculate recommended sync interval based on UV proximity to threshold
    const recommendedInterval = calculateSyncInterval(currentUV, threshold, profile.smart_intervals_enabled);

    // Update user location in database (includes last_notified_at if notification was sent)
    const updateData: any = {
      latitude: body.latitude,
      longitude: body.longitude,
      location_name: body.locationName,
      current_uv_index: body.currentUV,
      adjusted_uv_index: body.adjustedUV,
      environmental_factors: body.environmentalFactors,
      updated_at: new Date().toISOString(),
    };

    if (notificationSent) {
      updateData.last_notified_at = new Date().toISOString();
    }

    // Try to update existing location record, or insert new one
    const { error: updateError } = await supabase
      .from('user_locations')
      .upsert(
        { user_id: body.userId, ...updateData },
        { onConflict: 'user_id' }
      );

    if (updateError) {
      console.error(`⚠️  [Location Update] Failed to update location:`, updateError);
    }

    const response = {
      success: true,
      notificationSent,
      thresholdCrossed,
      recommendedSyncInterval: recommendedInterval,
      currentUV,
      threshold,
      timestamp: new Date().toISOString(),
    };

    console.log(`✅ [Location Update] Complete for user ${body.userId}`);

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('❌ [Location Update] Error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

/**
 * Calculate recommended sync interval based on UV proximity to threshold
 * Returns interval in seconds
 */
function calculateSyncInterval(currentUV: number, threshold: number, smartIntervalsEnabled: boolean): number {
  if (!smartIntervalsEnabled) {
    return 3600; // 1 hour default
  }

  const difference = Math.abs(currentUV - threshold);

  if (difference === 0) {
    return 900; // 15 minutes - at threshold
  } else if (difference <= 1) {
    return 1800; // 30 minutes - very close
  } else if (difference <= 3) {
    return 3600; // 1 hour - close
  } else {
    return 7200; // 2 hours - far
  }
}


