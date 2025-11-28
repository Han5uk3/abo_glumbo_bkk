# SHA Fingerprints for com.aboglumbo

## Debug Key (for development/testing)

**Keystore:** `%USERPROFILE%\.android\debug.keystore`
**Alias:** androiddebugkey

```
SHA-1:   F8:2A:B6:B9:4E:D4:39:35:D3:F5:20:48:60:F6:E8:3F:4C:48:65:D4
SHA-256: CF:2D:7D:02:0E:44:E6:F4:DB:78:B3:1A:6A:CB:D3:FD:33:CE:30:F7:8E:B8:28:3D:0B:26:63:52:B0:46:5A:67
```

## Release Key (for production)

**Keystore:** `android/app/upload-key.jks`
**Alias:** upload

```
SHA-1:   67:D4:DC:C0:16:DA:56:3B:E2:8D:00:48:10:81:3E:56:24:6F:60:BB
SHA-256: 53:98:63:57:F3:0A:2E:53:BC:A0:42:BB:33:B8:68:21:71:AC:78:56:1C:87:13:8B:19:38:9F:E8:E0:97:47:9D
```

---

## Action Required in Firebase Console

Go to: https://console.firebase.google.com/project/worker-app-tnext/settings/general

### For app: `com.aboglumbo`

**Add BOTH of these SHA-256 fingerprints:**

1. **Debug SHA-256** (for development):

   ```
   CF:2D:7D:02:0E:44:E6:F4:DB:78:B3:1A:6A:CB:D3:FD:33:CE:30:F7:8E:B8:28:3D:0B:26:63:52:B0:46:5A:67
   ```

2. **Release SHA-256** (for production):
   ```
   53:98:63:57:F3:0A:2E:53:BC:A0:42:BB:33:B8:68:21:71:AC:78:56:1C:87:13:8B:19:38:9F:E8:E0:97:47:9D
   ```

### Steps:

1. Scroll down to "Your apps" section
2. Find the Android app with package name: `com.aboglumbo`
3. Click "Add fingerprint" button
4. Add the Debug SHA-256 first
5. Click "Add fingerprint" again
6. Add the Release SHA-256
7. Click "Save" or it will auto-save
8. **IMPORTANT:** Download the new `google-services.json` file
9. Replace `android/app/google-services.json` with the downloaded file

### After adding fingerprints:

```bash
flutter clean
flutter pub get
flutter run
```

---

## Verification

After adding both SHA-256 fingerprints and downloading the new `google-services.json`, your app should work for:

- ✅ Debug builds (development)
- ✅ Release builds (production)
- ✅ Test phone numbers
- ✅ Real phone numbers

The error "Requests from this Android client application com.aboglumbo are blocked" should disappear.
