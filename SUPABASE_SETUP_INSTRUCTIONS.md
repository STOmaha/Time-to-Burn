# 🚀 Time to Burn - Supabase Setup Instructions

## **What I've Created For You:**

✅ **Complete Database Schema** (`supabase_database_schema.sql`)
✅ **Authentication Views** (`AuthenticationView.swift`)
✅ **Enhanced SupabaseService** with Apple/Google sign-in
✅ **AuthenticationManager** for app integration

## **What You Need to Do (Step by Step):**

### **Step 1: Set Up Supabase Authentication (5 minutes)**

1. **Go to your Supabase Dashboard:**
   - Visit [https://app.supabase.com/](https://app.supabase.com/)
   - Select your project

2. **Configure Apple Sign-In:**
   - Go to **Authentication → Providers**
   - Find **Apple** and click **Enable**
   - Add your app's bundle ID: `com.timetoburn.app` (or whatever your bundle ID is)
   - Save the settings

3. **Configure Google Sign-In:**
   - In the same **Authentication → Providers** section
   - Find **Google** and click **Enable**
   - Add your app's bundle ID
   - Save the settings

### **Step 2: Create Database Tables (10 minutes)**

1. **Open SQL Editor:**
   - In Supabase Dashboard, go to **SQL Editor**
   - Click **New Query**

2. **Run the Database Schema:**
   - Copy the entire contents of `supabase_database_schema.sql`
   - Paste it into the SQL Editor
   - Click **Run**

3. **Verify Tables Created:**
   - Go to **Table Editor**
   - You should see these tables:
     - `user_profiles`
     - `user_locations`
     - `uv_monitoring_data`
     - `user_preferences`
     - `notification_history`
     - `uv_calculation_cache`

### **Step 3: Configure Apple Sign-In in Xcode (5 minutes)**

1. **Add Sign in with Apple capability:**
   - Open your Xcode project
   - Select your app target
   - Go to **Signing & Capabilities**
   - Click **+ Capability**
   - Add **Sign in with Apple**

2. **Update Info.plist (if needed):**
   - Add URL scheme for Google OAuth callback
   - Add: `timetoburn` as a URL scheme

### **Step 4: Test Authentication (5 minutes)**

1. **Build and Run:**
   - Build your app in Xcode
   - Run on device or simulator

2. **Test Sign-In:**
   - The app should show the authentication screen
   - Try "Sign in with Apple"
   - Check Supabase Dashboard → **Authentication → Users** to see if user was created

## **🔧 Troubleshooting:**

### **If Apple Sign-In doesn't work:**
- Make sure you're testing on a real device (Apple Sign-In doesn't work in simulator)
- Verify your bundle ID matches in both Xcode and Supabase
- Check that "Sign in with Apple" capability is added

### **If Google Sign-In doesn't work:**
- Google OAuth requires additional setup with Google Cloud Console
- For now, focus on Apple Sign-In and email authentication

### **If database tables aren't created:**
- Check the SQL Editor for any error messages
- Make sure you're running the entire SQL script
- Verify you have the correct permissions in Supabase

## **🎯 Next Steps After Setup:**

1. **Test the authentication flow**
2. **Verify user data is created in Supabase**
3. **Start integrating UV data sync**
4. **Update your widget to use server data**

## **📱 What You'll See:**

### **Before Authentication:**
- Beautiful authentication screen with:
  - "Sign in with Apple" button
  - "Continue with Google" button
  - Email sign-in option
  - App logo and branding

### **After Authentication:**
- User profile automatically created
- Default preferences set up
- Ready to sync UV data

## **🔍 Verification Checklist:**

- [ ] Apple Sign-In enabled in Supabase
- [ ] Google Sign-In enabled in Supabase
- [ ] Database tables created successfully
- [ ] Sign in with Apple capability added to Xcode
- [ ] App builds without errors
- [ ] Authentication screen appears
- [ ] User can sign in with Apple
- [ ] User appears in Supabase Authentication → Users
- [ ] User profile created in user_profiles table

## **🚨 Important Notes:**

1. **Apple Sign-In only works on real devices** (not simulator)
2. **Test with a real device** for full functionality
3. **Check the console logs** for detailed debugging information
4. **Supabase Dashboard** shows all user data and authentication status

## **📞 Need Help?**

If you encounter any issues:
1. Check the console logs in Xcode
2. Check the Supabase Dashboard for errors
3. Verify all steps were completed correctly

---

**Ready to start? Begin with Step 1 (Supabase Authentication setup)!** 