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
            currentUserId: currentUserType,
            otherUserId: currentUserType == 'customer'
                ? 'technician'
                : 'customer',
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

  /// How often the presence flag is refreshed while the chat is on screen.
  /// Must stay well below CHAT_PRESENCE_TTL_MS in functions/index.js so a live
  /// viewer is never mistaken for a stale one.
  static const Duration _presenceHeartbeat = Duration(seconds: 15);

  Timer? _presenceTimer;

  /// Marks this user as actively viewing [chatId], which is the only thing that
  /// stops the backend from pushing them the message.
  ///
  /// The flag is a heartbeat rather than a plain `true`: it expires on its own,
  /// so a flag left behind by a suspended, killed or disconnected app degrades
  /// into "not viewing" and the push goes out instead of being silently lost.
  Future<void> setActiveChat(String chatId) async {
    final String uid = currentUserId;
    if (uid.isEmpty || chatId.isEmpty) return;

    final ref = _rtdb.child('chats/$chatId/presence/$uid');
    debugPrint('🚀 Presence start: path=chats/$chatId/presence/$uid');

    // Register the disconnect hook before the first write, so a drop between
    // the two can't leave the flag behind.
    try {
      await ref.onDisconnect().remove();
    } catch (e) {
      debugPrint('⚠️ OnDisconnect register failed: $e');
    }

    await _writePresence(ref);

    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(_presenceHeartbeat, (_) {
      _writePresence(ref);
    });
  }

  Future<void> _writePresence(DatabaseReference ref) async {
    try {
      await ref.set({'active': true, 'updatedAt': ServerValue.timestamp});
    } catch (e) {
      // Fail open: without a heartbeat the backend sends the push, which is the
      // safe direction to fail in.
      debugPrint('⚠️ Presence write failed: $e');
    }
  }

  Future<void> clearActiveChat(String chatId) async {
    final String uid = currentUserId;

    _presenceTimer?.cancel();
    _presenceTimer = null;

    if (uid.isEmpty || chatId.isEmpty) return;

    final ref = _rtdb.child('chats/$chatId/presence/$uid');
    try {
      await ref.onDisconnect().cancel();
    } catch (e) {
      debugPrint('⚠️ Failed to cancel presence onDisconnect: $e');
    }
    try {
      await ref.remove();
    } catch (e) {
      debugPrint('⚠️ Failed to clear presence: $e');
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

  Future<bool> chatExists(String chatId) async {
    final snapshot = await _rtdb.child('chats/$chatId').get();
    return snapshot.exists;
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
