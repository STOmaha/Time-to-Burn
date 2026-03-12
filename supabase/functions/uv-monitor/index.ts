import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendBatchAPNsNotifications, createUVDangerNotification, createUVAllClearNotification } from '../_shared/apns.ts';

/**
 * UV Monitor Edge Function
 *
 * NEW DAILY NOTIFICATION FLOW:
 * 1. Check all users with location_tracking_enabled
 * 2. Send ONE "High UV Danger" notification per day when UV exceeds threshold
 * 3. Send ONE "All Clear" notification per day when UV drops below threshold
 * 4. Respect "Ignore for Day" user preference (no notifications until tomorrow)
 *
 * SCALE OPTIMIZATIONS:
 * - Wave-based processing (100 users per wave)
 * - Cursor pagination for memory efficiency
 * - Delays between waves to prevent overload
 * - Timeout guard to prevent Edge Function timeout
 */

// Types for daily notification state
interface DailyNotificationState {
  highUvNotifiedDate: string | null;  // YYYY-MM-DD format
  safeUvNotifiedDate: string | null;
  ignoredUntilDate: string | null;
}

interface NotificationDecision {
  shouldNotify: boolean;
  notificationType: 'high_uv_danger' | 'uv_all_clear' | null;
  reason: string;
}

// Wave processing configuration for scale
const USERS_PER_WAVE = 100;
const WAVE_DELAY_MS = 200;
const MAX_PROCESSING_TIME_MS = 110000;
const NOTIFICATION_DELAY_MS = 50;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Get today's date in YYYY-MM-DD format
 */
function getTodayDateString(): string {
  return new Date().toISOString().split('T')[0];
}

/**
 * Evaluate if notification should be sent based on new daily flow
 */
