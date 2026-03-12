import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as jose from 'https://esm.sh/jose@4.15.4';

/**
 * APNs Helper Module
 * Handles sending push notifications via Apple Push Notification service
 */

interface APNsNotification {
  deviceToken: string;
  title: string;
  body: string;
  badge?: number;
  sound?: string;
  category?: string;
  data?: Record<string, any>;
}

interface APNsConfig {
  keyId: string;
  teamId: string;
  keyFile: string;
  bundleId: string;
  production?: boolean;
}

/**
 * Send a push notification via APNs
 */
export async function sendAPNsNotification(
  notification: APNsNotification,
  config: APNsConfig
): Promise<{ success: boolean; error?: string }> {
  try {
    console.log(`📱 [APNs] Sending notification to device: ${notification.deviceToken.substring(0, 8)}...`);

    // Construct APNs payload
    const payload = {
      aps: {
        alert: {
          title: notification.title,
          body: notification.body,
        },
        badge: notification.badge ?? 0,
        sound: notification.sound ?? 'default',
        category: notification.category,
        'mutable-content': 1,
      },
      ...notification.data,
    };

    // Determine APNs endpoint (production vs sandbox)
    const apnsEndpoint = config.production
      ? 'https://api.push.apple.com'
      : 'https://api.sandbox.push.apple.com';

    const url = `${apnsEndpoint}/3/device/${notification.deviceToken}`;

    // Generate JWT token for authentication
    const jwtToken = await generateAPNsJWT(config);

    // Send request to APNs
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'authorization': `bearer ${jwtToken}`,
        'apns-topic': config.bundleId,
        'apns-push-type': 'alert',
        'apns-priority': '10',
      },
      body: JSON.stringify(payload),
    });

    const responseText = await response.text();
    console.log(`📡 [APNs] Response: status=${response.status}, apns-id=${response.headers.get('apns-id')}, body=${responseText}`);

    if (response.ok) {
      const apnsId = response.headers.get('apns-id');
      console.log(`✅ [APNs] Notification sent successfully, apns-id: ${apnsId}`);
      return { success: true, apnsId: apnsId || undefined };
    } else {
      const errorMsg = `${response.status} - ${responseText}`;
      console.error(`❌ [APNs] Failed to send notification: ${errorMsg}`);
      return { success: false, error: errorMsg };
    }
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.error(`❌ [APNs] Error sending notification:`, errorMsg);
    return { success: false, error: errorMsg };
  }
}

// Batch configuration for scale
const BATCH_SIZE = 50;              // Process 50 devices per batch (up from 10)
const BATCH_DELAY_MS = 100;         // 100ms delay between batches

// Helper function for delays
function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Send notifications to multiple devices
 * Optimized for scale with larger batches, delays, and JWT reuse
 */
export async function sendBatchAPNsNotifications(
  deviceTokens: string[],
  notification: Omit<APNsNotification, 'deviceToken'>,
  config: APNsConfig
): Promise<{ successful: number; failed: number; errors: string[]; apnsIds: string[] }> {
  console.log(`📱 [APNs] Sending batch notifications to ${deviceTokens.length} devices (batch size: ${BATCH_SIZE})`);

  let successful = 0;
  let failed = 0;
  const errors: string[] = [];
  const apnsIds: string[] = [];

  // Pre-generate JWT token once for all requests (reuse for efficiency)
  const jwtToken = await generateAPNsJWT(config);

  // Determine APNs endpoint
  const apnsEndpoint = config.production
    ? 'https://api.push.apple.com'
    : 'https://api.sandbox.push.apple.com';

  // Construct payload once
  const payload = JSON.stringify({
    aps: {
      alert: {
        title: notification.title,
        body: notification.body,
      },
      badge: notification.badge ?? 0,
      sound: notification.sound ?? 'default',
      category: notification.category,
      'mutable-content': 1,
    },
    ...notification.data,
  });

  // Send notifications in batches with delays
  for (let i = 0; i < deviceTokens.length; i += BATCH_SIZE) {
    const batch = deviceTokens.slice(i, i + BATCH_SIZE);

    // Process batch in parallel
    const results = await Promise.all(
      batch.map(async (token) => {
        try {
          const url = `${apnsEndpoint}/3/device/${token}`;

          const response = await fetch(url, {
            method: 'POST',
            headers: {
              'authorization': `bearer ${jwtToken}`,
              'apns-topic': config.bundleId,
              'apns-push-type': 'alert',
              'apns-priority': '10',
            },
            body: payload,
          });

          if (response.ok) {
            return { success: true, apnsId: response.headers.get('apns-id') || undefined };
          } else {
            const errorText = await response.text();
            return { success: false, error: `${response.status} - ${errorText}` };
          }
        } catch (error) {
          return { success: false, error: error instanceof Error ? error.message : String(error) };
        }
      })
    );

    // Collect results
    for (const result of results) {
      if (result.success) {
        successful++;
        if (result.apnsId) {
          apnsIds.push(result.apnsId);
        }
      } else {
        failed++;
        if (result.error) {
          errors.push(result.error);
        }
      }
    }

    // Delay between batches (except for last batch)
    if (i + BATCH_SIZE < deviceTokens.length) {
      await delay(BATCH_DELAY_MS);
    }
  }

  console.log(`📊 [APNs] Batch complete: ${successful} successful, ${failed} failed`);

  return { successful, failed, errors, apnsIds };
}

