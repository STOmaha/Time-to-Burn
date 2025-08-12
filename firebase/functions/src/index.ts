import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { createClient } from '@supabase/supabase-js';

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Supabase client
const supabaseUrl = 'https://svkrlwzwnirhgbyardze.supabase.co';
const supabaseServiceKey = functions.config().supabase.service_key;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Helper function to get device tokens for a user
async function getDeviceTokens(userId: string): Promise<string[]> {
  try {
    const { data, error } = await supabase
      .from('user_devices')
      .select('fcm_token')
      .eq('user_id', userId)
      .eq('is_active', true);

    if (error) {
      console.error('Error fetching device tokens:', error);
      return [];
    }

    return data?.map(device => device.fcm_token).filter(Boolean) || [];
  } catch (error) {
    console.error('Error in getDeviceTokens:', error);
    return [];
  }
}

// Helper function to log notification
async function logNotification(userId: string, title: string, body: string, type: string, success: boolean) {
  try {
    await supabase
      .from('notification_history')
      .insert({
        user_id: userId,
        title: title,
        body: body,
        notification_type: type,
        sent_at: new Date().toISOString(),
        success: success
      });
  } catch (error) {
    console.error('Error logging notification:', error);
  }
}

// Send UV Alert Notification
export const sendUVAlert = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, uvIndex, location } = data;

  if (!userId || !uvIndex || !location) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    // Get user's device tokens
    const deviceTokens = await getDeviceTokens(userId);

    if (deviceTokens.length === 0) {
      console.log(`No active devices found for user: ${userId}`);
      await logNotification(userId, 'High UV Alert', `UV Index is ${uvIndex} in ${location}`, 'uv_alert', false);
      return { success: false, message: 'No active devices found' };
    }

    // Prepare notification message
    const message = {
      notification: {
        title: 'High UV Alert',
        body: `UV Index is ${uvIndex} in ${location}. Time to protect your skin!`
      },
      data: {
        type: 'uv_alert',
        uvIndex: uvIndex.toString(),
        location: location,
        timestamp: Date.now().toString()
      },
      tokens: deviceTokens
    };

    // Send notification
    const response = await admin.messaging().sendMulticast(message);

    // Log the notification
    await logNotification(userId, message.notification.title, message.notification.body, 'uv_alert', true);

    console.log(`UV alert sent to ${response.successCount}/${deviceTokens.length} devices for user ${userId}`);

    return {
      success: true,
      sentCount: response.successCount,
      totalCount: deviceTokens.length,
      failures: response.failureCount
    };

  } catch (error) {
    console.error('Error sending UV alert:', error);
    await logNotification(userId, 'High UV Alert', `UV Index is ${uvIndex} in ${location}`, 'uv_alert', false);
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
});

// Send Timer Reminder Notification
export const sendTimerReminder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, minutesRemaining } = data;

  if (!userId || minutesRemaining === undefined) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    const deviceTokens = await getDeviceTokens(userId);

    if (deviceTokens.length === 0) {
      await logNotification(userId, 'Sun Exposure Timer', `You have ${minutesRemaining} minutes remaining`, 'timer_reminder', false);
      return { success: false, message: 'No active devices found' };
    }

    const message = {
      notification: {
        title: 'Sun Exposure Timer',
        body: `You have ${minutesRemaining} minutes remaining in the sun. Consider seeking shade soon.`
      },
      data: {
        type: 'timer_reminder',
        minutesRemaining: minutesRemaining.toString(),
        timestamp: Date.now().toString()
      },
      tokens: deviceTokens
    };

    const response = await admin.messaging().sendMulticast(message);
    await logNotification(userId, message.notification.title, message.notification.body, 'timer_reminder', true);

    return {
      success: true,
      sentCount: response.successCount,
      totalCount: deviceTokens.length
    };

  } catch (error) {
    console.error('Error sending timer reminder:', error);
    await logNotification(userId, 'Sun Exposure Timer', `You have ${minutesRemaining} minutes remaining`, 'timer_reminder', false);
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
});

