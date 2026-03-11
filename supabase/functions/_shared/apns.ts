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

/**
 * Send notifications to multiple devices
 */
export async function sendBatchAPNsNotifications(
  deviceTokens: string[],
  notification: Omit<APNsNotification, 'deviceToken'>,
  config: APNsConfig
): Promise<{ successful: number; failed: number; errors: string[]; apnsIds: string[] }> {
  console.log(`📱 [APNs] Sending batch notifications to ${deviceTokens.length} devices`);
  console.log(`📱 [APNs] Config: keyId=${config.keyId}, teamId=${config.teamId}, bundleId=${config.bundleId}, production=${config.production}`);

  let successful = 0;
  let failed = 0;
  const errors: string[] = [];
  const apnsIds: string[] = [];

  // Send notifications in parallel (with reasonable batch size)
  const batchSize = 10;
  for (let i = 0; i < deviceTokens.length; i += batchSize) {
    const batch = deviceTokens.slice(i, i + batchSize);

    const results = await Promise.all(
      batch.map(token =>
        sendAPNsNotification({ ...notification, deviceToken: token }, config)
      )
    );

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
  }

  console.log(`📊 [APNs] Batch complete: ${successful} successful, ${failed} failed, apnsIds: ${apnsIds.join(', ')}`);

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


