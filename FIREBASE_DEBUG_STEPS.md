# Firebase Authentication Debug Steps

## Current Issue

"Requests from this Android client application com.aboglumbo are blocked"

## Your Debug SHA-256 Fingerprint

```
CF:2D:7D:02:0E:44:E6:F4:DB:78:B3:1A:6A:CB:D3:FD:33:CE:30:F7:8E:B8:28:3D:0B:26:63:52:B0:46:5A:67
```

## Step-by-Step Verification

### 1. Verify SHA-256 in Firebase Console

Go to: https://console.firebase.google.com/project/worker-app-tnext/settings/general

**CRITICAL**: Make sure you're adding the SHA-256 to the **CORRECT APP**:

- App package name: `com.aboglumbo` (NOT `com.aboglumbo.cPanel`)
- Look for the Android icon with package name `com.aboglumbo`

**Check if the SHA-256 is listed:**

- Scroll down to "Your apps" section
- Click on the `com.aboglumbo` app
- Look at the "SHA certificate fingerprints" section
- You should see your SHA-256 listed there

### 2. Download Updated google-services.json

**IMPORTANT**: After adding the SHA-256, you MUST download a new `google-services.json`:

1. In Firebase Console, still on the same page
2. Scroll down to the `com.aboglumbo` app
3. Click the "Download google-services.json" button
4. Replace the file at: `android/app/google-services.json`

### 3. Check App Check Settings

Go to: https://console.firebase.google.com/project/worker-app-tnext/appcheck

**Check if App Check is ENFORCED:**

- If you see "Enforcement" enabled for any services, this could be blocking your app
- For development, you can either:
  - **Option A**: Disable enforcement temporarily
  - **Option B**: Add a debug token (see step 4)

### 4. Get App Check Debug Token (If Enforcement is Enabled)

If App Check enforcement is enabled, you need to register a debug token:

1. Run the app once
2. Check the logs for a line like:
   ```
   D/DebugAppCheckProvider: Enter this debug token into the Firebase console:
   XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
   ```
3. Copy that token
4. Go to: https://console.firebase.google.com/project/worker-app-tnext/appcheck/apps
5. Click on your app (`com.aboglumbo`)
6. Click "Manage debug tokens"
7. Add the debug token
8. Give it a name like "Dev Machine Debug Token"

### 5. Verify Authentication Settings

Go to: https://console.firebase.google.com/project/worker-app-tnext/authentication/settings

**Check these settings:**

- Phone authentication should be ENABLED
- Check if there are any domain restrictions
- Check if there are any IP restrictions

### 6. Clean and Rebuild

After making ALL the above changes:

```bash
flutter clean
flutter pub get
flutter run
```

## Alternative: Disable App Verification (TEMPORARY - Development Only)

If you want to temporarily bypass this for development, you can disable app verification in Firebase Console:

1. Go to Authentication → Settings → App Verification
2. Look for "SafetyNet" or "App Check" settings
3. Temporarily disable for development

**WARNING**: This reduces security. Only use for development, never in production.

## Still Not Working?

If none of the above works, the issue might be:

1. **Firebase project configuration issue**: The project might have strict security rules
2. **Google Cloud Console settings**: Check if there are API restrictions
3. **Test phone numbers**: Make sure test numbers are properly configured in Firebase Console

### Configure Test Phone Numbers

1. Go to: https://console.firebase.google.com/project/worker-app-tnext/authentication/providers
2. Click on "Phone" provider
3. Scroll to "Phone numbers for testing"
4. Add your test numbers with their verification codes
5. Example: `+966111111111` → `123456`

## Expected Result

After completing these steps, you should see in logs:

```
✅ Firebase App Check activated (debug mode)
✅ OTP code sent successfully
```

Instead of:

```
❌ Requests from this Android client application com.aboglumbo are blocked
```
