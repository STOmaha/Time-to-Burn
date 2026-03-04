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
): Promise<boolean> {
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

    if (response.ok) {
      console.log(`✅ [APNs] Notification sent successfully`);
      return true;
    } else {
      const errorText = await response.text();
      console.error(`❌ [APNs] Failed to send notification: ${response.status} - ${errorText}`);
      return false;
    }
  } catch (error) {
    console.error(`❌ [APNs] Error sending notification:`, error);
    return false;
  }
}

/**
 * Send notifications to multiple devices
 */
export async function sendBatchAPNsNotifications(
  deviceTokens: string[],
  notification: Omit<APNsNotification, 'deviceToken'>,
  config: APNsConfig
): Promise<{ successful: number; failed: number }> {
  console.log(`📱 [APNs] Sending batch notifications to ${deviceTokens.length} devices`);
  
  let successful = 0;
  let failed = 0;

  // Send notifications in parallel (with reasonable batch size)
  const batchSize = 10;
  for (let i = 0; i < deviceTokens.length; i += batchSize) {
    const batch = deviceTokens.slice(i, i + batchSize);
    
    const results = await Promise.all(
      batch.map(token =>
        sendAPNsNotification({ ...notification, deviceToken: token }, config)
      )
    );

    successful += results.filter(r => r).length;
    failed += results.filter(r => !r).length;
  }

  console.log(`📊 [APNs] Batch complete: ${successful} successful, ${failed} failed`);
  
  return { successful, failed };
}

/**
 * Generate JWT token for APNs authentication
 * Uses ES256 algorithm as required by Apple
 */
async function generateAPNsJWT(config: APNsConfig): Promise<string> {
  try {
    console.log('🔐 [APNs] Generating JWT token...');

    // Import the private key (PKCS8 format from .p8 file)
    const privateKey = await jose.importPKCS8(config.keyFile, 'ES256');

    // Create and sign the JWT
    const jwt = await new jose.SignJWT({})
      .setProtectedHeader({
        alg: 'ES256',
        kid: config.keyId
      })
      .setIssuer(config.teamId)
      .setIssuedAt()
      .setExpirationTime('1h') // APNs tokens are valid for up to 1 hour
      .sign(privateKey);

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


