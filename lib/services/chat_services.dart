import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

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

  String get currentUserId => _auth.currentUser!.uid;

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

        // Create userChats for other user
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
            rethrow;
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
    try {
      final messageRef = _rtdb.child('messages/$chatId').push();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await messageRef.set({
        'senderId': currentUserId,
        'senderType': senderType,
        'text': message,
        'timestamp': timestamp,
        'status': 'sent',
        'mediaUrl': null,
        'mediaType': null,
      });

      await _rtdb.child('chats/$chatId').update({
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'lastMessageBy': currentUserId,
      });

      String unreadField = senderType == 'customer'
          ? 'technicianUnreadCount'
          : 'customerUnreadCount';
      await _rtdb
          .child('chats/$chatId/$unreadField')
          .set(ServerValue.increment(1));

      await _rtdb.child('userChats/$currentUserId/$chatId').update({
        'lastMessage': message,
        'lastMessageTime': timestamp,
      });

      // Check if receiver's userChats entry exists, create if not
      final receiverChatRef = _rtdb.child('userChats/$receiverId/$chatId');

      bool receiverChatExists = false;
      bool receiverChatCorrupted = false;

      try {
        final receiverSnapshot = await receiverChatRef.get();
        receiverChatExists = receiverSnapshot.exists;

        // Check if data is corrupted
        if (receiverSnapshot.exists && receiverSnapshot.value is String) {
          receiverChatCorrupted = true;
        }
      } catch (e) {
        if (e.toString().contains('String') && e.toString().contains('Map')) {
          receiverChatCorrupted = true;
        } else {
          rethrow;
        }
      }

      if (receiverChatExists && !receiverChatCorrupted) {
        // Update existing entry
        try {
          await receiverChatRef.update({
            'lastMessage': message,
            'lastMessageTime': timestamp,
            'unreadCount': ServerValue.increment(1),
          });
        } catch (e) {
          // If update fails, recreate the entry
          debugPrint('⚠️ Failed to update receiver chat, recreating: $e');
          receiverChatCorrupted = true;
        }
      }

      if (!receiverChatExists || receiverChatCorrupted) {
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
      }
    } catch (e) {
      throw Exception('Failed to send message: $e');
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
        });
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
