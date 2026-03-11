import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendBatchAPNsNotifications, createUVThresholdNotification, createSafeUVNotification } from '../_shared/apns.ts';

/**
 * UV Monitor Edge Function
 * 
 * Scheduled function that runs periodically to:
 * 1. Check all users with location_tracking_enabled
 * 2. Compare their current UV index against their threshold
 * 3. Send push notifications when UV crosses threshold
 * 4. Implement smart intervals based on UV proximity to threshold
 */

interface UserLocationData {
  user_id: string;
  latitude: number;
  longitude: number;
  location_name: string;
  current_uv_index: number;
  adjusted_uv_index: number;
  last_notified_at: string | null;
  uv_threshold: number;
  notification_enabled: boolean;
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
    console.log('🌤️  [UV Monitor] Starting UV monitoring check...');

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get APNs configuration
    const apnsConfig = {
      keyId: Deno.env.get('APNS_KEY_ID')!,
      teamId: Deno.env.get('APNS_TEAM_ID')!,
      keyFile: Deno.env.get('APNS_KEY_FILE')!,
      bundleId: Deno.env.get('APNS_BUNDLE_ID')!,
      production: Deno.env.get('APNS_PRODUCTION') === 'true',
    };

    // Debug: Log config (sanitized)
    console.log(`🔧 [UV Monitor] APNs Config: keyId=${apnsConfig.keyId?.substring(0, 4) || 'MISSING'}..., teamId=${apnsConfig.teamId?.substring(0, 4) || 'MISSING'}..., bundleId=${apnsConfig.bundleId || 'MISSING'}, production=${apnsConfig.production}, keyFileLength=${apnsConfig.keyFile?.length || 0}`);

    // Query users with their latest location and preferences
    const { data: users, error: usersError } = await supabase
      .from('user_locations')
      .select(`
        user_id,
        latitude,
        longitude,
        location_name,
        current_uv_index,
        adjusted_uv_index,
        last_notified_at,
        user_profiles!inner (
          uv_threshold,
          notification_enabled,
          smart_intervals_enabled,
          location_tracking_enabled
        )
      `)
      .order('updated_at', { ascending: false });

    if (usersError) {
      throw new Error(`Failed to fetch users: ${usersError.message}`);
    }

    console.log(`📊 [UV Monitor] Found ${users?.length || 0} user locations to check`);

    let notificationsSent = 0;
    let usersProcessed = 0;
    const debugLog: string[] = [];

