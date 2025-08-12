# 🔥 Firebase Push Notifications - Quick Reference

## **📁 Files Created:**

### **iOS App Files:**
- ✅ **Updated `Time_to_BurnApp.swift`** - Firebase initialization
- ✅ **Updated `PushNotificationService.swift`** - Firebase Messaging integration
- ✅ **Updated `PushNotificationService.swift`** - Firebase token storage and notification sending
- ✅ **Updated `NotificationDelegate`** - Firebase Messaging delegate

### **Firebase Files:**
- ✅ **`firebase/functions/package.json`** - Dependencies
- ✅ **`firebase/functions/src/index.ts`** - Push notification functions
- ✅ **`firebase/functions/tsconfig.json`** - TypeScript config
- ✅ **`firebase/firebase.json`** - Firebase project config

### **Database Files:**
- ✅ **`firebase_database_schema_update.sql`** - Database schema updates
- ✅ **`test_firebase_notifications.sql`** - Test queries

### **Setup Files:**
- ✅ **`FIREBASE_PUSH_NOTIFICATIONS_SETUP.md`** - Complete setup guide
- ✅ **`firebase_setup_script.sh`** - Automated setup script

---

## **🚀 Quick Setup Steps:**

### **1. Create Firebase Project:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project: `Time to Burn`
3. Add iOS app with Bundle ID: `com.timetoburn.app`
4. Download `GoogleService-Info.plist`

### **2. Add to Xcode:**
1. Drag `GoogleService-Info.plist` into Xcode project
2. Add Firebase SDK via Swift Package Manager:
   - URL: `https://github.com/firebase/firebase-ios-sdk`
   - Packages: `FirebaseMessaging`, `FirebaseAnalytics`

### **3. Update Database:**
1. Run Firebase Functions setup (no database schema needed)

### **4. Setup Firebase Functions:**
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login and initialize
firebase login
firebase init functions

# Deploy functions
firebase deploy --only functions
```

### **5. Test:**
1. Build and run on real device
2. Check console for FCM token
3. Verify token stored locally
4. Test notification sending

---

## **🔧 Key Code Changes:**

### **App Initialization:**
```swift
// In Time_to_BurnApp.swift
init() {
    FirebaseApp.configure()  // Add this line
    // ... rest of init
}
```

### **FCM Token Handling:**
```swift
// In NotificationDelegate
func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    // Store FCM token locally
    if let token = fcmToken {
        Task {
            await pushNotificationService.handleFCMToken(token)
        }
    }
}
```

### **Sending Notifications:**
```swift
// In your app logic
if uvIndex >= 8 {
    try await pushNotificationService.sendUVAlertNotification(
        uvIndex: uvIndex,
        location: currentLocation
    )
}
```

---

## **📱 Firebase Functions Available:**

### **Callable Functions:**
- `sendUVAlert(userId, uvIndex, location)`
- `sendTimerReminder(userId, minutesRemaining)`
- `sendDailySummary(userId, totalExposureMinutes, maxUVIndex)`
- `sendSunscreenReminder(userId)`
- `sendCustomNotification(userId, title, body, type, data)`

### **Usage from iOS:**
```swift
// The PushNotificationService methods handle the Firebase Function calls
try await pushNotificationService.sendUVAlertNotification(uvIndex: 10, location: "San Francisco")
```

---

## **🔍 Testing Commands:**

### **Check FCM Token Registration:**
```swift
// Check local storage for FCM token
if let token = UserDefaults.standard.string(forKey: "fcm_token") {
    print("FCM token found: \(token)")
}
```

### **Test Notification Function:**
```swift
// Test local notification
pushNotificationService.testPushNotification()
```

### **Check Notification History:**
```swift
// Check local notification history
// (Implementation depends on your local storage strategy)
```

---

## **⚠️ Important Notes:**

### **Development vs Production:**
- **Development:** Uses Firebase development environment
- **Production:** Update Firebase project settings for production

### **APNs Certificate:**
- Firebase handles APNs automatically
- No need to manually configure APNs certificates

### **Authentication:**
- Firebase Functions require user authentication
- Uses local user authentication

### **Token Management:**
- FCM tokens are automatically refreshed
- Old tokens are marked inactive in database
- Multiple devices per user supported

---

## **🎯 Integration Points:**

### **Weather Monitoring:**
```swift
// In WeatherViewModel
if uvIndex >= 8 {
    try await pushNotificationService.sendUVAlertNotification(
        uvIndex: uvIndex,
        location: locationName
    )
}
```

### **Timer Reminders:**
```swift
// In TimerViewModel
if minutesRemaining <= 5 {
    try await supabaseService.sendTimerReminderNotification(
        minutesRemaining: minutesRemaining
    )
}
```

### **Daily Summaries:**
```swift
// At end of day
try await supabaseService.sendDailySummaryNotification(
    totalExposureMinutes: totalMinutes,
    maxUVIndex: maxUV
)
```

---

## **🔧 Troubleshooting:**

### **Common Issues:**

#### **"No FCM token received"**
- Check Firebase initialization in app
- Verify `GoogleService-Info.plist` is added to project
- Ensure running on real device (not simulator)

#### **"Function not found"**
- Deploy Firebase Functions: `firebase deploy --only functions`
- Check function names match exactly
- Verify Firebase project ID is correct

#### **"Authentication failed"**
- Check Supabase JWT token is valid
- Verify user is authenticated in Supabase
- Check Firebase Function authentication setup

#### **"No active devices found"**
- Verify FCM token is stored in database
- Check `is_active` flag is true
- Ensure user has registered devices

---

## **📞 Support:**

- **Firebase Console:** [console.firebase.google.com](https://console.firebase.google.com/)
- **Firebase Functions Logs:** `firebase functions:log`
- **Supabase Dashboard:** [app.supabase.com](https://app.supabase.com/)

---

**🎉 Your Firebase push notification system is ready to go!** 