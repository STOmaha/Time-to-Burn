#!/bin/bash

# 🚀 Firebase Setup Script for Time to Burn
# This script automates the Firebase setup process

echo "🔥 Setting up Firebase for Time to Burn..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm first."
    exit 1
fi

# Install Firebase CLI globally
echo "📦 Installing Firebase CLI..."
npm install -g firebase-tools

# Login to Firebase
echo "🔐 Logging into Firebase..."
firebase login

# Initialize Firebase project
echo "🚀 Initializing Firebase project..."
firebase init functions

echo "✅ Firebase setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Create a Firebase project at https://console.firebase.google.com/"
echo "2. Add your iOS app to the Firebase project"
echo "3. Download GoogleService-Info.plist and add it to your Xcode project"
echo "4. Add Firebase SDK to your Xcode project via Swift Package Manager"
echo "5. Update your project ID in the Firebase Functions"
echo "6. Deploy the Firebase Functions"
echo ""
echo "📖 See FIREBASE_PUSH_NOTIFICATIONS_SETUP.md for detailed instructions" 