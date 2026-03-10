# Why AdMob and IAP Work in Debug but Fail in Release

## The Problem

Your app uses a single **environment** flag that controls:

- **AdMob**: test ad unit IDs vs production ad unit IDs  
- **IAP (RevenueCat)**: sandbox API key vs production API key  

That environment is chosen as follows:

- If you **do not** pass a build-time variable (`ENVIRONMENT`), then:
  - **Debug build** → environment is treated as **development**
  - **Release build** → environment is treated as **production**

So by default:

- **Debug** → test ads + sandbox IAP → everything works in testing.
- **Release** → production ads + production IAP → if production config is not real yet, both break.

---

## Root Cause #1: Environment Switches to Production in Release

In release (with no override), the app assumes **production**:

1. **AdMob**  
   Production ad unit IDs are used. If those IDs are still placeholders (e.g. `ca-app-pub-XXXX/YYYY`) or not yet active in AdMob, no ads load. Test IDs are **not** used in this case.

2. **IAP (RevenueCat)**  
   Production RevenueCat API keys are used. If those keys are placeholders (e.g. `YOUR_ANDROID_PROD_API_KEY`), the purchase service detects invalid keys and **does not** mark itself as initialized. Then:
   - No offerings are fetched.
   - The purchase dialog never appears because there are no products to show.

So: **ads and IAP “break” in release because release turns on production config, and production config is not fully set up yet.**

---

## Root Cause #2: Placeholder Production Config

The place where production ad unit IDs and RevenueCat keys are stored currently has:

- **Ad unit IDs**: placeholder values (e.g. `ca-app-pub-XXXX/YYYY`). AdMob will not serve on these.
- **RevenueCat keys**: placeholder values (e.g. `YOUR_...`). The purchase service explicitly refuses to initialize with these so the app stays in “free” mode and does not show a broken paywall.

So in a **default** release build, both ads and IAP correctly “fail” until you replace those placeholders with real production values.

---

## Root Cause #3: Android Release Minification (ProGuard/R8)

In release, the Android build uses **code shrinking and obfuscation** (minify enabled). If the ProGuard/R8 rules do **not** keep the classes and methods used by:

- Google Mobile Ads (AdMob)
- RevenueCat

then those SDKs can be stripped or renamed and break at runtime. That can cause:

- Ads not loading or crashing.
- RevenueCat not initializing or purchase flow failing.

So another reason things can work in debug but fail in release is **missing keep rules** for these SDKs.

---

## Root Cause #4: Initialization Timing

AdMob and RevenueCat are initialized in the background with short timeouts (e.g. a few seconds). In release:

- Code is optimized and timing can differ.
- Production endpoints might be slower or stricter.
- If init times out, the app continues but ads and offerings may never load.

So timeouts and “init in background” can make release more sensitive to slow or failing init.

---

## Root Cause #5: iOS Capabilities and Signing

For IAP to work in **any** build (debug or release), the app must:

- Have the **In-App Purchase** capability enabled for the app target.
- Be signed with a provisioning profile that includes that capability.

If the **release** profile or archive uses a different profile that does not include IAP, the purchase dialog can fail only in release. This is less common than the environment/config issues above but worth checking.

---

## Summary of Why Debug Works and Release Fails

| Area              | Debug (development)     | Release (production, default)     |
|-------------------|--------------------------|-----------------------------------|
| Ad unit IDs       | Test IDs (always fill)    | Production IDs (placeholders → no ads) |
| RevenueCat key    | Sandbox key (valid)      | Production key (placeholder → no init) |
| ProGuard/R8       | Not used                 | Can strip AdMob/RevenueCat if rules missing |
| Init timing       | Same logic, different timing in release |

---

# Solutions and Best Practices

## 1. Use Test Ads and Sandbox IAP in Release When Testing (Recommended)

To test a **release** build without touching production config:

- **Build** release with the environment forced to **UAT** (or development), e.g.:
  - `--dart-define=ENVIRONMENT=uat`
