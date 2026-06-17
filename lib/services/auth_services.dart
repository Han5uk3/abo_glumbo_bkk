import 'dart:async';
import 'dart:io';

import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/pages/SignUp/signup_page.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:abo_glumbo_bbk/services/notification_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AuthServices {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static String? phoneNumber;

  String _sanitizePhoneNumber(String input) {
    if (input.startsWith("+966")) {
      String countryCode = "+966";
      String numberPart = input.substring(4);
      String sanitizedNumberPart = _sanitizeNumberPart(numberPart);
      String result = countryCode + sanitizedNumberPart;
      return result;
    }
    String sanitizedNumberPart = _sanitizeNumberPart(input);
    return sanitizedNumberPart;
  }

  String _sanitizeNumberPart(String input) {
    String result = input.replaceAll(RegExp(r'\s'), '');
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const asciiDigits = '0123456789';
    for (int i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], asciiDigits[i]);
    }
    return result;
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

  String _formatToE164(String phoneNumber) {
    String sanitized = phoneNumber;
    if (sanitized.startsWith('+966')) {
      return sanitized;
    }
    while (sanitized.startsWith('0')) {
      sanitized = sanitized.substring(1);
    }
    String e164Number = '+966$sanitized';
    return e164Number;
  }

  String? _verificationId;

  Future<void> sendOTP(
    BuildContext context, {
    required String phoneNumber,
    required Function(String verificationId, {int? resendToken}) onCodeSent,
    required Function(FirebaseAuthException e) onError,
    int? forceResendingToken,
  }) async {
    debugPrint('🟢 [CUSTOMER AUTH] sendOTP method called');
    debugPrint('📱 [CUSTOMER AUTH] Phone number: $phoneNumber');

    String sanitizedPhoneNumber = _formatToE164(
      _sanitizePhoneNumber(phoneNumber),
    );
    debugPrint('🔢 [CUSTOMER AUTH] Sanitized number: $sanitizedPhoneNumber');
    debugPrint(
      '📱 [CUSTOMER AUTH] Platform: ${Platform.isIOS ? "iOS" : "Android"}',
    );

    AuthServices.phoneNumber = sanitizedPhoneNumber;
    _verificationId = null;

    try {
      if (Platform.isIOS) {
        debugPrint('🍎 [CUSTOMER AUTH] Explicitly setting appVerificationDisabledForTesting to false to clear cache');
        await FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: false,
          userAccessGroup: null,
        );
      }

      debugPrint(
        '📞 [CUSTOMER AUTH] Calling Firebase verifyPhoneNumber (no-await version)...',
      );

      _auth.verifyPhoneNumber(
        phoneNumber: sanitizedPhoneNumber,
        forceResendingToken: forceResendingToken,
        timeout: const Duration(seconds: 120),
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('✅ [CUSTOMER AUTH] verificationCompleted triggered');
          try {
            AuthServices.phoneNumber = sanitizedPhoneNumber;
            await _auth.signInWithCredential(credential);
            debugPrint('✅ [CUSTOMER AUTH] Auto sign-in successful');
          } catch (e) {
            debugPrint(
              "❌ [CUSTOMER AUTH] Auto verification sign-in failed: $e",
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ [CUSTOMER AUTH] verificationFailed triggered');
          debugPrint('❌ [CUSTOMER AUTH] Code: ${e.code}');
          debugPrint('❌ [CUSTOMER AUTH] Message: ${e.message}');
          onError(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ [CUSTOMER AUTH] codeSent triggered');
          debugPrint('🆔 [CUSTOMER AUTH] ID: $verificationId');
          onCodeSent(verificationId, resendToken: resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⏰ [CUSTOMER AUTH] codeAutoRetrievalTimeout triggered');
        },
      );

      debugPrint('✅ [CUSTOMER AUTH] verifyPhoneNumber call initiated');
    } catch (e) {
      debugPrint('💥 [CUSTOMER AUTH] Exception in sendOTP: $e');
      if (e is FirebaseAuthException) {
        onError(e);
      } else {
        onError(FirebaseAuthException(code: 'unknown', message: e.toString()));
      }
      rethrow;
    }
    debugPrint('🏁 [CUSTOMER AUTH] sendOTP method complete');
  }

  Future<void> resendOTP({
    required String phoneNumber,
    required int? resendToken,
    required Function(String verificationId, {int? resendToken}) onCodeSent,
    required Function(FirebaseAuthException e) onError,
    Function(String verificationId)? onAutoRetrievalTimeout,
  }) async {
    debugPrint('🔵 [CUSTOMER AUTH] resendOTP method called');
    debugPrint('📱 [CUSTOMER AUTH] Phone number: $phoneNumber');
    debugPrint('🔑 [CUSTOMER AUTH] Resend token: $resendToken');

    String sanitizedPhoneNumber = _formatToE164(
      _sanitizePhoneNumber(phoneNumber),
    );
    debugPrint(
      '🔢 [CUSTOMER AUTH] Sanitized phone number: $sanitizedPhoneNumber',
    );

    try {
      debugPrint('📞 [CUSTOMER AUTH] Calling Firebase verifyPhoneNumber...');
      await _auth.verifyPhoneNumber(
        phoneNumber: sanitizedPhoneNumber,
        forceResendingToken: resendToken,
        timeout: const Duration(seconds: 120),
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint(
            '✅ [CUSTOMER AUTH] verificationCompleted callback triggered',
          );
          debugPrint('🔐 [CUSTOMER AUTH] Auto-signing in with credential...');
          try {
            debugPrint("Auto-verification completed during resend OTP");
            await _auth.signInWithCredential(credential);
            debugPrint('✅ [CUSTOMER AUTH] Auto sign-in successful');
          } catch (e) {
            debugPrint(
              "❌ [CUSTOMER AUTH] Auto verification failed during resend: $e",
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ [CUSTOMER AUTH] verificationFailed callback triggered');
          debugPrint('❌ [CUSTOMER AUTH] Error code: ${e.code}');
          debugPrint('❌ [CUSTOMER AUTH] Error message: ${e.message}');

          debugPrint('❌ [CUSTOMER AUTH] Calling onError callback');
          onError(e);
        },
        codeSent: (String verificationId, int? token) {
          debugPrint('✅ [CUSTOMER AUTH] codeSent callback triggered');
          debugPrint('🆔 [CUSTOMER AUTH] Verification ID: $verificationId');
          debugPrint('🔑 [CUSTOMER AUTH] New resend token: $token');

          _verificationId = verificationId;
          debugPrint('📞 [CUSTOMER AUTH] Calling onCodeSent callback');
          onCodeSent(verificationId, resendToken: token);
          debugPrint('✅ [CUSTOMER AUTH] onCodeSent callback completed');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint(
            '⏰ [CUSTOMER AUTH] codeAutoRetrievalTimeout callback triggered',
          );
          debugPrint(
            '🆔 [CUSTOMER AUTH] Timeout verification ID: $verificationId',
          );

          _verificationId = verificationId;
          if (onAutoRetrievalTimeout != null) {
            debugPrint(
              '📞 [CUSTOMER AUTH] Calling onAutoRetrievalTimeout callback',
            );
            onAutoRetrievalTimeout(verificationId);
          }
        },
      );
      debugPrint(
        '✅ [CUSTOMER AUTH] verifyPhoneNumber call completed (setup done, waiting for callbacks)',
      );
    } catch (e) {
      debugPrint('💥 [CUSTOMER AUTH] Exception caught in resendOTP: $e');
      if (e is FirebaseAuthException) {
        debugPrint(
          '❌ [CUSTOMER AUTH] Calling onError callback from catch block',
        );
        onError(e);
      } else {
        debugPrint(
          '❌ [CUSTOMER AUTH] Unknown error - wrapping in FirebaseAuthException',
        );
        onError(FirebaseAuthException(code: 'unknown', message: e.toString()));
      }
      rethrow;
    }
    debugPrint('🏁 [CUSTOMER AUTH] resendOTP method complete');
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

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: sanitizedOTP,
      );
      final tempUserCredential = await _auth.signInWithCredential(credential);
      final userPhoneNumber = tempUserCredential.user?.phoneNumber ?? '';

      AuthServices.phoneNumber = userPhoneNumber;

      return tempUserCredential;
    } catch (e) {
      debugPrint("Error verifying OTP: $e");
      if (e is FirebaseAuthException) {
        // Enhanced error handling for iOS-specific issues
        switch (e.code) {
          case 'invalid-verification-code':
            debugPrint("iOS: Invalid verification code provided");
            break;
          case 'session-expired':
            debugPrint("iOS: OTP session expired");
            break;
          case 'too-many-requests':
            debugPrint("iOS: Too many requests - temporarily blocked");
            break;
          case 'network-request-failed':
            debugPrint("iOS: Network request failed");
            break;
          default:
            debugPrint("iOS: Unknown error - ${e.code}: ${e.message}");
        }
        rethrow;
      } else {
        throw FirebaseAuthException(
          code: 'verification-failed',
          message: 'Failed to verify OTP: $e',
        );
      }
    }
  }

  Future<void> checkUser({
    required UserCredential userCredential,
    required BuildContext context,
  }) async {
    try {
      final uid = userCredential.user?.uid;
      if (uid == null) {
        debugPrint("❌ Error: User UID is null");
        return;
      }

      debugPrint("🔍 Checking user in customers collection: $uid");
      final userDoc = await AppFirestore.customersCollectionRef.doc(uid).get();

      if (!context.mounted) {
        debugPrint("⚠️ Context unmounted after Firestore check in checkUser");
        return;
      }

      await LocalStoreHelper.putGuestUser(false);

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        final userRole =
            userData?['role']?.toString().toLowerCase() ?? 'customer';

        debugPrint("🔍 User found with role: $userRole");

        // Only allow users with role "customer" to log in via customer app
        if (userRole != 'customer') {
          debugPrint(
            "❌ User role is '$userRole', not 'customer'. Access denied.",
          );
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

        debugPrint("✅ User exists with role 'customer', logging in...");

        // Setup authenticated state within the code
        await LocalStoreHelper.putUID(uid);
        await LocalStoreHelper.putlogoutStatus(false);
        await LocalStoreHelper.putBlockStatus(false);

        // Update current location address on login
        debugPrint("📍 Updating current location on login...");
        await _updateCurrentLocationAddress(uid);

        // Refresh FCM token on successful login (re-login)
        await NotificationServices.refreshFCMToken();

        if (context.mounted) {
          debugPrint("🏠 Navigating to home...");
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const Home()),
            (route) => false,
          );
        }
      } else {
        // UID not found — check by phone number to prevent duplicate accounts
        final phone = userCredential.user?.phoneNumber;
        debugPrint("🔍 UID not found, checking customers by phone: $phone");

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

            debugPrint(
              "✅ Existing customer found by phone (old UID: $oldDocId), migrating to new UID: $uid",
            );

            // Update UID field and write to new doc
            oldData['uid'] = uid;
            oldData['updatedAt'] = Timestamp.now();
            await AppFirestore.customersCollectionRef.doc(uid).set(oldData);

            // Delete old document
            if (oldDocId != uid) {
              await AppFirestore.customersCollectionRef.doc(oldDocId).delete();
              debugPrint("🗑️ Old customer doc ($oldDocId) deleted");
            }

            // Login with migrated account
            await LocalStoreHelper.putUID(uid);
            await LocalStoreHelper.putlogoutStatus(false);
            await LocalStoreHelper.putBlockStatus(false);

            await _updateCurrentLocationAddress(uid);
            await NotificationServices.refreshFCMToken();

            if (context.mounted) {
              debugPrint("🏠 Navigating to home (migrated account)...");
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
        debugPrint(
          "📝 No existing customer found by phone, navigating to signup...",
        );
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => SignupPage(uid: uid)),
            (route) => false,
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Error in checkUser: $e");
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
      debugPrint("👤 Setting up Guest User state...");

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
        debugPrint("🏠 Navigating to home as Guest...");
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Home(initialIndex: 0)),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint("❌ Error in signInAsGuest: $e");
      rethrow;
    }
  }

  /// Update or create current location address on login
  Future<void> _updateCurrentLocationAddress(String uid) async {
    try {
      debugPrint("📍 Fetching current location for user: $uid");

      // Get current position
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint("⚠️ Failed to get current position: $e");
        position = null;
      }

      if (position == null) {
        debugPrint("⚠️ Could not fetch location, skipping update");
        return;
      }

      debugPrint(
        "📍 Position fetched: ${position.latitude}, ${position.longitude}",
      );

      // Get customer document
      final customerDoc = await AppFirestore.customersCollectionRef
          .doc(uid)
          .get();
      if (!customerDoc.exists) {
        debugPrint("❌ Customer document not found");
        return;
      }

      final customerData = customerDoc.data();
      if (customerData == null) {
        debugPrint("❌ Customer data is null");
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
        debugPrint(
          "📍 Skipping reverse geocode — using default 'Current Location'",
        );
      } catch (e) {
        debugPrint("⚠️ Reverse geocoding failed: $e");
      }

      // Find existing current location address
      final currentLocationIndex = addresses.indexWhere(
        (addr) => addr.isCurrentLocation == true,
      );

      final phoneNumber = customer.phone ?? '';

      if (currentLocationIndex != -1) {
        // Update existing current location
        debugPrint("🔄 Updating existing current location address");
        addresses[currentLocationIndex] = addresses[currentLocationIndex]
            .copyWith(
              fullName: addressName,
              buildingNumber: 'N/A',
              lat: position.latitude,
              lon: position.longitude,
            );
      } else {
        // Create new current location address
        debugPrint("➕ Creating new current location address");
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

      debugPrint("✅ Current location address updated successfully");
    } catch (e, stackTrace) {
      debugPrint("❌ Error updating current location: $e");
      debugPrint("Stack trace: $stackTrace");
      // Don't throw - location update failure shouldn't block login
    }
  }
}
