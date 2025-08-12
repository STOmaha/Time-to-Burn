# 🚀 Firebase Push Notifications Setup Guide for Time to Burn

## **Why Firebase for Push Notifications?**

Firebase Cloud Messaging (FCM) is the industry standard for push notifications and integrates seamlessly with iOS apps.

## **🔍 How the New Flow Works:**

### **1. App Registration Flow:**
```
iOS App → Firebase SDK → FCM → Device Token → Local Storage
```

### **2. Notification Sending Flow:**
```
Your Backend → Firebase Admin SDK → FCM → Apple Push Service → iOS App → User Receives Notification
```

### **3. Data Flow:**
```
User Action → App Logic → Firebase Function → FCM → User Device
```

---

## **📋 Step-by-Step Setup Instructions**

### **Step 1: Create Firebase Project**

**What this does:** Sets up your Firebase project and gets the necessary configuration files.

#### **1.1 Create Firebase Project:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Create a project**
3. Enter project name: `Time to Burn`
4. Enable Google Analytics (optional but recommended)
5. Click **Create project**

#### **1.2 Add iOS App to Firebase:**
1. In Firebase Console, click **Add app** → **iOS**
2. Enter your Bundle ID: `com.timetoburn.app`
3. Enter App nickname: `Time to Burn`
4. Click **Register app**
5. Download the `GoogleService-Info.plist` file
6. Click **Continue**

#### **1.3 Add GoogleService-Info.plist to Xcode:**
1. Drag `GoogleService-Info.plist` into your Xcode project
2. Make sure it's added to your main app target
3. Verify it appears in your project navigator

### **Step 2: Install Firebase Dependencies**

**What this does:** Adds Firebase SDK to your project for push notification functionality.

#### **2.1 Add Firebase SDK via Swift Package Manager:**
1. In Xcode, go to **File** → **Add Package Dependencies**
2. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
3. Select these packages:
   - `FirebaseMessaging`
   - `FirebaseAnalytics` (optional but recommended)
4. Click **Add Package**

#### **2.2 Verify Package Installation:**
- Check that Firebase packages appear in your project's Package Dependencies
- Build your project to ensure no errors

### **Step 3: Configure iOS App for Push Notifications**

**What this does:** Sets up your iOS app to receive push notifications from Firebase.

#### **3.1 Update App Delegate:**
Your app already has a `NotificationDelegate` class. We need to update it to work with Firebase.

#### **3.2 Update Entitlements:**
Your `Time to Burn.entitlements` file already has the correct settings:
```xml
<key>aps-environment</key>
<string>development</string>
```

#### **3.3 Update Info.plist:**
Your `Time-to-Burn-Info.plist` already has the correct notification description.

### **Step 4: Create Firebase Functions for Push Notifications**

**What this does:** Creates serverless functions that can send push notifications to your users.

#### **4.1 Install Firebase CLI:**
```bash
npm install -g firebase-tools
```

#### **4.2 Login to Firebase:**
```bash
firebase login
```

#### **4.3 Initialize Firebase Functions:**
```bash
firebase init functions
```
- Select your project
- Choose TypeScript
- Enable ESLint
- Install dependencies

#### **4.4 Create Push Notification Functions:**
The functions will be created in the `firebase/functions/` directory.

### **Step 5: Update Database Schema**

**What this does:** Modifies your Supabase database to work with Firebase device tokens.

#### **5.1 Update user_devices table:**
We'll modify the existing table to store Firebase device tokens instead of APNs tokens.

### **Step 6: Update iOS App Code**

**What this does:** Integrates Firebase SDK into your existing push notification system.

#### **6.1 Update PushNotificationService:**
Replace the current implementation with Firebase-based code.

#### **6.2 Update SupabaseService:**
Add methods to send notifications via Firebase Functions.

---

## **🔧 Implementation Details**

### **1. Firebase Configuration**

#### **Initialize Firebase in App:**
```swift
import Firebase
import FirebaseMessaging

// In your App.swift
@main
struct Time_to_BurnApp: App {
    init() {
        FirebaseApp.configure()
    }
    // ... rest of your app
}
```

#### **Firebase Messaging Delegate:**
```swift
extension NotificationDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔔 [Firebase] FCM token: \(fcmToken ?? "nil")")
        
        // Store token in Supabase
        if let token = fcmToken {
            Task {
                await registerDeviceTokenWithSupabase(token)
            }
        }
    }
}
```

### **2. Updated PushNotificationService**