- Then:
  - **AdMob** still uses **test ad unit IDs** (same as in dev) → ads load and you avoid policy risk.
  - **RevenueCat** still uses **sandbox** API key → purchase dialog and sandbox IAP work.

So: **for “release build for testing”, always pass the same environment override you use for UAT/debug (e.g. ENVIRONMENT=uat).** That way release behaves like debug for ads and IAP, and nothing breaks because of production placeholders.

Use this for:

- Installing release on device via Xcode/Flutter.
- TestFlight builds used for internal/QA testing.

Only use **production** environment for the real App Store / Play Store build when production config is filled and approved.

---

## 2. Fill Production Config When You Ship Real Production

When you are ready to ship a **production** build (store release):

- In the place where **production** ad unit IDs are stored: replace every placeholder with the **real** AdMob ad unit IDs for this app (banner, interstitial, rewarded).
- In the place where **production** RevenueCat API keys are stored: replace every placeholder with the **real** RevenueCat production API keys for this app (Android and iOS).

Until those are real, a build that uses “production” environment will correctly show no ads and no IAP in release.

---

## 3. Add Android ProGuard Keep Rules for AdMob and RevenueCat

In the **Android app module**, the release build type references a ProGuard rules file. That file must exist and must keep the SDKs used by ads and IAP.

Ensure that file contains (or add) keep rules for:

- **Google Mobile Ads / Play Services**  
  Keep classes and methods used by the AdMob/Play Services libraries (e.g. `com.google.android.gms.ads.**` and any classes that implement listeners or callbacks you use).

- **RevenueCat**  
  Keep classes and methods used by the RevenueCat SDK (e.g. `com.revenuecat.purchases.**` and related model/callback classes).

Exact rule syntax can be taken from:

- Official AdMob / Google Mobile Ads documentation for ProGuard.
- Official RevenueCat documentation for Android ProGuard.

Without these, release builds can break ads and IAP even when config is correct.

---

## 4. Make Initialization Robust in Both Modes

- Prefer initializing AdMob and RevenueCat **once** at startup, and retrying on failure (e.g. retry once after a short delay if init times out).
- Avoid assuming init always finishes within the first few seconds; in release, networks and servers can be slower.
- If you use “init in background with timeout”, ensure the rest of the app still works when init fails (e.g. show “no ads” and “no offerings” instead of crashing), and consider a manual “retry” or “refresh” for the user.

---

## 5. Checklist for Release Testing (Test Ads + Sandbox IAP)

- Build release with **ENVIRONMENT=uat** (or equivalent) so that:
  - AdMob uses **test ad IDs**.
  - RevenueCat uses **sandbox** key and sandbox IAP.
- On **Android**: ensure the ProGuard rules file exists and keeps AdMob and RevenueCat.
- On **iOS**: ensure the app target has In-App Purchase capability and the release provisioning profile includes it.
- Install the app (via IDE or TestFlight) and verify:
  - Test ads load (banner, rewarded, etc.).
  - Paywall shows and purchase dialog appears (sandbox tester account).

---

## 6. Checklist for Real Production Release

- Replace **all** production ad unit ID placeholders with real AdMob IDs.
- Replace **all** production RevenueCat API key placeholders with real keys.
- Build **without** overriding environment (so the app uses production in release), or with an explicit production value if you use one.
- Ensure ProGuard keep rules for AdMob and RevenueCat are in place.
- Ensure App Store Connect / Play Console products are approved and available.
- Test a build that uses production config (e.g. internal track or a dedicated “production” build type) before submitting to the stores.

---

## Summary

- **Ads and IAP “work in debug but break in release”** mainly because **release defaults to production** and your **production config is still placeholder** (invalid ad IDs, invalid RevenueCat keys).
- **For release testing:** build release with **ENVIRONMENT=uat** (or your UAT value) so AdMob uses **test ad IDs** and RevenueCat uses **sandbox** → same behavior as debug, no policy risk from real ads in test builds.
- **For real production:** replace placeholders with real ad unit IDs and RevenueCat keys, add ProGuard keep rules for AdMob and RevenueCat, and ensure IAP capability and product approval on both stores.
