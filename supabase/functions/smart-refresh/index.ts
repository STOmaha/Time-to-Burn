import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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
 *
 * SCALE OPTIMIZATIONS:
 * - Wave-based processing (100 users per wave)
 * - Cursor pagination for memory efficiency
 * - Delays between waves to prevent overload
 * - Timeout guard to prevent Edge Function timeout
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

// Wave processing configuration for scale
const USERS_PER_WAVE = 100;            // Process 100 users per wave
const WAVE_DELAY_MS = 200;             // 200ms delay between waves
const MAX_PROCESSING_TIME_MS = 110000; // 110 seconds max
const NOTIFICATION_DELAY_MS = 25;      // 25ms between silent pushes

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Helper function for delays
function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const startTime = Date.now();

  try {
    console.log('🔄 [Smart Refresh] Starting wave-based refresh check...');

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

    // Pre-import jose and generate JWT once for all requests
    const jose = await import('https://esm.sh/jose@4.15.4');
    const privateKey = await jose.importPKCS8(apnsConfig.keyFile, 'ES256');
    const jwt = await new jose.SignJWT({})
      .setProtectedHeader({ alg: 'ES256', kid: apnsConfig.keyId })
      .setIssuer(apnsConfig.teamId)
      .setIssuedAt()
      .setExpirationTime('1h')
      .sign(privateKey);

    // Get current hour to adjust refresh frequency
    const currentHour = new Date().getHours();
    const isDaytime = currentHour >= 6 && currentHour <= 20;

    console.log(`🕐 [Smart Refresh] Current hour: ${currentHour}, Daytime: ${isDaytime}`);

    let totalRefreshesSent = 0;
    let totalSkipped = 0;
    let waveNumber = 0;
    let lastUserId: string | null = null;

    // Process users in waves using cursor pagination
    while (Date.now() - startTime < MAX_PROCESSING_TIME_MS) {
      waveNumber++;

      // Fetch next batch of users with cursor pagination
      let query = supabase
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
        .eq('user_profiles.location_tracking_enabled', true)
        .eq('user_profiles.notification_enabled', true)
        .order('user_id', { ascending: true })
        .limit(USERS_PER_WAVE);

      // Cursor pagination
      if (lastUserId) {
        query = query.gt('user_id', lastUserId);
      }

      const { data: users, error: usersError } = await query;

      if (usersError) {
        throw new Error(`Failed to fetch users: ${usersError.message}`);
      }

      // No more users to process
      if (!users || users.length === 0) {
        console.log(`📊 [Smart Refresh] Wave ${waveNumber}: No more users`);
        break;
      }

      console.log(`📊 [Smart Refresh] Wave ${waveNumber}: Processing ${users.length} users...`);

      // Process this wave
      const waveResult = await processUserWave(users, isDaytime, apnsConfig, jwt, supabase);
      totalRefreshesSent += waveResult.refreshesSent;
      totalSkipped += waveResult.skipped;

      // Update cursor
      lastUserId = users[users.length - 1].user_id;

      console.log(`✅ [Smart Refresh] Wave ${waveNumber}: ${waveResult.refreshesSent} sent, ${waveResult.skipped} skipped`);

      // Delay between waves
      if (users.length === USERS_PER_WAVE) {
        await delay(WAVE_DELAY_MS);
      }
    }

    const processingTime = Date.now() - startTime;

    const response = {
      success: true,
      totalRefreshesSent,
      totalSkipped,
      wavesProcessed: waveNumber,
      processingTimeMs: processingTime,
      isDaytime,
      timestamp: new Date().toISOString(),
    };

    console.log(`🎉 [Smart Refresh] Complete: ${waveNumber} waves, ${totalRefreshesSent} refreshes, ${totalSkipped} skipped in ${processingTime}ms`);

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
 * Process a wave of users
 */
async function processUserWave(
  users: any[],
  isDaytime: boolean,
  apnsConfig: any,
  jwt: string,
  supabase: any
): Promise<{ refreshesSent: number; skipped: number }> {
  let refreshesSent = 0;
  let skipped = 0;

  for (const userData of users) {
    const profile = userData.user_profiles;

    // Evaluate if refresh is needed
    const shouldRefresh = evaluateRefreshNeed(userData, profile, isDaytime);

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
            apnsConfig,
            jwt
          );

          if (success) {
            refreshesSent++;
          }

          // Small delay between pushes
          await delay(NOTIFICATION_DELAY_MS);
        }

        // Update last_notified_at
        await supabase
          .from('user_locations')
          .update({ last_notified_at: new Date().toISOString() })
          .eq('user_id', userData.user_id);
      }
    } else {
      skipped++;
    }
  }

  return { refreshesSent, skipped };
}

/**
 * Evaluate if a user needs a data refresh
 */
function evaluateRefreshNeed(
  userData: any,
  profile: any,
  isDaytime: boolean
): { needed: boolean; reason: string } {
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
  config: any,
  jwt: string
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

    const apnsEndpoint = config.production
      ? 'https://api.push.apple.com'
      : 'https://api.sandbox.push.apple.com';

    const url = `${apnsEndpoint}/3/device/${deviceToken}`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'authorization': `bearer ${jwt}`,
        'apns-topic': config.bundleId,
        'apns-push-type': 'background',
        'apns-priority': '5',
      },
      body: JSON.stringify(payload),
    });

    return response.ok;
  } catch (error) {
    console.error(`  ❌ Silent push error:`, error);
    return false;
  }
}
