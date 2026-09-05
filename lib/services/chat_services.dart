import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';

class ChatService {
  static FirebaseDatabase? _databaseInstance;

  static FirebaseDatabase get _database {
    _databaseInstance ??= FirebaseDatabase.instance;
    return _databaseInstance!;
  }

  late final DatabaseReference _rtdb;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ChatService() {
    _rtdb = _database.ref();
  }

  String get currentUserId => _auth.currentUser?.uid ?? LocalStoreHelper.getUID() ?? '';

  String generateChatId(String bookingId, String userId1, String userId2) {
    List<String> ids = [userId1, userId2]..sort();
    return '${bookingId}_${ids[0]}_${ids[1]}';
  }

  Future<String> createChat(
    String bookingId,
    String otherUserId,
    String otherUserName,
    String otherUserPhoto,
    String currentUserName,
    String currentUserPhoto,
    String currentUserType,
  ) async {
    debugPrint('[log] 🔄 Initiating new chat...');
    debugPrint('[log] 📋 Booking ID: $bookingId');
    debugPrint('[log] 👤 Current User ID: $currentUserId');
    debugPrint('[log] 👤 Other User ID: $otherUserId');
    debugPrint('[log] 🏷️ Current User Type: $currentUserType');

    final chatId = generateChatId(bookingId, currentUserId, otherUserId);
    debugPrint('[log] 💬 Generated Chat ID: $chatId');

    try {
      final chatRef = _rtdb.child('chats/$chatId');
      debugPrint('[log] 🔍 Checking if chat exists...');

      DataSnapshot? snapshot;
      bool hasCorruptedData = false;

      try {
        snapshot = await chatRef.get();
        debugPrint('[log] ✅ Chat exists check complete: ${snapshot.exists}');

        // Validate the data structure if chat exists
        if (snapshot.exists) {
          debugPrint(
            '[log] 🔍 Snapshot value type: ${snapshot.value.runtimeType}',
          );

          // Check if the value is a String (corrupted data)
          if (snapshot.value is String) {
            debugPrint(
              '[log] ⚠️ CORRUPTED DATA DETECTED: Chat node contains String instead of Map',
            );
            debugPrint('[log] 📝 Corrupted value: ${snapshot.value}');
            hasCorruptedData = true;
          } else if (snapshot.value is! Map) {
            debugPrint(
              '[log] ⚠️ CORRUPTED DATA DETECTED: Chat node contains ${snapshot.value.runtimeType} instead of Map',
            );
            hasCorruptedData = true;
          }
        }
      } catch (e) {
        // This error occurs when Firebase tries to parse corrupted data
        if (e.toString().contains('String') && e.toString().contains('Map')) {
          debugPrint('[log] ⚠️ CORRUPTED DATA DETECTED from exception: $e');
          hasCorruptedData = true;
          // Set snapshot to null so we treat it as non-existent
          snapshot = null;
        } else {
          debugPrint('[log] ❌ Error getting chat snapshot: $e');
          rethrow;
        }
      }

      // If data is corrupted, delete it and recreate
      if (hasCorruptedData) {
        debugPrint('[log] 🗑️ Attempting to clean corrupted chat data...');
        try {
          // Try to delete the corrupted chat node
          await chatRef.remove();
          debugPrint('[log] ✅ Corrupted chat node deleted');

          // Delete any corrupted userChats entries
          await _rtdb.child('userChats/$currentUserId/$chatId').remove();
          await _rtdb.child('userChats/$otherUserId/$chatId').remove();
          debugPrint('[log] ✅ Corrupted userChats entries deleted');
        } catch (deleteError) {
          debugPrint(
            '[log] ⚠️ Delete failed (likely permission denied): $deleteError',
          );
          debugPrint('[log] 💡 Will overwrite corrupted data instead');
          // Don't throw - we'll just overwrite the data below
        }

        // Clear or update the chatroomId in booking
        try {
          await _firestore.collection('bookings').doc(bookingId).update({
            'chatroomId': chatId, // Keep the same chatId
          });
          debugPrint('[log] ✅ Updated chatroomId in booking');
        } catch (firestoreError) {
          debugPrint('[log] ⚠️ Could not update booking: $firestoreError');
        }

        // Force snapshot to null to trigger recreation/overwrite
        snapshot = null;
      }

      if (snapshot == null || !snapshot.exists || hasCorruptedData) {
        debugPrint('[log] 🆕 Creating new chat...');

        // Create the main chat document
        await chatRef.set({
          'bookingId': bookingId,
          'participants': {
            currentUserType: currentUserId,
            currentUserType == 'customer' ? 'technician' : 'customer':
                otherUserId,
          },
          'createdAt': ServerValue.timestamp,
          'lastMessage': '',
          'lastMessageTime': ServerValue.timestamp,
          'lastMessageBy': '',
          'customerUnreadCount': 0,
          'technicianUnreadCount': 0,
        });
        debugPrint('[log] ✅ Main chat document created');

        // Create userChats for current user
        await _rtdb.child('userChats/$currentUserId/$chatId').set({
          'participantId': otherUserId,
          'participantName': otherUserName,
          'participantPhoto': otherUserPhoto,
          'participantType': currentUserType == 'customer'
              ? 'technician'
              : 'customer',
          'bookingId': bookingId,
          'lastMessage': '',
          'lastMessageTime': ServerValue.timestamp,
          'unreadCount': 0,
        });
        debugPrint('[log] ✅ Current user chat entry created');

        // Create userChats for other user (Best effort, might fail due to permissions)
        try {
          await _rtdb.child('userChats/$otherUserId/$chatId').set({
            'participantId': currentUserId,
            'participantName': currentUserName,
            'participantPhoto': currentUserPhoto,
            'participantType': currentUserType,
            'bookingId': bookingId,
            'lastMessage': '',
            'lastMessageTime': ServerValue.timestamp,
            'unreadCount': 0,
          });
          debugPrint('[log] ✅ Other user chat entry created');
        } catch (e) {
          debugPrint('[log] ⚠️ Could not create other user chat entry (likely permission denied): $e');
        }

        // Update booking with chatRoomId
        await _firestore.collection('bookings').doc(bookingId).update({
          'chatroomId': chatId,
        });
        debugPrint('[log] ✅ Booking updated with chatroom ID');
      } else {
        debugPrint('[log] ♻️ Chat already exists with valid data...');

        // Ensure userChats entry exists for current user
        debugPrint('[log] 🔍 Checking current user chat entry...');
        try {
          final userChatSnapshot = await _rtdb
              .child('userChats/$currentUserId/$chatId')
              .get();
          debugPrint(
            '[log] ✅ Current user chat entry exists: ${userChatSnapshot.exists}',
          );

          if (!userChatSnapshot.exists) {
            debugPrint('[log] 🆕 Creating missing current user chat entry...');
            await _rtdb.child('userChats/$currentUserId/$chatId').set({
              'participantId': otherUserId,
              'participantName': otherUserName,
              'participantPhoto': otherUserPhoto,
              'participantType': currentUserType == 'customer'
                  ? 'technician'
                  : 'customer',
              'bookingId': bookingId,
              'lastMessage': '',
              'lastMessageTime': ServerValue.timestamp,
              'unreadCount': 0,
            });
            debugPrint('[log] ✅ Current user chat entry created');
          }
        } catch (e) {
          if (e.toString().contains('String') && e.toString().contains('Map')) {
            debugPrint(
              '[log] ⚠️ Corrupted current user userChat detected, recreating...',
            );
            await _rtdb.child('userChats/$currentUserId/$chatId').set({
              'participantId': otherUserId,
              'participantName': otherUserName,
              'participantPhoto': otherUserPhoto,
              'participantType': currentUserType == 'customer'
                  ? 'technician'
                  : 'customer',
              'bookingId': bookingId,
              'lastMessage': '',
              'lastMessageTime': ServerValue.timestamp,
              'unreadCount': 0,
            });
            debugPrint('[log] ✅ Current user chat entry recreated');
          } else {
            rethrow;
          }
        }

        // Ensure userChats entry exists for other user
        debugPrint('[log] 🔍 Checking other user chat entry...');
        try {
          final otherUserChatSnapshot = await _rtdb
              .child('userChats/$otherUserId/$chatId')
              .get();
          debugPrint(
            '[log] ✅ Other user chat entry exists: ${otherUserChatSnapshot.exists}',
          );

          if (!otherUserChatSnapshot.exists) {
            debugPrint('[log] 🆕 Creating missing other user chat entry...');
            await _rtdb.child('userChats/$otherUserId/$chatId').set({
              'participantId': currentUserId,
              'participantName': currentUserName,
              'participantPhoto': currentUserPhoto,
              'participantType': currentUserType,
              'bookingId': bookingId,
              'lastMessage': '',
              'lastMessageTime': ServerValue.timestamp,
              'unreadCount': 0,
            });
            debugPrint('[log] ✅ Other user chat entry created');
          }
        } catch (e) {
          if (e.toString().contains('String') && e.toString().contains('Map')) {
            debugPrint(
              '[log] ⚠️ Corrupted other user userChat detected, recreating...',
            );
            await _rtdb.child('userChats/$otherUserId/$chatId').set({
              'participantId': currentUserId,
              'participantName': currentUserName,
              'participantPhoto': currentUserPhoto,
              'participantType': currentUserType,
              'bookingId': bookingId,
              'lastMessage': '',
              'lastMessageTime': ServerValue.timestamp,
              'unreadCount': 0,
            });
            debugPrint('[log] ✅ Other user chat entry recreated');
          } else {
            debugPrint('[log] ⚠️ Error checking other user chat entry (likely permission denied): $e');
            // Try best-effort update if read was denied but write might be allowed
            try {
              await _rtdb.child('userChats/$otherUserId/$chatId').update({
                'participantId': currentUserId,
                'participantName': currentUserName,
                'participantPhoto': currentUserPhoto,
                'participantType': currentUserType,
                'bookingId': bookingId,
              });
            } catch (_) {}
          }
        }
      }

      debugPrint('[log] ✅ Chat initialization complete!');
      return chatId;
    } catch (e, stackTrace) {
      debugPrint('[log] ❌ Chat error: Exception: $e');
      debugPrint('[log] 📚 Stack trace: $stackTrace');
      throw Exception('Failed to initiate chat: $e');
    }
  }

