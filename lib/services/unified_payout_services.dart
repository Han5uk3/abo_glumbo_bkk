import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Unified Payout Services for Customer App
/// This is a lightweight version that only handles wallet updates
/// Full payout management is in the panel app
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
          'totalEarnings': 0.0,
          'paidEarnings': 0.0,
          'availableEarnings': 0.0,
          'totalTips': 0.0,
          'cardTips': 0.0,
          'cashTips': 0.0,
          'paidTips': 0.0,
          'totalBonus': 0.0,
          'paidBonus': 0.0,
          'availableBonus': 0.0,
          'totalAvailableBalance': 0.0,
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

  /// Update wallet amounts (earnings, tips, or bonus)
  /// This is called from the customer app when payments are made
  static Future<void> updateWalletAmounts({
    required String workerId,
    double earningsIncrement = 0.0,
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

      // Update earnings (from service payments)
      if (earningsIncrement > 0) {
        updates['totalEarnings'] = FieldValue.increment(earningsIncrement);
        updates['availableEarnings'] = FieldValue.increment(earningsIncrement);
        updates['lifetimeTotal'] = FieldValue.increment(earningsIncrement);
        updates['totalAvailableBalance'] = FieldValue.increment(
          earningsIncrement,
        );

        if (kDebugMode) {
          print('💰 Adding earnings: $earningsIncrement to worker: $workerId');
        }
      }

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
          // Card tips are added to available balance
          updates['cardTips'] = FieldValue.increment(tipsIncrement);
          updates['totalAvailableBalance'] = FieldValue.increment(
            tipsIncrement,
          );
          if (kDebugMode) {
            print('💳 Adding card tip: $tipsIncrement to worker: $workerId');
          }
        }
      }

      // Update bonus (if needed in the future)
      if (bonusIncrement > 0) {
        updates['totalBonus'] = FieldValue.increment(bonusIncrement);
        updates['availableBonus'] = FieldValue.increment(bonusIncrement);
        updates['lifetimeTotal'] = FieldValue.increment(bonusIncrement);
        updates['totalAvailableBalance'] = FieldValue.increment(bonusIncrement);

        if (kDebugMode) {
          print('🎁 Adding bonus: $bonusIncrement to worker: $workerId');
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
