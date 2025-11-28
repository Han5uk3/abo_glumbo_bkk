# Fix: "Requests from this Android client application com.aboglumbo are blocked"

## Problem

SHA-256 keys are correctly registered in Firebase Console, but authentication is still blocked.

## Root Cause

Firebase App Check is likely **enforced** on your project, requiring a valid App Check token.

## Solution Steps

### Step 1: Check App Check Enforcement

1. Go to: https://console.firebase.google.com/project/worker-app-tnext/appcheck
2. Look at the services listed (Authentication, Firestore, etc.)
3. Check if any service shows "Enforcement: Enabled" or "Enforced"

### Step 2: Get Debug Token from App Logs

Run your app and look for this line in the logs:

```
D/DebugAppCheckProvider: Enter this debug token into the Firebase console:
XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

**To see this token:**

1. Run the app: `flutter run`
2. Watch the console output carefully
3. Look for a line containing "DebugAppCheckProvider" or "debug token"
4. Copy the token (format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX)

### Step 3: Register Debug Token in Firebase Console

1. Go to: https://console.firebase.google.com/project/worker-app-tnext/appcheck/apps
2. Click on your app: `com.aboglumbo`
3. Scroll down to "App Check debug tokens"
4. Click "Manage debug tokens" or "Add debug token"
5. Paste the debug token from Step 2
6. Give it a name like "Dev Machine - Debug Token"
7. Click "Save" or "Add"

### Step 4: Alternative - Disable App Check Enforcement (Temporary)

If you want to temporarily disable App Check for development:

1. Go to: https://console.firebase.google.com/project/worker-app-tnext/appcheck
2. For each service (especially "Authentication"):
   - Click on the service
   - Look for "Enforcement" toggle
   - **Disable** enforcement for development
   - Click "Save"

**WARNING:** Only disable enforcement for development. Re-enable for production!

### Step 5: Check Authentication Domain Settings

1. Go to: https://console.firebase.google.com/project/worker-app-tnext/authentication/settings
2. Click on "Authorized domains" tab
3. Make sure your domains are listed (usually includes firebaseapp.com domains)
4. Check if there are any restrictions blocking your app

### Step 6: Verify Phone Authentication Settings

1. Go to: https://console.firebase.google.com/project/worker-app-tnext/authentication/providers
2. Click on "Phone" provider
3. Ensure it's **Enabled**
4. Check "Phone numbers for testing" section
5. Add your test number if not already there:
   - Phone: `+966111111111`
   - Code: `123456` (or your preferred code)

### Step 7: Clean Rebuild

After making changes:

```bash
flutter clean
flutter pub get
flutter run
```

---

## Expected Logs After Fix

You should see:

```
✅ Firebase initialized successfully
✅ Firebase App Check activated (debug mode)
🔑 App Check Token obtained successfully
✅ OTP code sent successfully
```

Instead of:

```
❌ Requests from this Android client application com.aboglumbo are blocked
```

---

## Still Not Working?

If the issue persists after all these steps:

1. **Check Google Cloud Console API restrictions:**

   - Go to: https://console.cloud.google.com/apis/credentials?project=worker-app-tnext
   - Check if there are API key restrictions blocking your app

2. **Verify Firebase project quota:**

   - Check if you've hit any Firebase quotas or limits
   - Go to: https://console.firebase.google.com/project/worker-app-tnext/usage

3. **Check for IP restrictions:**

   - Some Firebase projects have IP-based restrictions
   - Verify in Firebase Console → Authentication → Settings

4. **Contact Firebase Support:**
   - If all else fails, this might be a Firebase project-level restriction
   - You may need to contact Firebase support
