# RevenueCat Setup Guide for Heads Up Game

This guide walks you through the complete setup process for RevenueCat in-app purchases.

---

## 📋 Table of Contents

1. [RevenueCat Dashboard Setup](#1-revenuecat-dashboard-setup)
2. [App Store Connect Setup (iOS)](#2-app-store-connect-setup-ios)
3. [Google Play Console Setup (Android)](#3-google-play-console-setup-android)
4. [Configure API Keys](#4-configure-api-keys)
5. [Create Products & Offerings](#5-create-products--offerings)
6. [iOS Native Configuration](#6-ios-native-configuration)
7. [Android Native Configuration](#7-android-native-configuration)
8. [Testing](#8-testing)
9. [Go Live Checklist](#9-go-live-checklist)

---

## 1. RevenueCat Dashboard Setup

### Step 1.1: Create a RevenueCat Account
1. Go to [https://app.revenuecat.com/](https://app.revenuecat.com/)
2. Sign up for a free account
3. Confirm your email

### Step 1.2: Create a New Project
1. Click **"+ New"** in the top right
2. Enter project name: **"Heads Up Game"**
3. Click **"Create project"**

### Step 1.3: Note Your Project ID
- Copy your **Project ID** from the project settings (you'll need this later)

---

## 2. App Store Connect Setup (iOS)

### Step 2.1: Access App Store Connect
1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to **"My Apps"** → Select your app

### Step 2.2: Create App-Specific Shared Secret
1. Go to **"App Information"** (left sidebar)
2. Scroll to **"App-Specific Shared Secret"**
3. Click **"Manage"** → **"Generate"**
4. **Copy the shared secret** (you'll need this for RevenueCat)

### Step 2.3: Create In-App Purchases
1. Go to **"Features"** → **"In-App Purchases"**
2. Click **"+"** to create new products:

#### Product 1: Monthly Subscription
```
Reference Name: Premium Monthly
Product ID: premium_monthly
Type: Auto-Renewable Subscription
Price: $2.99/month (or your preferred price)
```

#### Product 2: Yearly Subscription
```
Reference Name: Premium Yearly
Product ID: premium_yearly
Type: Auto-Renewable Subscription
Price: $19.99/year (or your preferred price)
```

#### Product 3: Lifetime (One-Time Purchase)
```
Reference Name: Premium Lifetime
Product ID: premium_lifetime
Type: Non-Consumable
Price: $9.99 (or your preferred price)
```

#### Product 4: Weekend Pass (48-Hour Non-Renewing)
```
Reference Name: Premium Weekend Pass
Product ID: premium_weekend
Type: Non-Renewing Subscription
Duration: 3 days (closest to 48h available on iOS)
Price: $0.99
```
> **Note:** Apple does not offer a 48-hour duration. Use "3 days" as the
> closest option. RevenueCat will set the entitlement expiration based on
> the store's configured duration. On Google Play, create this as a
> prepaid subscription with a 3-day billing period.

### Step 2.4: Create Subscription Group
1. When creating subscriptions, create a group called **"Premium"**
2. Add monthly and yearly subscriptions to this group
3. Set the **Level** (yearly should be level 1, monthly level 2)
4. The Weekend Pass should be a **separate non-renewing subscription** — it does NOT go in the auto-renewable group

### Step 2.5: Submit for Review
- Each in-app purchase needs to go through Apple's review
- Fill in all required metadata (description, screenshot)
- Submit for review

---

## 3. Google Play Console Setup (Android)

### Step 3.1: Access Google Play Console
1. Go to [Google Play Console](https://play.google.com/console/)
2. Select your app

### Step 3.2: Enable Monetization
1. Go to **"Monetization setup"** in left sidebar
2. Accept the terms if you haven't already

### Step 3.3: Create Products

#### For Subscriptions:
1. Go to **"Subscriptions"** → Click **"Create subscription"**
2. Create:

**Monthly Subscription:**
```
Product ID: premium_monthly
Name: Premium Monthly
Description: Unlock all decks and remove ads
Pricing: $2.99/month
```

**Yearly Subscription:**
```
Product ID: premium_yearly
Name: Premium Yearly  
Description: Unlock all decks and remove ads - Best value!
Pricing: $19.99/year
```

#### For One-Time Purchase:
1. Go to **"In-app products"** → Click **"Create product"**

**Lifetime Purchase:**
```
Product ID: premium_lifetime
Name: Premium Lifetime
Description: One-time purchase for lifetime access
Price: $9.99
```

**Weekend Pass (Prepaid Subscription):**
```
Product ID: premium_weekend
Name: Premium Weekend Pass
Description: 48 hours of unlimited premium access
Billing period: 3 days (prepaid, no auto-renewal)
Price: $0.99
```
> On Google Play, create this as a **prepaid** base plan within a new
> subscription. Prepaid plans do not auto-renew.

### Step 3.4: Get License Key
1. Go to **"Monetization setup"**
2. Copy the **"Base64-encoded RSA public key"**
3. You'll need this for RevenueCat

---

## 4. Configure API Keys

### Step 4.1: Connect iOS App to RevenueCat
1. In RevenueCat dashboard, go to your project
2. Click **"Apps"** → **"+ New"**
3. Select **"App Store"**
4. Enter your **Bundle ID**: (e.g., `com.cuberix.headsup`)
5. Paste your **App-Specific Shared Secret** from App Store Connect
6. Click **"Save"**
7. **Copy the iOS API Key** shown

### Step 4.2: Connect Android App to RevenueCat
1. Click **"+ New"** again
2. Select **"Play Store"**
3. Enter your **Package Name**: (e.g., `com.cuberix.headsup`)
4. For **Service Account credentials**:
   - Go to Google Cloud Console
   - Create a Service Account with Play Developer API access
   - Download the JSON key file
   - Upload it to RevenueCat
5. Click **"Save"**
6. **Copy the Android API Key** shown

### Step 4.3: Update Your Code
Open `lib/services/purchases_service.dart` and update:

```dart
// Replace these with your actual API keys from RevenueCat
static const String _androidApiKey = 'goog_YOUR_ACTUAL_ANDROID_API_KEY';
static const String _iosApiKey = 'appl_YOUR_ACTUAL_IOS_API_KEY';
```

---

## 5. Create Products & Offerings

### Step 5.1: Add Products in RevenueCat
1. Go to **"Products"** in your project
2. Click **"+ New"**
3. Add each product:

| Identifier | App Store Product ID | Play Store Product ID |
|------------|---------------------|----------------------|
| premium_monthly | premium_monthly | premium_monthly |
| premium_yearly | premium_yearly | premium_yearly |
| premium_lifetime | premium_lifetime | premium_lifetime |
| premium_weekend | premium_weekend | premium_weekend |

### Step 5.2: Create an Entitlement
1. Go to **"Entitlements"** → **"+ New"**
2. Create entitlement:
   - **Identifier**: `premium`
   - **Description**: Premium access to all features
3. **Attach all 4 products** to this entitlement (monthly, yearly, lifetime, **and** weekend pass)

### Step 5.3: Create an Offering
1. Go to **"Offerings"** → **"+ New"**
2. Create offering:
   - **Identifier**: `default`
   - **Description**: Default offering
3. Add packages:
   - **Monthly** → Link to `premium_monthly`
   - **Annual** → Link to `premium_yearly`  
   - **Lifetime** → Link to `premium_lifetime`
   - **Custom** (identifier: `premium_weekend`) → Link to `premium_weekend`
4. **Set as Current Offering** ✓

---

## 6. iOS Native Configuration

### Step 6.1: Update Info.plist
Your `ios/Runner/Info.plist` should already have the necessary permissions. Verify it contains:

```xml
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
</array>
```

### Step 6.2: Enable In-App Purchase Capability
1. Open Xcode (`ios/Runner.xcworkspace`)
2. Select the **Runner** project
3. Go to **"Signing & Capabilities"**
4. Click **"+ Capability"**
5. Add **"In-App Purchase"**

### Step 6.3: Verify StoreKit Configuration (for testing)
1. In Xcode, go to **File → New → File**
2. Select **"StoreKit Configuration File"**
3. Add your products for local testing
4. In scheme settings, set this file as the StoreKit Configuration

---

## 7. Android Native Configuration

### Step 7.1: Update build.gradle
Your `android/app/build.gradle.kts` should have billing enabled. RevenueCat handles this automatically, but verify:

```kotlin
dependencies {
    // RevenueCat handles billing library internally
}
```

### Step 7.2: Add Internet Permission
Ensure `android/app/src/main/AndroidManifest.xml` has:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="com.android.vending.BILLING" />
```

---

## 8. Testing

### Step 8.1: iOS Sandbox Testing
1. On your iPhone, go to **Settings → App Store**
2. Scroll down and tap **"Sandbox Account"**
3. Sign in with an Apple Sandbox tester account
4. Create sandbox testers in App Store Connect under **Users and Access → Sandbox Testers**

### Step 8.2: Android Testing
1. In Google Play Console, go to **"License Testing"**
2. Add your test email addresses
3. Enable **"Internal testing"** track
4. Upload your app bundle

### Step 8.3: RevenueCat Debug Mode
The purchases_service.dart already enables debug logging in development:

```dart
if (kDebugMode) {
  await Purchases.setLogLevel(LogLevel.debug);
}
```

### Step 8.4: Test Scenarios
Test these scenarios:
- [ ] Purchase monthly subscription
- [ ] Purchase yearly subscription
- [ ] Purchase lifetime
- [ ] Cancel subscription
- [ ] Restore purchases
- [ ] Upgrade/downgrade subscription
- [ ] Handle network errors

---

## 9. Go Live Checklist

### Before Publishing:

- [ ] **API Keys**: Replace test keys with production keys
- [ ] **Products Approved**: All IAPs approved by Apple/Google
- [ ] **Entitlements**: Configured correctly in RevenueCat
- [ ] **Offerings**: Set default offering with all packages
- [ ] **Sandbox Testing**: All purchase flows tested
- [ ] **Restore Purchases**: Working correctly
- [ ] **Error Handling**: All error cases handled gracefully
- [ ] **Analytics**: Purchase events being tracked

### In Your Code:
- [ ] Remove debug logs if not needed in production
- [ ] Test on real devices (not just simulators)
- [ ] Verify pricing displays correctly
- [ ] Test subscription management (cancel/restore)

### RevenueCat Dashboard:
- [ ] Verify events are being received
- [ ] Check Charts for test purchases
- [ ] Set up Webhooks if needed
- [ ] Configure Integrations (optional: Slack, Discord, etc.)

---

## 🔗 Quick Reference Links

| Resource | URL |
|----------|-----|
| RevenueCat Dashboard | https://app.revenuecat.com |
| RevenueCat Flutter Docs | https://www.revenuecat.com/docs/flutter |
| App Store Connect | https://appstoreconnect.apple.com |
| Google Play Console | https://play.google.com/console |
| RevenueCat API Reference | https://www.revenuecat.com/docs/api |

---

## 📞 Support

- RevenueCat Community: https://community.revenuecat.com
- RevenueCat Discord: https://discord.gg/revenuecat
- Documentation: https://docs.revenuecat.com

---

## 📝 Code Files Modified

| File | Purpose |
|------|---------|
| `lib/services/purchases_service.dart` | Main RevenueCat service |
| `lib/screens/paywall_screen.dart` | UI for purchases |
| `lib/main.dart` | SDK initialization |
| `pubspec.yaml` | Added purchases_flutter dependency |

---

## ✅ Next Steps Summary

1. **Create RevenueCat account** → [app.revenuecat.com](https://app.revenuecat.com)
2. **Create products** in App Store Connect & Google Play Console
3. **Configure apps** in RevenueCat dashboard
4. **Get API keys** and update `purchases_service.dart`
5. **Create entitlements & offerings** in RevenueCat
6. **Test in sandbox** on real devices
7. **Submit for review** and go live!

---

*Last Updated: December 2024*








