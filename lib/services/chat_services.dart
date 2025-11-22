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
    final chatId = generateChatId(bookingId, currentUserId, otherUserId);

    try {
      final chatRef = _rtdb.child('chats/$chatId');
      final snapshot = await chatRef.get();

      if (!snapshot.exists) {
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

        // Update booking with chatRoomId
        await _firestore.collection('bookings').doc(bookingId).update({
          'chatroomId': chatId,
        });
      } else {
        // Ensure userChats entry exists for current user
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

        // Ensure userChats entry exists for other user
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
      }

      return chatId;
    } catch (e) {
      throw Exception('Failed to create chat: $e');
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
      final receiverSnapshot = await receiverChatRef.get();

      if (receiverSnapshot.exists) {
        await receiverChatRef.update({
          'lastMessage': message,
          'lastMessageTime': timestamp,
          'unreadCount': ServerValue.increment(1),
        });
      } else {
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