function evaluateDailyNotification(
  currentUV: number,
  threshold: number,
  state: DailyNotificationState
): NotificationDecision {
  const today = getTodayDateString();

  // Rule 1: If user chose "Ignore for Day", skip ALL notifications
  if (state.ignoredUntilDate === today) {
    return { shouldNotify: false, notificationType: null, reason: 'user_ignored_today' };
  }

  // Rule 2: Check if we should send HIGH UV notification
  if (currentUV >= threshold) {
    // Only send if we haven't already notified today
    if (state.highUvNotifiedDate !== today) {
      return { shouldNotify: true, notificationType: 'high_uv_danger', reason: 'uv_exceeded_threshold' };
    }
    return { shouldNotify: false, notificationType: null, reason: 'already_notified_high_uv_today' };
  }

  // Rule 3: Check if we should send SAFE UV notification
  if (currentUV < threshold) {
    // Only send "all clear" if:
    // a) We sent a high UV notification earlier today
    // b) We haven't already sent an all-clear today
    if (state.highUvNotifiedDate === today && state.safeUvNotifiedDate !== today) {
      return { shouldNotify: true, notificationType: 'uv_all_clear', reason: 'uv_dropped_below_threshold' };
    }
    return { shouldNotify: false, notificationType: null, reason: 'no_action_needed' };
  }

  return { shouldNotify: false, notificationType: null, reason: 'no_action_needed' };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const startTime = Date.now();
  const today = getTodayDateString();

  try {
    console.log('🌤️  [UV Monitor] Starting daily notification check...');
    console.log(`📅 [UV Monitor] Today: ${today}`);

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const apnsConfig = {
      keyId: Deno.env.get('APNS_KEY_ID')!,
      teamId: Deno.env.get('APNS_TEAM_ID')!,
      keyFile: Deno.env.get('APNS_KEY_FILE')!,
      bundleId: Deno.env.get('APNS_BUNDLE_ID')!,
      production: Deno.env.get('APNS_PRODUCTION') === 'true',
    };

    console.log(`🔧 [UV Monitor] APNs Config: keyId=${apnsConfig.keyId?.substring(0, 4) || 'MISSING'}..., production=${apnsConfig.production}`);

    let totalProcessed = 0;
    let highUvNotificationsSent = 0;
    let allClearNotificationsSent = 0;
    let waveNumber = 0;
    let lastUserId: string | null = null;
    const debugLog: string[] = [];

    // Process users in waves
    while (Date.now() - startTime < MAX_PROCESSING_TIME_MS) {
      waveNumber++;

      // Query includes new daily notification state columns
      let query = supabase
        .from('user_locations')
        .select(`
          user_id,
          latitude,
          longitude,
          location_name,
          current_uv_index,
          adjusted_uv_index,
          high_uv_notified_date,
          safe_uv_notified_date,
          ignored_until_date,
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

      if (lastUserId) {
        query = query.gt('user_id', lastUserId);
      }

      const { data: users, error: usersError } = await query;

      if (usersError) {
        throw new Error(`Failed to fetch users: ${usersError.message}`);
      }

      if (!users || users.length === 0) {
        console.log(`📊 [UV Monitor] Wave ${waveNumber}: No more users`);
        break;
      }

      console.log(`📊 [UV Monitor] Wave ${waveNumber}: Processing ${users.length} users...`);

      // Process wave
      const waveResult = await processUserWave(users, apnsConfig, supabase, debugLog, today);
      totalProcessed += waveResult.processed;
      highUvNotificationsSent += waveResult.highUvSent;
      allClearNotificationsSent += waveResult.allClearSent;

      lastUserId = users[users.length - 1].user_id;

      console.log(`✅ [UV Monitor] Wave ${waveNumber}: processed=${waveResult.processed}, highUV=${waveResult.highUvSent}, allClear=${waveResult.allClearSent}`);

      if (users.length === USERS_PER_WAVE) {
        await delay(WAVE_DELAY_MS);
      }
    }

    const processingTime = Date.now() - startTime;

    const response = {
      success: true,
      totalProcessed,
      highUvNotificationsSent,
      allClearNotificationsSent,
      totalNotificationsSent: highUvNotificationsSent + allClearNotificationsSent,
      wavesProcessed: waveNumber,
      processingTimeMs: processingTime,
      date: today,
      timestamp: new Date().toISOString(),
      debug: debugLog.slice(-50),
    };

    console.log(`🎉 [UV Monitor] Complete: ${totalProcessed} users, ${highUvNotificationsSent} high UV, ${allClearNotificationsSent} all-clear in ${processingTime}ms`);

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
 * Process a wave of users with new daily notification logic
 */
async function processUserWave(
  users: any[],
  apnsConfig: any,
  supabase: any,
  debugLog: string[],
  today: string
): Promise<{ processed: number; highUvSent: number; allClearSent: number }> {
  let processed = 0;
  let highUvSent = 0;
  let allClearSent = 0;

  const notificationsToSend: Array<{
    userId: string;
    tokens: string[];
    notification: any;
    notificationType: 'high_uv_danger' | 'uv_all_clear';
    currentUV: number;
    threshold: number;
  }> = [];

  for (const userData of users) {
    const profile = userData.user_profiles;
    processed++;

    const currentUV = userData.adjusted_uv_index ?? userData.current_uv_index;

    // Skip if UV data is NULL
    if (currentUV === null || currentUV === undefined) {
      continue;
    }

    const threshold = profile.uv_threshold;

    // Build daily notification state from database columns
    const state: DailyNotificationState = {
      highUvNotifiedDate: userData.high_uv_notified_date,
      safeUvNotifiedDate: userData.safe_uv_notified_date,
      ignoredUntilDate: userData.ignored_until_date,
    };

    // Evaluate using new daily flow logic
    const decision = evaluateDailyNotification(currentUV, threshold, state);

    console.log(`🔍 [UV Monitor] User ${userData.user_id.substring(0, 8)}: UV=${currentUV}, threshold=${threshold}, decision=${decision.reason}`);

    if (decision.shouldNotify && decision.notificationType) {
      // Get user's active devices
      const { data: devices, error: devicesError } = await supabase
        .from('user_devices')
        .select('device_token')
        .eq('user_id', userData.user_id)
        .eq('is_active', true)
        .eq('platform', 'ios');

      if (devicesError || !devices || devices.length === 0) {
        continue;
      }

      // Create appropriate notification
      const notification = decision.notificationType === 'high_uv_danger'
        ? createUVDangerNotification(currentUV, threshold, userData.location_name || 'your location')
        : createUVAllClearNotification(currentUV, threshold, userData.location_name || 'your location');

      notificationsToSend.push({
        userId: userData.user_id,
        tokens: devices.map((d: any) => d.device_token),
        notification,
        notificationType: decision.notificationType,
        currentUV,
        threshold,
      });
    }
  }

  // Send notifications with staggered delays
  for (const item of notificationsToSend) {
    const result = await sendBatchAPNsNotifications(item.tokens, item.notification, apnsConfig);

    if (result.successful > 0) {
      if (item.notificationType === 'high_uv_danger') {
        highUvSent += result.successful;

        // Update high_uv_notified_date to today
        await supabase
          .from('user_locations')
          .update({ high_uv_notified_date: today })
          .eq('user_id', item.userId);

        debugLog.push(`HIGH UV: ${item.userId.substring(0, 8)} UV=${item.currentUV}`);
      } else {
        allClearSent += result.successful;

        // Update safe_uv_notified_date to today
        await supabase
          .from('user_locations')
          .update({ safe_uv_notified_date: today })
          .eq('user_id', item.userId);

        debugLog.push(`ALL CLEAR: ${item.userId.substring(0, 8)} UV=${item.currentUV}`);
      }

      // Log notification
      await supabase.from('notification_logs').insert({
        user_id: item.userId,
        notification_type: item.notificationType,
        uv_index: item.currentUV,
        threshold: item.threshold,
      });
    }

    await delay(NOTIFICATION_DELAY_MS);
  }

  return { processed, highUvSent, allClearSent };
}