  Future<void> sendMessage(
    String chatId,
    String message,
    String senderType,
    String receiverId,
    String senderName,
    String senderPhoto,
    String bookingId,
  ) async {
    final messageRef = _rtdb.child('messages/$chatId').push();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      final messageData = {
        'senderId': currentUserId,
        'senderType': senderType,
        'text': message,
        'timestamp': timestamp,
        'status': 'sent',
      };
      await messageRef.set(messageData);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }

    // Metadata updates are best-effort. The message has already been sent.
    try {
      await _rtdb.child('chats/$chatId').update({
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'lastMessageBy': currentUserId,
      });
    } catch (e) {
      debugPrint('⚠️ Failed to update chat metadata: $e');
    }

    String unreadField = senderType == 'customer'
        ? 'technicianUnreadCount'
        : 'customerUnreadCount';
    try {
      await _rtdb
          .child('chats/$chatId/$unreadField')
          .set(ServerValue.increment(1));
    } catch (e) {
      debugPrint('⚠️ Failed to increment unread count: $e');
    }

    try {
      await _rtdb.child('userChats/$currentUserId/$chatId').update({
        'lastMessage': message,
        'lastMessageTime': timestamp,
      });
    } catch (e) {
      debugPrint('⚠️ Failed to update current user chat entry: $e');
    }

