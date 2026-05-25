import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Unified Payout Services for Customer App
/// This is a lightweight version that only handles wallet updates
/// Full payout management is in the panel app
///
/// PAYOUT RULES:
/// - Only Inside App tips + bonus count toward payout-requestable balance (totalAvailableBalance)
/// - Inside App service payments (mode 1 only) are tracked separately for informational purposes
/// - Inspection fees (mode 0) are NEVER included in payout tracking
/// - Outside App payments are tracked for lifetime totals only
class UnifiedPayoutServices {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get or create unified wallet for a worker
  static Future<void> getOrCreateUnifiedWallet(String workerId) async {
    try {
      final walletDoc = await _firestore
          .collection('unified_wallets')
          .doc(workerId)
          .get();

      if (!walletDoc.exists) {
        // Create new wallet with zero balances
        await _firestore.collection('unified_wallets').doc(workerId).set({
          'workerId': workerId,
          // In-app earnings (paid through Telr/Apple Pay in the customer app)
          'inAppEarnings': 0.0,
          // Outside-app earnings (cash/manual payments verified by technician)
          'outsideAppEarnings': 0.0,
          'totalCompletionAmount': 0.0, // Sum of both in-app + outside-app
          // Tips
          'totalTips': 0.0,
          'cardTips': 0.0,
          'cashTips': 0.0,
          'paidTips': 0.0,
          // Bonus
          'totalBonus': 0.0,
          'paidBonus': 0.0,
          'availableBonus': 0.0,
          // Payout balance: ONLY cardTips + availableBonus (NOT earnings)
          'totalAvailableBalance': 0.0,
          // Lifetime total: all earnings + tips + bonus for display
          'lifetimeTotal': 0.0,
          'payoutRequested': false,
          'requestedAmount': 0.0,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          print('✅ Created new unified wallet for worker: $workerId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting/creating unified wallet: $e');
      }
      rethrow;
    }
  }

  /// Update wallet amounts when a FULL SERVICE (mode 1) in-app payment is made
  /// Called from processing_payment_page.dart when customer pays via Telr/Apple Pay
  ///
  /// NOTE: Earnings are tracked for informational/lifetime totals only.
  /// They are NOT added to totalAvailableBalance (payout-requestable amount).
  /// Only Inside App tips and bonus are payoutable.
  static Future<void> recordInAppServicePayment({
    required String workerId,
    required double amount,
  }) async {
    try {
      await getOrCreateUnifiedWallet(workerId);

      final walletRef = _firestore.collection('unified_wallets').doc(workerId);

      await walletRef.update({
        'inAppEarnings': FieldValue.increment(amount),
        'totalCompletionAmount': FieldValue.increment(amount),
        'lifetimeTotal': FieldValue.increment(amount),
        // Increment totalAvailableBalance since in-app earnings are now payoutable!
        'totalAvailableBalance': FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print(
          '💰 Recorded in-app service payment: $amount for worker: $workerId',
        );
        print('   ℹ️ This is tracked for lifetime totals only, NOT for payout');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error recording in-app service payment: $e');
      }
      rethrow;
    }
  }

  /// Update wallet amounts (tips or bonus)
  /// This is called from the customer app when tips are given via review
  static Future<void> updateWalletAmounts({
    required String workerId,
    double tipsIncrement = 0.0,
    double bonusIncrement = 0.0,
    bool isCashTip = false,
  }) async {
    try {
      // Ensure wallet exists
      await getOrCreateUnifiedWallet(workerId);

      final walletRef = _firestore.collection('unified_wallets').doc(workerId);

      Map<String, dynamic> updates = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Update tips
      if (tipsIncrement > 0) {
        updates['totalTips'] = FieldValue.increment(tipsIncrement);
        updates['lifetimeTotal'] = FieldValue.increment(tipsIncrement);

        if (isCashTip) {
          // Cash tips are tracked but not added to available balance
          updates['cashTips'] = FieldValue.increment(tipsIncrement);
          if (kDebugMode) {
            print(
              '💵 Adding cash tip: $tipsIncrement to worker: $workerId (not payable)',
            );
          }
        } else {
          // Inside App tips ARE added to available balance (payoutable)
          updates['cardTips'] = FieldValue.increment(tipsIncrement);
          updates['totalAvailableBalance'] = FieldValue.increment(
            tipsIncrement,
          );
          if (kDebugMode) {
            print(
              '💳 Adding Inside App tip: $tipsIncrement to worker: $workerId (payable)',
            );
          }
        }
      }

      // Update bonus (payoutable)
      if (bonusIncrement > 0) {
        updates['totalBonus'] = FieldValue.increment(bonusIncrement);
        updates['availableBonus'] = FieldValue.increment(bonusIncrement);
        updates['lifetimeTotal'] = FieldValue.increment(bonusIncrement);
        updates['totalAvailableBalance'] = FieldValue.increment(bonusIncrement);

        if (kDebugMode) {
          print(
            '🎁 Adding bonus: $bonusIncrement to worker: $workerId (payable)',
          );
        }
      }

      await walletRef.update(updates);

      if (kDebugMode) {
        print('✅ Unified wallet updated successfully for worker: $workerId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating unified wallet: $e');
      }
      rethrow;
    }
  }
}