#### **Key Changes:**
- Use Firebase Messaging instead of direct APNs
- Register for FCM tokens instead of device tokens
- Handle Firebase-specific notification payloads

### **3. Firebase Functions**

#### **Send UV Alert Function:**
```typescript
export const sendUVAlert = functions.https.onCall(async (data, context) => {
    // Verify user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const { userId, uvIndex, location } = data;
    
    // Get user's device tokens from Supabase
    const deviceTokens = await getDeviceTokens(userId);
    
    // Send notification via FCM
    const message = {
        notification: {
            title: 'High UV Alert',
            body: `UV Index is ${uvIndex} in ${location}. Time to protect your skin!`
        },
        data: {
            type: 'uv_alert',
            uvIndex: uvIndex.toString(),
            location: location
        },
        tokens: deviceTokens
    };
    
    const response = await admin.messaging().sendMulticast(message);
    return { success: true, sentCount: response.successCount };
});
```

### **4. Updated Database Schema**

#### **Modified user_devices table:**
```sql
-- Update the table to store Firebase tokens
ALTER TABLE user_devices 
ADD COLUMN firebase_token TEXT,
ADD COLUMN fcm_token TEXT;

-- Create index for Firebase tokens
CREATE INDEX IF NOT EXISTS idx_user_devices_firebase_token ON user_devices(firebase_token);
CREATE INDEX IF NOT EXISTS idx_user_devices_fcm_token ON user_devices(fcm_token);
```

---

## **🚀 Complete Implementation Steps**

### **Step 1: Add Firebase to Your Project**

1. **Download GoogleService-Info.plist** from Firebase Console
2. **Add to Xcode project** (drag and drop into project)
3. **Add Firebase SDK** via Swift Package Manager
4. **Initialize Firebase** in your app

### **Step 2: Update Your Code**

1. **Update NotificationDelegate** to implement MessagingDelegate
2. **Update PushNotificationService** to use Firebase
3. **Update SupabaseService** to store Firebase tokens
4. **Add Firebase initialization** to your app

### **Step 3: Create Firebase Functions**

1. **Install Firebase CLI**
2. **Initialize Firebase Functions**
3. **Create notification functions**
4. **Deploy functions**

### **Step 4: Update Database**

1. **Modify user_devices table** to store Firebase tokens
2. **Update existing functions** to work with Firebase
3. **Test token storage**

### **Step 5: Test the Complete Flow**

1. **Build and run** on real device
2. **Verify FCM token** is received
3. **Test notification sending** via Firebase Functions
4. **Verify notification delivery**

---

## **📱 Integration Examples**

### **Send UV Alert:**
```swift
// In your WeatherViewModel
if uvIndex >= 8 {
    Task {
        try await supabaseService.sendUVAlertNotification(
            uvIndex: uvIndex,
            location: currentLocation
        )
    }
}
```

### **Send Timer Reminder:**
```swift
// In your TimerViewModel
if minutesRemaining <= 5 {
    Task {
        try await supabaseService.sendTimerReminderNotification(
            minutesRemaining: minutesRemaining
        )
    }
}
```

---

## **🔍 Benefits of Firebase Approach:**

### **Advantages:**
- ✅ **Industry standard** for push notifications
- ✅ **Reliable delivery** with automatic retry
- ✅ **Rich notification features** (images, actions, etc.)
- ✅ **Analytics and monitoring** built-in
- ✅ **Cross-platform support** (iOS, Android, Web)
- ✅ **Free tier** with generous limits

### **Integration with Supabase:**
- ✅ **Keep Supabase** for database and authentication
- ✅ **Use Firebase** only for push notifications
- ✅ **Best of both worlds** approach

---

## **🎯 Next Steps:**

1. **Create Firebase project** and download config file
2. **Add Firebase SDK** to your Xcode project
3. **Update your code** to use Firebase Messaging
4. **Create Firebase Functions** for sending notifications
5. **Test the complete flow**

---

## **✅ Verification Checklist:**

- [ ] Firebase project created
- [ ] GoogleService-Info.plist added to Xcode
- [ ] Firebase SDK installed via SPM
- [ ] Firebase initialized in app
- [ ] MessagingDelegate implemented
- [ ] FCM token received and stored
- [ ] Firebase Functions created and deployed
- [ ] Test notification sent successfully
- [ ] Notification appears on device

---

**🎉 Ready to implement Firebase push notifications!** This approach will give you a robust, reliable push notification system that's the industry standard. 