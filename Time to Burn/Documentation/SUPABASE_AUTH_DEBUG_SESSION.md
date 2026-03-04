# Supabase Auth & Profile Creation Debug Session

**Date:** February 2026
**Status:** In Progress - Awaiting Test Results

---

## Problem Summary

User can sign in with Apple successfully (email shows in account, 1 row in `auth.users`), but:
1. `user_profiles` table has 0 rows - profile not being created
2. No debug output appears in Xcode console during sign-in
3. Widget shows garbage `timeToBurn` value (e.g., `153722867280912930`)

---

## Root Causes Identified

### 1. RLS Policies
Row Level Security policies may have been blocking INSERT operations. Fixed by creating comprehensive policy reset script.

### 2. Missing Debug Logging
Sign-in flows lacked print statements to trace execution path.

### 3. Widget Data Validation
No validation for garbage `timeToBurn` values from SharedUVData.

---

## Changes Made

### SQL: `fix_all_rls_policies.sql`
- Drops ALL existing policies on all tables
- Recreates policies with correct names and permissions
- Adds service_role policies for edge functions
- Location: Project root

### SupabaseService.swift
```swift
// Added comprehensive auth event logging
func setupAuthListener() {
    // Now logs: SIGNED IN, SIGNED OUT, INITIAL SESSION, TOKEN REFRESHED, etc.
}

// Added session verification before profile creation
private func createUserProfileIfNeeded() async {
    // Verifies active session exists
    // Uses NewUserProfile Codable struct instead of raw dictionary
    // Detailed error logging
}

// Added debug function
func debugConnectionTest() async {
    // Tests: client init, session, currentUser, query, insert
}
```

### AuthenticationManager.swift
```swift
// Added logging to auth state listener
private func setupAuthenticationListener() {
    // Logs when auth state changes
}

// Added prominent logging to signInWithApple
func signInWithApple(authorization: ASAuthorization) async throws {
    print("🔐 [AuthenticationManager] ====================================")
    print("🔐 [AuthenticationManager] 🍎 Sign In with Apple STARTED")
    // ...
}

// Calls debugConnectionTest() after successful sign-in
```

### OnboardingManager.swift
```swift
// Added logging to handleSignInWithApple
func handleSignInWithApple(authorization: ASAuthorization) async {
    print("🍎 [OnboardingManager] handleSignInWithApple called!")
    // ...
}
```

### OnboardingView.swift
```swift
// Added logging to SignInWithAppleButton closures
SignInWithAppleButton(.signIn) { request in
    print("🍎 [OnboardingView] SignInWithAppleButton - request configuration")
} onCompletion: { result in
    print("🍎 [OnboardingView] SignInWithAppleButton - onCompletion called")
}
```

### MeView.swift
```swift
// Added same logging to the Sign in with Apple button in settings
```

### TimeToBurnWidget.swift
```swift
// Added validation for garbage timeToBurn values
private func createValidatedEntry(from sharedData: SharedUVData, source: String) -> UVIndexEntry {
    // If timeToBurn < 0 or > 86400 (24 hours), reset to reasonable default
    // If UV is 0, set timeToBurn to 0 (displays as ∞)
}
```

### MediumWidgetView.swift
```swift
// Added safeguard for garbage values
private var timeToBurnString: String {
    if entry.timeToBurn > 86400 { return "∞" }  // Guard against garbage
}
```

### New Struct: NewUserProfile
```swift
// In SupabaseService.swift - for inserting new profiles
struct NewUserProfile: Codable {
    let id: UUID
    let email: String?
    let skinType: String
    let uvThreshold: Int
    let notificationEnabled: Bool
    let smartIntervalsEnabled: Bool
    let locationTrackingEnabled: Bool
}
```

---

## Files Modified

| File | Changes |
|------|---------|
| `SupabaseService.swift` | Auth logging, profile creation fix, debug function |
| `AuthenticationManager.swift` | Sign-in logging, debug test call |
| `OnboardingManager.swift` | Sign-in logging |
| `OnboardingView.swift` | Button logging |
| `MeView.swift` | Button logging |
| `TimeToBurnWidget.swift` | Data validation |
| `MediumWidgetView.swift` | Garbage value guard |
| `fix_all_rls_policies.sql` | RLS policy reset (project root) |

---

## Next Steps to Debug

### 1. Check Xcode Console on App Launch
Look for these logs:
```
🔔 [SupabaseService] Setting up auth state listener...
🔐 [AuthenticationManager] Setting up authentication listener...
🔔 [SupabaseService] 📱 INITIAL SESSION: email@example.com  (if already signed in)
```

### 2. Check Console During Sign-In
Look for:
```
🍎 [OnboardingView] SignInWithAppleButton - request configuration
🍎 [OnboardingView] SignInWithAppleButton - onCompletion called
🍎 [OnboardingManager] handleSignInWithApple called!
🔐 [AuthenticationManager] 🍎 Sign In with Apple STARTED
🍎 [SupabaseService] Signing in with Apple...
```

### 3. Check Supabase Dashboard
```sql
-- Check if user exists
SELECT id, email, created_at FROM auth.users;

-- Check if profile was created
SELECT * FROM user_profiles;

-- Check policies
SELECT tablename, policyname FROM pg_policies
WHERE tablename = 'user_profiles';
```

### 4. If No Console Output at All
- Verify Xcode console filter is set to "All Output"
- The SignInWithAppleButton may not be calling its closures
- Check if sign-in is being restored from cached session (look for INITIAL SESSION log)

---

## Possible Issues Still to Investigate

1. **SignInWithAppleButton not firing closures** - User reports no output even when tapping the button
2. **Session restoration** - User may already be signed in, so button flow isn't triggered
3. **Profile creation failing silently** - Need to see error from `createUserProfileIfNeeded()`

---

## Quick Test Commands

### Check current auth status in app
The `debugConnectionTest()` function runs automatically after sign-in and prints:
```
🔧 [SupabaseService] ========== DEBUG CONNECTION TEST ==========
🔧 [SupabaseService] ✅ TEST 1 PASSED: Client initialized
🔧 [SupabaseService] ✅ TEST 2 PASSED: Active session found
...
```

### Reset for fresh test
1. In app: Settings → Reset Onboarding
2. Force close app
3. Delete from Supabase: `DELETE FROM auth.users WHERE email = 'your@email.com';`
4. Reopen app and go through onboarding

---

## Related Documentation

- `SUPABASE_INTEGRATION.md` - Full setup guide
- `fix_all_rls_policies.sql` - RLS policy reset script
- `fix_user_profiles_rls.sql` - Original partial fix (superseded)
