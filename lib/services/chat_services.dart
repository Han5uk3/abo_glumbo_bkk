import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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

    final chatId = generateChatId(bookingId, currentUserId, otherUserId);

    try {
      final chatRef = _rtdb.child('chats/$chatId');

      DataSnapshot? snapshot;
      bool hasCorruptedData = false;

      try {
        snapshot = await chatRef.get();

        // Validate the data structure if chat exists
        if (snapshot.exists) {
          // Check if the value is a String (corrupted data)
          if (snapshot.value is String) {
            hasCorruptedData = true;
          } else if (snapshot.value is! Map) {
            hasCorruptedData = true;
          }
        }
      } catch (e) {
        // This error occurs when Firebase tries to parse corrupted data
        if (e.toString().contains('String') && e.toString().contains('Map')) {
          hasCorruptedData = true;
          // Set snapshot to null so we treat it as non-existent
          snapshot = null;
        } else {
          rethrow;
        }
      }

      // If data is corrupted, delete it and recreate
      if (hasCorruptedData) {
        try {
          // Try to delete the corrupted chat node
          await chatRef.remove();

          // Delete any corrupted userChats entries
          await _rtdb.child('userChats/$currentUserId/$chatId').remove();
          await _rtdb.child('userChats/$otherUserId/$chatId').remove();
        } catch (deleteError) {
          // Don't throw - we'll just overwrite the data below
        }

        // Clear or update the chatroomId in booking
        try {
          await _firestore.collection('bookings').doc(bookingId).update({
            'chatroomId': chatId, // Keep the same chatId
          });
        } catch (_) {
        }

        // Force snapshot to null to trigger recreation/overwrite
        snapshot = null;
      }

      if (snapshot == null || !snapshot.exists || hasCorruptedData) {
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
        } catch (_) {
        }

        // Update booking with chatRoomId
        await _firestore.collection('bookings').doc(bookingId).update({
          'chatroomId': chatId,
        });
      } else {
        // Ensure userChats entry exists for current user
        try {
          final userChatSnapshot = await _rtdb
              .child('userChats/$currentUserId/$chatId')
              .get();

          if (!userChatSnapshot.exists) {
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
          }
        } catch (e) {
          if (e.toString().contains('String') && e.toString().contains('Map')) {
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
          } else {
            rethrow;
          }
        }

        // Ensure userChats entry exists for other user
        try {
          final otherUserChatSnapshot = await _rtdb
              .child('userChats/$otherUserId/$chatId')
              .get();

          if (!otherUserChatSnapshot.exists) {
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
          }
        } catch (e) {
          if (e.toString().contains('String') && e.toString().contains('Map')) {
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
          } else {
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

      return chatId;
    } catch (e) {
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
    } catch (_) {
    }

    String unreadField = senderType == 'customer'
        ? 'technicianUnreadCount'
        : 'customerUnreadCount';
    try {
      await _rtdb
          .child('chats/$chatId/$unreadField')
          .set(ServerValue.increment(1));
    } catch (_) {
    }

    try {
      await _rtdb.child('userChats/$currentUserId/$chatId').update({
        'lastMessage': message,
        'lastMessageTime': timestamp,
      });
    } catch (_) {
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
        } catch (_) {
        }
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
    } catch (_) {
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