    // Process each user
    for (const userData of users || []) {
      const profile = userData.user_profiles;
      
      // Skip if user has disabled tracking or notifications
      if (!profile.location_tracking_enabled || !profile.notification_enabled) {
        continue;
      }

      usersProcessed++;

      const currentUV = userData.adjusted_uv_index ?? userData.current_uv_index;

      // Skip if UV data is NULL (app hasn't synced yet)
      if (currentUV === null || currentUV === undefined) {
        console.log(`⚠️  [UV Monitor] Skipping user ${userData.user_id} - UV data is NULL`);
        continue;
      }

      const threshold = profile.uv_threshold;
      const lastNotified = userData.last_notified_at ? new Date(userData.last_notified_at) : null;

      // Check if enough time has passed since last notification (rate limiting)
      const hoursSinceLastNotification = lastNotified
        ? (Date.now() - lastNotified.getTime()) / (1000 * 60 * 60)
        : Infinity;

      // Require at least 1 hour between notifications
      if (hoursSinceLastNotification < 1) {
        console.log(`⏭️  [UV Monitor] Skipping user ${userData.user_id} - notified ${hoursSinceLastNotification.toFixed(1)}h ago`);
        continue;
      }

      // Determine if notification should be sent
      const shouldNotify = await checkIfShouldNotify(
        currentUV,
        threshold,
        lastNotified,
        profile.smart_intervals_enabled
      );

      console.log(`🔍 [UV Monitor] User ${userData.user_id}: UV=${currentUV}, threshold=${threshold}, shouldNotify=${shouldNotify}`);
      debugLog.push(`User ${userData.user_id.substring(0, 8)}: UV=${currentUV}, threshold=${threshold}, shouldNotify=${shouldNotify}`);

      if (shouldNotify) {
        // Get user's active devices
        const { data: devices, error: devicesError } = await supabase
          .from('user_devices')
          .select('device_token')
          .eq('user_id', userData.user_id)
          .eq('is_active', true)
          .eq('platform', 'ios');

        if (devicesError) {
          console.log(`❌ [UV Monitor] Device query error for user ${userData.user_id}: ${devicesError.message}`);
          debugLog.push(`Device error: ${devicesError.message}`);
          continue;
        }

        if (!devices || devices.length === 0) {
          console.log(`⚠️  [UV Monitor] No active devices for user ${userData.user_id}`);
          debugLog.push(`No active devices found`);
          continue;
        }

        console.log(`📱 [UV Monitor] Found ${devices.length} device(s) for user ${userData.user_id}`);
        debugLog.push(`Found ${devices.length} device(s)`);

        // Determine notification type
        const notificationType = currentUV >= threshold ? 'high_uv' : 'safe_uv';
        const notification = currentUV >= threshold
          ? createUVThresholdNotification(currentUV, threshold, userData.location_name || 'your location')
          : createSafeUVNotification(currentUV, threshold, userData.location_name || 'your location');

        // Send notifications to all user's devices
        const deviceTokens = devices.map(d => d.device_token);
        console.log(`📤 [UV Monitor] Sending to tokens: ${deviceTokens.map(t => t.substring(0, 8) + '...').join(', ')}`);

        const result = await sendBatchAPNsNotifications(deviceTokens, notification, apnsConfig);
        console.log(`📊 [UV Monitor] APNs result: ${result.successful} successful, ${result.failed} failed`);
        debugLog.push(`APNs: ${result.successful} sent, ${result.failed} failed`);
        if (result.apnsIds && result.apnsIds.length > 0) {
          debugLog.push(`APNs IDs: ${result.apnsIds.join(', ')}`);
        }
        if (result.errors && result.errors.length > 0) {
          debugLog.push(`APNs errors: ${result.errors.join(', ')}`);
        }

        if (result.successful > 0) {
          notificationsSent += result.successful;

          // Log notification
          await supabase.from('notification_logs').insert({
            user_id: userData.user_id,
            notification_type: notificationType,
            uv_index: currentUV,
            threshold: threshold,
            latitude: userData.latitude,
            longitude: userData.longitude,
          });

          // Update last_notified_at
          await supabase
            .from('user_locations')
            .update({ last_notified_at: new Date().toISOString() })
            .eq('user_id', userData.user_id)
            .order('updated_at', { ascending: false })
            .limit(1);

          console.log(`✅ [UV Monitor] Notified user ${userData.user_id}: UV ${currentUV} vs threshold ${threshold}`);
        }
      }
    }

    const response = {
      success: true,
      usersProcessed,
      notificationsSent,
      timestamp: new Date().toISOString(),
      debug: debugLog,
      apnsConfig: {
        keyId: apnsConfig.keyId?.substring(0, 4) + '...',
        teamId: apnsConfig.teamId?.substring(0, 4) + '...',
        bundleId: apnsConfig.bundleId,
        production: apnsConfig.production,
        keyFileLength: apnsConfig.keyFile?.length || 0,
        keyFileStart: apnsConfig.keyFile?.substring(0, 30),
      },
    };

    console.log(`🎉 [UV Monitor] Complete: Processed ${usersProcessed} users, sent ${notificationsSent} notifications`);

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('❌ [UV Monitor] Error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

/**
 * Determine if notification should be sent based on UV levels and timing
 */
async function checkIfShouldNotify(
  currentUV: number,
  threshold: number,
  lastNotified: Date | null,
  smartIntervalsEnabled: boolean
): Promise<boolean> {
  // Always notify if UV crosses threshold (either way)
  const crossedThreshold = currentUV >= threshold;
  const wasAboveThreshold = lastNotified !== null; // Simplified - in production, track previous UV state

  // If this is the first check or threshold was crossed, notify
  if (!lastNotified || crossedThreshold !== wasAboveThreshold) {
    return true;
  }

  // Smart intervals: check more frequently when near threshold
  if (smartIntervalsEnabled) {
    const difference = Math.abs(currentUV - threshold);
    const hoursSinceLastCheck = lastNotified
      ? (Date.now() - lastNotified.getTime()) / (1000 * 60 * 60)
      : Infinity;

    // At threshold or ±1: check every 1 hour
    if (difference <= 1 && hoursSinceLastCheck >= 1) {
      return true;
    }

    // ±2-3: check every 2 hours
    if (difference <= 3 && hoursSinceLastCheck >= 2) {
      return true;
    }

    // Far from threshold: check every 4 hours
    if (hoursSinceLastCheck >= 4) {
      return true;
    }
  } else {
    // Without smart intervals, check every 2 hours
    const hoursSinceLastCheck = lastNotified
      ? (Date.now() - lastNotified.getTime()) / (1000 * 60 * 60)
      : Infinity;
      
    if (hoursSinceLastCheck >= 2) {
      return true;
    }
  }

  return false;
}