/**
 * Generate JWT token for APNs authentication
 * Uses ES256 algorithm as required by Apple
 */
async function generateAPNsJWT(config: APNsConfig): Promise<string> {
  try {
    console.log('🔐 [APNs] Generating JWT token...');
    console.log(`🔐 [APNs] Key file length: ${config.keyFile?.length}, starts with: ${config.keyFile?.substring(0, 27)}`);

    // Import the private key (PKCS8 format from .p8 file)
    let privateKey;
    try {
      privateKey = await jose.importPKCS8(config.keyFile, 'ES256');
      console.log('✅ [APNs] Private key imported successfully');
    } catch (importError) {
      console.error('❌ [APNs] Failed to import private key:', importError);
      throw new Error(`Key import failed: ${importError.message}`);
    }

    // Create and sign the JWT
    let jwt;
    try {
      jwt = await new jose.SignJWT({})
        .setProtectedHeader({
          alg: 'ES256',
          kid: config.keyId
        })
        .setIssuer(config.teamId)
        .setIssuedAt()
        .setExpirationTime('1h') // APNs tokens are valid for up to 1 hour
        .sign(privateKey);
      console.log('✅ [APNs] JWT signed successfully');
    } catch (signError) {
      console.error('❌ [APNs] Failed to sign JWT:', signError);
      throw new Error(`JWT signing failed: ${signError.message}`);
    }

    console.log('✅ [APNs] JWT token generated successfully');
    return jwt;
  } catch (error) {
    console.error('❌ [APNs] Failed to generate JWT:', error);
    throw new Error(`APNs JWT generation failed: ${error.message}`);
  }
}

/**
 * Validate device token format
 */
export function isValidDeviceToken(token: string): boolean {
  // APNs device tokens are 64 hexadecimal characters
  return /^[0-9a-fA-F]{64}$/.test(token);
}

/**
 * Helper to create UV threshold notification
 */
export function createUVThresholdNotification(
  uvIndex: number,
  threshold: number,
  locationName: string
): Omit<APNsNotification, 'deviceToken'> {
  return {
    title: '⚠️ High UV Alert',
    body: `UV Index is ${uvIndex} in ${locationName}, above your threshold of ${threshold}. Take precautions!`,
    badge: 1,
    sound: 'default',
    category: 'uv_alert',
    data: {
      type: 'uv_threshold',
      uv_index: uvIndex,
      threshold: threshold,
      location: locationName,
    },
  };
}

/**
 * Helper to create safe UV notification
 */
export function createSafeUVNotification(
  uvIndex: number,
  threshold: number,
  locationName: string
): Omit<APNsNotification, 'deviceToken'> {
  return {
    title: '✅ Safe UV Levels',
    body: `UV Index is ${uvIndex} in ${locationName}, below your threshold of ${threshold}. Safe to go outside!`,
    badge: 1,
    sound: 'default',
    category: 'uv_safe',
    data: {
      type: 'uv_safe',
      uv_index: uvIndex,
      threshold: threshold,
      location: locationName,
    },
  };
}

/**
 * Create UV Danger notification with 4 action options
 * Category: UV_DANGER_ALERT
 * Actions: Apply Sunscreen, Start UV Timer, Start Sunscreen Timer, Ignore for Day
 */
export function createUVDangerNotification(
  uvIndex: number,
  threshold: number,
  locationName: string,
  timeToBurnMinutes?: number
): Omit<APNsNotification, 'deviceToken'> {
  const burnWarning = timeToBurnMinutes
    ? ` Time to burn: ${timeToBurnMinutes} minutes.`
    : '';

  return {
    title: '☀️ High UV Alert',
    body: `UV Index is ${uvIndex} in ${locationName}.${burnWarning} Protect yourself!`,
    badge: 1,
    sound: 'default',
    category: 'UV_DANGER_ALERT',
    data: {
      type: 'uv_danger',
      uv_index: uvIndex,
      threshold: threshold,
      location: locationName,
      time_to_burn_minutes: timeToBurnMinutes,
    },
  };
}

/**
 * Create UV All Clear notification
 * Sent once when UV drops below threshold after a high UV alert
 * Category: UV_ALL_CLEAR
 */
export function createUVAllClearNotification(
  uvIndex: number,
  threshold: number,
  locationName: string
): Omit<APNsNotification, 'deviceToken'> {
  return {
    title: '✅ UV Levels Safe Now',
    body: `UV Index has dropped to ${uvIndex} in ${locationName}. Safe to enjoy the outdoors!`,
    badge: 0,
    sound: 'default',
    category: 'UV_ALL_CLEAR',
    data: {
      type: 'uv_all_clear',
      uv_index: uvIndex,
      threshold: threshold,
      location: locationName,
    },
  };
}
