import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Which service delivers login codes.
enum OtpProvider { taqnyat, firebase }

/// Reads remote feature flags from `app_settings/customer_app_v1`.
///
/// Flags are controlled server-side so options can be toggled without a new
/// app release.
///
/// Each flag falls back to the app's existing behaviour when the document,
/// the field, or the network is unavailable, so a Firestore outage never
/// changes what users see today.
class AppSettingsService {
  /// Settings document for this app.
  static const String docId = 'customer_app_v1';

  /// Flag deciding whether the "Delete account" option is offered.
  static const String showDeleteAccountField = 'showDeleteAccountOption';

  /// Flag deciding whether guest ("sign up later") login is offered.
  static const String showGuestLoginField = 'showGuestLogin';

  /// Set to `firebase` to fall back to Firebase SMS, for example during a
  /// Taqnyat outage. Any other value, or none, uses Taqnyat.
  static const String otpProviderField = 'otpProvider';

  static const Duration _otpProviderTimeout = Duration(milliseconds: 2500);

  static DocumentReference<Object?> get _docRef =>
      AppFirestore.appSettingsCollectionRef.doc(docId);

  static OtpProvider _parseOtpProvider(Object? value) =>
      value == OtpProvider.firebase.name
      ? OtpProvider.firebase
      : OtpProvider.taqnyat;

  /// The provider to use for the login the user just started.
  ///
  /// The wait is bounded so a slow network cannot hold up login. If the flag
  /// cannot be read, the last value seen on this device applies.
  static Future<OtpProvider> resolveOtpProvider() async {
    try {
      final snapshot = await _docRef
          .get(const GetOptions(source: Source.server))
          .timeout(_otpProviderTimeout);
      final data = snapshot.data();
      final provider = _parseOtpProvider(
        data is Map<String, dynamic> ? data[otpProviderField] : null,
      );
      await LocalStoreHelper.putOtpProvider(provider.name);
      return provider;
    } catch (e) {
      return _parseOtpProvider(LocalStoreHelper.getOtpProvider());
    }
  }

  static bool _readFlag(
    DocumentSnapshot<Object?> snapshot,
    String field, {
    required bool fallback,
  }) {
    if (!snapshot.exists) return fallback;
    final data = snapshot.data();
    if (data is! Map<String, dynamic>) return fallback;
    final value = data[field];
    // A non-bool value (for example the string "true") is not trusted.
    return value is bool ? value : fallback;
  }

  static Stream<bool> _watch(String field, {required bool fallback}) {
    return _docRef
        .snapshots()
        .map((snapshot) => _readFlag(snapshot, field, fallback: fallback))
        .handleError((Object e) {
        });
  }

  /// Whether the "Delete account" option should be shown.
  ///
  /// Hidden unless explicitly enabled, matching the current behaviour.
  static Stream<bool> watchDeleteAccountEnabled() =>
      _watch(showDeleteAccountField, fallback: false);

  /// Whether guest login should be offered on the login screen.
  ///
  /// Shown unless explicitly disabled. This is read before sign-in, so a
  /// security-rules or network failure must not lock everyone out of guest
  /// browsing.
  static Stream<bool> watchGuestLoginEnabled() =>
      _watch(showGuestLoginField, fallback: true);
}
