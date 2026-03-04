import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendAPNsNotification } from '../_shared/apns.ts';

/**
 * Smart Refresh Edge Function
 *
 * Intelligently decides when to wake user devices for data refresh.
 * Considers:
 * - Time since last update
 * - UV proximity to user's threshold
 * - Time of day (more frequent during daylight)
 * - Location staleness
 *
 * Sends SILENT push notifications to wake the app without disturbing the user.
 */

interface UserData {
  user_id: string;
  latitude: number;
  longitude: number;
  current_uv_index: number;
  adjusted_uv_index: number;
  updated_at: string;
  last_notified_at: string | null;
  uv_threshold: number;
  notification_enabled: boolean;
  smart_intervals_enabled: boolean;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('🔄 [Smart Refresh] Starting intelligent refresh check...');

    // Initialize Supabase
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

    // Get current hour to adjust refresh frequency
    const currentHour = new Date().getHours();
    const isDaytime = currentHour >= 6 && currentHour <= 20;

    console.log(`🕐 [Smart Refresh] Current hour: ${currentHour}, Daytime: ${isDaytime}`);

    // Query users with their location data and preferences
    const { data: users, error: usersError } = await supabase
      .from('user_locations')
      .select(`
        user_id,
        latitude,
        longitude,
        current_uv_index,
        adjusted_uv_index,
        updated_at,
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

    console.log(`📊 [Smart Refresh] Found ${users?.length || 0} users to evaluate`);

    let refreshesSent = 0;
    let skipped = 0;

    // Process each user
    for (const userData of users || []) {
      const profile = userData.user_profiles;

      // Skip if notifications disabled
      if (!profile.notification_enabled || !profile.location_tracking_enabled) {
        skipped++;
        continue;
      }

      // Calculate if refresh is needed
      const shouldRefresh = await evaluateRefreshNeed(
        userData,
        profile,
        isDaytime
      );

      if (shouldRefresh.needed) {
        // Get user's devices
        const { data: devices } = await supabase
          .from('user_devices')
          .select('device_token')
          .eq('user_id', userData.user_id)
          .eq('is_active', true)
          .eq('platform', 'ios');

        if (devices && devices.length > 0) {
          // Send silent push to each device
          for (const device of devices) {
            const success = await sendSilentPush(
              device.device_token,
              shouldRefresh.reason,
              apnsConfig
            );

            if (success) {
              refreshesSent++;
            }
          }

          // Update last_notified_at to prevent rapid re-sends
          await supabase
            .from('user_locations')
            .update({ last_notified_at: new Date().toISOString() })
            .eq('user_id', userData.user_id);

          console.log(`✅ [Smart Refresh] Sent refresh to user ${userData.user_id.substring(0, 8)}... (reason: ${shouldRefresh.reason})`);
        }
      } else {
        skipped++;
      }
    }

    const response = {
      success: true,
      refreshesSent,
      skipped,
      isDaytime,
      timestamp: new Date().toISOString(),
    };

    console.log(`🎉 [Smart Refresh] Complete: ${refreshesSent} refreshes sent, ${skipped} skipped`);

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('❌ [Smart Refresh] Error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

/**
 * Evaluate if a user needs a data refresh
 */
async function evaluateRefreshNeed(
  userData: any,
  profile: any,
  isDaytime: boolean
): Promise<{ needed: boolean; reason: string }> {
  const now = Date.now();
  const lastUpdate = new Date(userData.updated_at).getTime();
  const lastNotified = userData.last_notified_at
    ? new Date(userData.last_notified_at).getTime()
    : 0;

  const minutesSinceUpdate = (now - lastUpdate) / (1000 * 60);
  const minutesSinceNotified = (now - lastNotified) / (1000 * 60);

  const currentUV = userData.adjusted_uv_index || userData.current_uv_index || 0;
  const threshold = profile.uv_threshold || 6;
  const uvProximity = Math.abs(currentUV - threshold);

  // Debug logging
  console.log(`  📍 User ${userData.user_id.substring(0, 8)}...: UV=${currentUV}, threshold=${threshold}, proximity=${uvProximity}, minutesSinceUpdate=${minutesSinceUpdate.toFixed(1)}`);

  // Rule 1: Don't refresh if we just did (minimum 10 minutes)
  if (minutesSinceNotified < 10) {
    return { needed: false, reason: 'recently_refreshed' };
  }

  // Rule 2: Nighttime - less frequent updates (every 2 hours max)
  if (!isDaytime) {
    if (minutesSinceUpdate < 120) {
      return { needed: false, reason: 'nighttime_cooldown' };
    }
    return { needed: true, reason: 'nighttime_refresh' };
  }

  // Rule 3: Smart intervals based on UV proximity to threshold
  if (profile.smart_intervals_enabled) {
    // At or very close to threshold - refresh every 15 minutes
    if (uvProximity <= 1 && minutesSinceUpdate >= 15) {
      return { needed: true, reason: 'uv_near_threshold' };
    }

    // Moderately close to threshold - refresh every 30 minutes
    if (uvProximity <= 3 && minutesSinceUpdate >= 30) {
      return { needed: true, reason: 'uv_moderate_proximity' };
    }

    // Far from threshold - refresh every 60 minutes
    if (minutesSinceUpdate >= 60) {
      return { needed: true, reason: 'routine_refresh' };
    }
  } else {
    // Without smart intervals, just refresh every 30 minutes during day
    if (minutesSinceUpdate >= 30) {
      return { needed: true, reason: 'standard_refresh' };
    }
  }

  // Rule 4: Stale data (over 2 hours old)
  if (minutesSinceUpdate >= 120) {
    return { needed: true, reason: 'stale_data' };
  }

  return { needed: false, reason: 'up_to_date' };
}

/**
 * Send a silent push notification to wake the app
 */
async function sendSilentPush(
  deviceToken: string,
  reason: string,
  config: any
): Promise<boolean> {
  try {
    // Silent push payload - no alert, just content-available
    const payload = {
      aps: {
        'content-available': 1,
      },
      type: 'data_refresh',
      reason: reason,
      timestamp: new Date().toISOString(),
    };

    // Use the existing APNs helper, but we need to modify for silent push
    // For now, construct the request directly
    const apnsEndpoint = config.production
      ? 'https://api.push.apple.com'
      : 'https://api.sandbox.push.apple.com';

    const url = `${apnsEndpoint}/3/device/${deviceToken}`;

    // Import jose for JWT generation
    const jose = await import('https://esm.sh/jose@4.15.4');

    // Generate JWT
    const privateKey = await jose.importPKCS8(config.keyFile, 'ES256');
    const jwt = await new jose.SignJWT({})
      .setProtectedHeader({ alg: 'ES256', kid: config.keyId })
      .setIssuer(config.teamId)
      .setIssuedAt()
      .setExpirationTime('1h')
      .sign(privateKey);

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'authorization': `bearer ${jwt}`,
        'apns-topic': config.bundleId,
        'apns-push-type': 'background', // Important: background for silent push
        'apns-priority': '5', // Low priority for silent push (5 instead of 10)
      },
      body: JSON.stringify(payload),
    });

    if (response.ok) {
      console.log(`  ✅ Silent push sent to ${deviceToken.substring(0, 8)}...`);
      return true;
    } else {
      const errorText = await response.text();
      console.error(`  ❌ Silent push failed: ${response.status} - ${errorText}`);
      return false;
    }
  } catch (error) {
    console.error(`  ❌ Silent push error:`, error);
    return false;
  }
}