// Send Daily Summary Notification
export const sendDailySummary = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, totalExposureMinutes, maxUVIndex } = data;

  if (!userId || totalExposureMinutes === undefined || maxUVIndex === undefined) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    const deviceTokens = await getDeviceTokens(userId);

    if (deviceTokens.length === 0) {
      const summaryText = `Today you spent ${Math.floor(totalExposureMinutes / 60)}h ${totalExposureMinutes % 60}m in the sun with UV Index up to ${maxUVIndex}.`;
      await logNotification(userId, 'Daily Sun Exposure Summary', summaryText, 'daily_summary', false);
      return { success: false, message: 'No active devices found' };
    }

    const hours = Math.floor(totalExposureMinutes / 60);
    const minutes = totalExposureMinutes % 60;
    const summaryText = `Today you spent ${hours}h ${minutes}m in the sun with UV Index up to ${maxUVIndex}.`;

    const message = {
      notification: {
        title: 'Daily Sun Exposure Summary',
        body: summaryText
      },
      data: {
        type: 'daily_summary',
        totalExposureMinutes: totalExposureMinutes.toString(),
        maxUVIndex: maxUVIndex.toString(),
        timestamp: Date.now().toString()
      },
      tokens: deviceTokens
    };

    const response = await admin.messaging().sendMulticast(message);
    await logNotification(userId, message.notification.title, message.notification.body, 'daily_summary', true);

    return {
      success: true,
      sentCount: response.successCount,
      totalCount: deviceTokens.length
    };

  } catch (error) {
    console.error('Error sending daily summary:', error);
    const summaryText = `Today you spent ${Math.floor(totalExposureMinutes / 60)}h ${totalExposureMinutes % 60}m in the sun with UV Index up to ${maxUVIndex}.`;
    await logNotification(userId, 'Daily Sun Exposure Summary', summaryText, 'daily_summary', false);
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
});

// Send Sunscreen Reminder Notification
export const sendSunscreenReminder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId } = data;

  if (!userId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    const deviceTokens = await getDeviceTokens(userId);

    if (deviceTokens.length === 0) {
      await logNotification(userId, 'Sunscreen Reminder', 'It\'s time to reapply your sunscreen for continued protection.', 'sunscreen_reminder', false);
      return { success: false, message: 'No active devices found' };
    }

    const message = {
      notification: {
        title: 'Sunscreen Reminder',
        body: 'It\'s time to reapply your sunscreen for continued protection.'
      },
      data: {
        type: 'sunscreen_reminder',
        timestamp: Date.now().toString()
      },
      tokens: deviceTokens
    };

    const response = await admin.messaging().sendMulticast(message);
    await logNotification(userId, message.notification.title, message.notification.body, 'sunscreen_reminder', true);

    return {
      success: true,
      sentCount: response.successCount,
      totalCount: deviceTokens.length
    };

  } catch (error) {
    console.error('Error sending sunscreen reminder:', error);
    await logNotification(userId, 'Sunscreen Reminder', 'It\'s time to reapply your sunscreen for continued protection.', 'sunscreen_reminder', false);
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
});

// Generic notification function
export const sendCustomNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, title, body, type = 'custom', data: customData = {} } = data;

  if (!userId || !title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    const deviceTokens = await getDeviceTokens(userId);

    if (deviceTokens.length === 0) {
      await logNotification(userId, title, body, type, false);
      return { success: false, message: 'No active devices found' };
    }

    const message = {
      notification: {
        title: title,
        body: body
      },
      data: {
        type: type,
        ...customData,
        timestamp: Date.now().toString()
      },
      tokens: deviceTokens
    };

    const response = await admin.messaging().sendMulticast(message);
    await logNotification(userId, title, body, type, true);

    return {
      success: true,
      sentCount: response.successCount,
      totalCount: deviceTokens.length
    };

  } catch (error) {
    console.error('Error sending custom notification:', error);
    await logNotification(userId, title, body, type, false);
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
}); 