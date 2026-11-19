import 'dart:async';
import 'dart:io';

import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/country_code_detector.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/pages/SignUp/signup_page.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/services/app_settings_service.dart';
import 'package:abo_glumbo_bbk/services/notification_services.dart';
import 'package:abo_glumbo_bbk/services/otp_api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter/material.dart';

class AuthServices {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static String? phoneNumber;

  /// Whether this device still holds a Firebase session for [uid] that the
  /// server accepts. A disabled or deleted account or a revoked session fails;
  /// an unreachable network does not, since the SDK re-checks on its next
  /// token refresh anyway.
  static Future<bool> hasValidSessionFor(String? uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (uid == null ||
        uid.isEmpty ||
        user == null ||
        user.isAnonymous ||
        user.uid != uid) {
      return false;
    }
    try {
      await user.getIdToken(true);
      return true;
    } on FirebaseAuthException catch (e) {
      return e.code == 'network-request-failed';
    } catch (_) {
      return false;
    }
  }

  String _sanitizeOTP(String input) {
    // Remove spaces and convert Arabic digits to ASCII for OTP
    String result = input.replaceAll(RegExp(r'\s'), '');
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const asciiDigits = '0123456789';
    for (int i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], asciiDigits[i]);
    }
    return result;
  }

  String? _verificationId;

  /// Android only: Firebase verified a number by itself while the OTP page
  /// was open, by reading the SMS or, on a resend, without one. OtpPage
  /// signs in with the credential, so the code is used once and the user
  /// moves on instead of being signed in silently in the background.
  static final StreamController<
    ({String phoneNumber, PhoneAuthCredential credential})
  >
  _autoVerifiedController = StreamController.broadcast();

  static Stream<({String phoneNumber, PhoneAuthCredential credential})>
  get autoVerifiedCredentials => _autoVerifiedController.stream;

  /// [onAutoVerified] gets the credential when Android verifies the number
  /// before any SMS is sent ("instant verification"). codeSent never fires
  /// then, so the caller must open the OTP page with it itself.
  Future<void> sendOTP(
    BuildContext context, {
    required String phoneNumber,
    required Function(String verificationId, {int? resendToken}) onCodeSent,
    required Function(FirebaseAuthException e) onError,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    int? forceResendingToken,
    OtpPurpose purpose = OtpPurpose.login,
    String? expectedUid,
  }) async {

    String sanitizedPhoneNumber = CountryCodeDetector.normalizeSaudiPhone(
      phoneNumber,
    );

    AuthServices.phoneNumber = sanitizedPhoneNumber;
    _verificationId = null;

    // Read before the first await, while the context is certainly valid.
    final locale = Localizations.localeOf(context).languageCode;
    final provider = await AppSettingsService.resolveOtpProvider();
    if (provider == OtpProvider.taqnyat) {
      await _sendTaqnyatOtp(
        phoneNumber: sanitizedPhoneNumber,
        purpose: purpose,
        locale: locale,
        expectedUid: expectedUid,
        onCodeSent: onCodeSent,
        onError: onError,
      );
      return;
    }

    try {
      if (Platform.isIOS) {
        await FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: false,
          userAccessGroup: null,
        );
      }

      var codeWasSent = false;
      var verifiedWithoutCode = false;
      _auth.verifyPhoneNumber(
        phoneNumber: sanitizedPhoneNumber,
        forceResendingToken: forceResendingToken,
        timeout: const Duration(seconds: 120),
        verificationCompleted: (PhoneAuthCredential credential) {
          AuthServices.phoneNumber = sanitizedPhoneNumber;
          if (codeWasSent) {
            _autoVerifiedController.add((
              phoneNumber: sanitizedPhoneNumber,
              credential: credential,
            ));
          } else {
            verifiedWithoutCode = true;
            onAutoVerified(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          // Already verified instantly and the OTP page is open with that
          // credential; a second page for the same number is not wanted.
          if (verifiedWithoutCode) return;
          codeWasSent = true;
          onCodeSent(verificationId, resendToken: resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
        },
      );

    } catch (e) {
      if (e is FirebaseAuthException) {
        onError(e);
      } else {
        onError(FirebaseAuthException(code: 'unknown', message: e.toString()));
      }
      rethrow;
    }
  }

  Future<void> _sendTaqnyatOtp({
    required String phoneNumber,
    required OtpPurpose purpose,
    required String locale,
    required String? expectedUid,
    required Function(String verificationId, {int? resendToken}) onCodeSent,
    required Function(FirebaseAuthException e) onError,
  }) async {
    try {
      final verificationId = await OtpApi.requestOtp(
        phone: phoneNumber,
        purpose: purpose,
        locale: locale,
        expectedUid: expectedUid,
      );
      onCodeSent(verificationId);
    } on FirebaseAuthException catch (e) {
      onError(e);
    }
  }

  /// Moves the signed-in account to the number the code was sent to, keeping
  /// its UID, and returns the new number.
  Future<String> confirmPhoneChange({
    required String verificationId,
    required String otp,
    required String expectedUid,
  }) async {
    final newPhone = await OtpApi.verifyPhoneChange(
      verificationId: verificationId,
      code: _sanitizeOTP(otp),
      expectedUid: expectedUid,
    );
    AuthServices.phoneNumber = newPhone;
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      // The change is already saved; the session refreshes on its own later.
    }
    return newPhone;
  }

  Future<void> resendOTP({
    required String phoneNumber,
    required int? resendToken,
    required Function(String verificationId, {int? resendToken}) onCodeSent,
    required Function(FirebaseAuthException e) onError,
    Function(String verificationId)? onAutoRetrievalTimeout,
    String? currentVerificationId,
    OtpPurpose purpose = OtpPurpose.login,
    String locale = 'ar',
    String? expectedUid,
  }) async {

    String sanitizedPhoneNumber = CountryCodeDetector.normalizeSaudiPhone(
      phoneNumber,
    );

    if (OtpApi.isTaqnyatVerification(currentVerificationId)) {
      await _sendTaqnyatOtp(
        phoneNumber: sanitizedPhoneNumber,
        purpose: purpose,
        locale: locale,
        expectedUid: expectedUid,
        onCodeSent: onCodeSent,
        onError: onError,
      );
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: sanitizedPhoneNumber,
        forceResendingToken: resendToken,
        timeout: const Duration(seconds: 120),
        verificationCompleted: (PhoneAuthCredential credential) {
          // Resends start from the OTP page, which is open to receive this.
          _autoVerifiedController.add((
            phoneNumber: sanitizedPhoneNumber,
            credential: credential,
          ));
        },
        verificationFailed: (FirebaseAuthException e) {

          onError(e);
        },
        codeSent: (String verificationId, int? token) {

          _verificationId = verificationId;
          onCodeSent(verificationId, resendToken: token);
        },
        codeAutoRetrievalTimeout: (String verificationId) {

          _verificationId = verificationId;
          if (onAutoRetrievalTimeout != null) {
            onAutoRetrievalTimeout(verificationId);
          }
        },
      );
    } catch (e) {
      if (e is FirebaseAuthException) {
        onError(e);
      } else {
        onError(FirebaseAuthException(code: 'unknown', message: e.toString()));
      }
      rethrow;
    }
  }

  Future<UserCredential> verifyOTP(
    BuildContext context,
    String otp, {
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      String sanitizedOTP = _sanitizeOTP(otp);

      // Additional validation for iOS
      if (sanitizedOTP.isEmpty || sanitizedOTP.length != 6) {
        throw FirebaseAuthException(
          code: 'invalid-verification-code',
          message: 'Invalid OTP format. Please enter a 6-digit code.',
        );
      }

      if (OtpApi.isTaqnyatVerification(verificationId)) {
        final token = await OtpApi.verifyLogin(
          verificationId: verificationId,
          code: sanitizedOTP,
        );
        final userCredential = await _auth.signInWithCustomToken(token);
        AuthServices.phoneNumber = userCredential.user?.phoneNumber ?? '';
        return userCredential;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: sanitizedOTP,
      );
      final tempUserCredential = await _auth.signInWithCredential(credential);
      final userPhoneNumber = tempUserCredential.user?.phoneNumber ?? '';

      AuthServices.phoneNumber = userPhoneNumber;

      return tempUserCredential;
    } catch (e) {
      if (e is FirebaseAuthException) {
        rethrow;
      } else {
        throw FirebaseAuthException(
          code: 'verification-failed',
          message: 'Failed to verify OTP: $e',
        );
      }
    }
  }

  /// Signs in with a credential Firebase produced by itself (see
  /// [sendOTP]'s onAutoVerified and [autoVerifiedCredentials]), with the
  /// same side effect as [verifyOTP].
  Future<UserCredential> signInWithAutoVerifiedCredential(
    PhoneAuthCredential credential,
  ) async {
    final userCredential = await _auth.signInWithCredential(credential);
    AuthServices.phoneNumber = userCredential.user?.phoneNumber ?? '';
    return userCredential;
  }

  Future<void> checkUser({
    required UserCredential userCredential,
    required BuildContext context,
  }) async {
    try {
      final uid = userCredential.user?.uid;
      if (uid == null) {
        return;
      }

      final userDoc = await AppFirestore.customersCollectionRef.doc(uid).get();

      if (!context.mounted) {
        return;
      }

      await LocalStoreHelper.putGuestUser(false);

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        final userRole =
            userData?['role']?.toString().toLowerCase() ?? 'customer';

        // Only allow users with role "customer" to log in via customer app
        if (userRole != 'customer') {
          // Sign out the Firebase Auth session since this user isn't a customer
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  (AppLocalizations.of(context)?.accountNotRegisteredCustomer ??
                      'This account is not registered as a customer.'),
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
            Navigator.pop(context);
          }
          return;
        }

        // Setup authenticated state within the code
        await LocalStoreHelper.putUID(uid);
        await LocalStoreHelper.putUserName(userData?['name'] ?? '');
        await LocalStoreHelper.putlogoutStatus(false);
        await LocalStoreHelper.putBlockStatus(false);

        // Update current location address on login
        await _updateCurrentLocationAddress(uid);

        // Refresh FCM token on successful login (re-login)
        await NotificationServices.refreshFCMToken();

        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
            (route) => false,
          );
        }
      } else {
        // UID not found — check by phone number to prevent duplicate accounts
        final phone = userCredential.user?.phoneNumber;

        if (phone != null && phone.isNotEmpty) {
          final phoneQuery = await AppFirestore.customersCollectionRef
              .where('phone', isEqualTo: phone)
              .limit(1)
              .get();

          if (phoneQuery.docs.isNotEmpty) {
            // Existing customer found by phone — migrate doc to new UID
            final oldDoc = phoneQuery.docs.first;
            final oldData = oldDoc.data() as Map<String, dynamic>;
            final oldDocId = oldDoc.id;

            // Update UID field and write to new doc
            oldData['uid'] = uid;
            oldData['updatedAt'] = Timestamp.now();
            await AppFirestore.customersCollectionRef.doc(uid).set(oldData);

            // Delete old document
            if (oldDocId != uid) {
              await AppFirestore.customersCollectionRef.doc(oldDocId).delete();
            }

            // Login with migrated account
            await LocalStoreHelper.putUID(uid);
            await LocalStoreHelper.putUserName(oldData['name'] ?? '');
            await LocalStoreHelper.putlogoutStatus(false);
            await LocalStoreHelper.putBlockStatus(false);

            await _updateCurrentLocationAddress(uid);
            await NotificationServices.refreshFCMToken();

            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const Home()),
                (route) => false,
              );
            }
            return;
          }
        }

        // Truly new user — redirect to signup
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => SignupPage(uid: uid)),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (e is FirebaseAuthException) {
        rethrow;
      } else {
        throw FirebaseAuthException(
          code: 'check-user-failed',
          message: 'Failed to check user: $e',
        );
      }
    }
  }

  Future<void> signInAsGuest(BuildContext context) async {
    try {
      final currentUid = LocalStoreHelper.getUID();
      final isBiometricEnabled = currentUid != null
          ? LocalStoreHelper.getBiometricAuthEnabled(currentUid)
          : false;

      // Handle setup correctly within the code
      if (!isBiometricEnabled) {
        await LocalStoreHelper.clearUID();
      }

      await LocalStoreHelper.putGuestUser(true);
      await LocalStoreHelper.putlogoutStatus(false);
      await LocalStoreHelper.putBlockStatus(false);

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Home(initialIndex: 0)),
          (route) => false,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update or create current location address on login
  Future<void> _updateCurrentLocationAddress(String uid) async {
    try {
      // Get current position
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        position = null;
      }

      if (position == null) {
        return;
      }

      // Get customer document
      final customerDoc = await AppFirestore.customersCollectionRef
          .doc(uid)
          .get();
      if (!customerDoc.exists) {
        return;
      }

      final customerData = customerDoc.data();
      if (customerData == null) {
        return;
      }

      final customer = CustomerModel.fromJson(
        customerData as Map<String, dynamic>,
      );
      final addresses = List<AddressModel>.from(customer.addresses);

      // Reverse geocode to get address name
      String addressName = 'Current Location';
      try {
        // Reverse geocoding is handled externally; use a safe fallback
      } catch (_) {
      }

      // Find existing current location address
      final currentLocationIndex = addresses.indexWhere(
        (addr) => addr.isCurrentLocation == true,
      );

      final phoneNumber = customer.phone ?? '';

      if (currentLocationIndex != -1) {
        // Update existing current location
        addresses[currentLocationIndex] = addresses[currentLocationIndex]
            .copyWith(
              fullName: addressName,
              buildingNumber: 'N/A',
              lat: position.latitude,
              lon: position.longitude,
            );
      } else {
        // Create new current location address
        final newAddress = AddressModel(
          id: const Uuid().v4(),
          fullName: addressName,
          buildingNumber: 'N/A',
          phoneNumber: phoneNumber,
          lat: position.latitude,
          lon: position.longitude,
          isCurrentLocation: true,
          isSelected: addresses.isEmpty, // Select if it's the only address
        );
        addresses.insert(0, newAddress); // Add at beginning
      }

      // Update customer document
      await AppFirestore.customersCollectionRef.doc(uid).update({
        'addresses': addresses.map((e) => e.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      // Don't throw - location update failure shouldn't block login
    }
  }
}