    final receiverChatRef = _rtdb.child('userChats/$receiverId/$chatId');

    // Update receiver's entry directly without reading first to avoid permission errors
    try {
      await receiverChatRef.update({
        'participantId': currentUserId,
        'participantName': senderName,
        'participantPhoto': senderPhoto,
        'participantType': senderType,
        'bookingId': bookingId,
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'unreadCount': ServerValue.increment(1),
      });
    } catch (e) {
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('String') ||
          e.toString().contains('Map')) {
        // If update fails due to permissions or corrupted data, try set/recreate
        try {
          await receiverChatRef.set({
            'participantId': currentUserId,
            'participantName': senderName,
            'participantPhoto': senderPhoto,
            'participantType': senderType,
            'bookingId': bookingId,
            'lastMessage': message,
            'lastMessageTime': timestamp,
            'unreadCount': 1,
          });
        } catch (e2) {
          debugPrint('⚠️ Failed to create/update receiver chat entry: $e2');
        }
      } else {
        debugPrint('⚠️ Unexpected error updating receiver chat entry: $e');
      }
    }
  }

  Stream<DatabaseEvent> getChatListStream() {
    return _rtdb
        .child('userChats/$currentUserId')
        .orderByChild('lastMessageTime')
        .onValue;
  }

  Stream<DatabaseEvent> getMessagesStream(String chatId) {
    return _rtdb.child('messages/$chatId').orderByChild('timestamp').onValue;
  }

  Future<void> markAsRead(String chatId, String userType) async {
    try {
      String unreadField = userType == 'customer'
          ? 'customerUnreadCount'
          : 'technicianUnreadCount';

      await _rtdb.child('chats/$chatId/$unreadField').set(0);
      await _rtdb.child('userChats/$currentUserId/$chatId/unreadCount').set(0);
    } catch (e) {
      debugPrint('❌ Error marking as read: $e');
    }
  }

  /// The roles a chat participant can hold.
  ///
  /// `participants` is keyed by ROLE, not by uid, and that is load-bearing.
  /// Both apps authenticate against the same Firebase project with phone auth,
  /// so a Firebase uid identifies a person, not a person-in-a-role: someone who
  /// is both a customer and a technician has exactly ONE uid. Keying the map by
  /// uid silently collapsed those two entries into one, leaving a chat that
  /// named nobody to notify. A chat has exactly one participant per role, so
  /// role is a key that cannot collide.
  static const List<String> chatRoles = ['customer', 'technician', 'admin'];

  /// The uids in a `participants` map, accepting either shape: the current
  /// role -> uid map, or the legacy uid -> role map still on older chats.
  static Set<String> participantUids(Object? participants) {
    if (participants is! Map) return {};
    final uids = <String>{};
    participants.forEach((key, value) {
      final k = key.toString();
      final v = value?.toString() ?? '';
      if (chatRoles.contains(k)) {
        if (v.isNotEmpty) uids.add(v);
      } else if (k.isNotEmpty) {
        uids.add(k);
      }
    });
    return uids;
  }

  /// Whether [chatId] can be reused as-is.
  ///
  /// Deliberately not a plain existence check. `markAsRead` writes
  /// `chats/<id>/<unreadCount>`, which in RTDB *creates* the node when it is
  /// missing - so a chat that was cleaned up and then merely opened comes back
  /// as a stub holding a counter and nothing else. It exists, but it names
  /// nobody, and notifyOnNewChatMessage cannot work out who to notify from it.
  Future<bool> isChatUsable(String chatId) async {
    try {
      final snapshot = await _rtdb.child('chats/$chatId/participants').get();
      if (!snapshot.exists) return false;
      final value = snapshot.value;
      if (value is! Map) return false;

      final namedRoles = value.entries
          .where((e) => chatRoles.contains(e.key.toString()))
          .where((e) => (e.value?.toString() ?? '').isNotEmpty)
          .length;
      if (namedRoles >= 2) return true;

      // Legacy uid -> role chats stay usable while they still name two people.
      // One that named the same person twice already collapsed to a single
      // entry, and recreating it in the role-keyed shape is the repair.
      return namedRoles == 0 && value.length >= 2;
    } catch (e) {
      debugPrint('⚠️ Could not verify chat $chatId: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getChatDetails(String chatId) async {
    final snapshot = await _rtdb.child('chats/$chatId').get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return null;
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _rtdb.child('messages/$chatId/$messageId').remove();
  }

  Stream<int> getUnreadCountStream(String? chatId) {
    if (chatId == null) return Stream.value(0);
    return _rtdb
        .child('userChats/$currentUserId/$chatId/unreadCount')
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          return value is int ? value : 0;
        })
        .asBroadcastStream();
  }

  Future<int> getUnreadCount(String userType) async {
    final snapshot = await _rtdb.child('userChats/$currentUserId').get();

    if (!snapshot.exists) return 0;

    int totalUnread = 0;
    final chatsMap = Map<String, dynamic>.from(snapshot.value as Map);

    chatsMap.forEach((key, value) {
      final chat = Map<String, dynamic>.from(value);
      totalUnread += (chat['unreadCount'] as int? ?? 0);
    });

    return totalUnread;
  }
}
