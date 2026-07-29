import 'package:abo_glumbo_bbk/services/time_service.dart';
import 'package:abo_glumbo_bbk/common_widgets/loader.dart';
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:abo_glumbo_bbk/services/chat_services.dart';
import 'package:abo_glumbo_bbk/services/notification_services.dart';
import 'package:abo_glumbo_bbk/styles/app_color.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String participantName;
  final String participantId;
  final String participantPhoto;
  final String customerName;
  final String customerPhoto;
  final String bookingId; // Added bookingId

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.participantName,
    required this.participantId,
    required this.participantPhoto,
    required this.customerName,
    required this.customerPhoto,
    required this.bookingId, // Added bookingId
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String userType = 'customer';

  bool _isLoading = false;
  int _lastMessageCount = 0;
  bool _shouldScrollToBottom = true;
  late final String _currentUserId;

  double _previousKeyboardHeight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUserId = _chatService.currentUserId;
    _chatService.markAsRead(widget.chatId, userType);
    _chatService.setActiveChat(widget.chatId);
    
    // Set active chat for notification suppression
    NotificationServices.setActiveChatId(widget.chatId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Listen to scroll position to determine if user is viewing older messages
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Listen for keyboard changes
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight != _previousKeyboardHeight) {
      _previousKeyboardHeight = keyboardHeight;

      // If keyboard is opening (height > 0), scroll to bottom
      if (keyboardHeight > 0) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _scrollToBottom(force: true);
          }
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      // If user is within 100 pixels of bottom, auto-scroll on new messages
      final shouldScroll = (maxScroll - currentScroll) < 100;

      // Only update state if the value actually changed
      if (_shouldScrollToBottom != shouldScroll) {
        _shouldScrollToBottom = shouldScroll;
      }
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!_scrollController.hasClients) return;
    if (!force && !_shouldScrollToBottom) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();

    if (messageText.isEmpty || _isLoading) return;

    // Clear immediately for better UX
    _messageController.clear();

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await _chatService.sendMessage(
        widget.chatId,
        messageText,
        userType,
        widget.participantId,
        widget.customerName,
        widget.customerPhoto,
        widget.bookingId,
      );

      // Scroll to bottom after message is sent
      if (mounted) {
        // Use a small delay to ensure the message is rendered
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _scrollToBottom(force: true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.failedToSendMessage(e.toString()) ?? 'Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.bgBlueTint,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withOpacity(0.2),
              backgroundImage: widget.participantPhoto.isNotEmpty
                  ? NetworkImage(widget.participantPhoto)
                  : null,
              child: widget.participantPhoto.isEmpty
                  ? Text(
                      widget.participantName.isNotEmpty
                          ? widget.participantName[0].toUpperCase()
                          : 'T',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.participantName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    localization.technician,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: _chatService.getMessagesStream(widget.chatId),
                builder: (context, snapshot) {
                  // Only show loading on first load, not on updates
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Loader(color: AppColors.primary, size: 20),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            localization.errorLoadingMessages,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.snapshot.value == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            localization.noMessages,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            localization.startConversation,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final messagesMap = snapshot.data!.snapshot.value as Map;
                  final messagesList = messagesMap.entries.toList()
                    ..sort(
                      (a, b) => (a.value['timestamp'] ?? 0).compareTo(
                        b.value['timestamp'] ?? 0,
                      ),
                    );

                  // Only scroll if message count changed
                  final currentMessageCount = messagesList.length;
                  if (currentMessageCount > _lastMessageCount &&
                      _shouldScrollToBottom) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });
                  }
                  // Update count directly without setState to avoid rebuild loop
                  _lastMessageCount = currentMessageCount;

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 16,
                    ),
                    itemCount: messagesList.length,
                    itemBuilder: (context, index) {
                      final messageEntry = messagesList[index];
                      final message = messageEntry.value as Map;

                      final senderId = message['senderId'] as String? ?? '';

                      String text = message['text'] as String? ?? '';
                      if (text.isEmpty) {
                        text = message['message'] as String? ?? '';
                      }
                      if (text.isEmpty) {
                        final mediaUrl = message['mediaUrl'] as String?;
                        if (mediaUrl != null && mediaUrl.isNotEmpty) {
                          final mediaType =
                              message['mediaType'] as String? ?? '';
                          text = mediaType == 'image'
                              ? '📷 Photo'
                              : (mediaType == 'video' ? '🎥 Video' : '[Media]');
                        } else {
                          text = '[Empty message]';
                        }
                      }

                      final timestamp = message['timestamp'] as int? ?? 0;
                      final isMe = senderId == _currentUserId;

                      bool showDateSeparator = false;
                      if (index == 0) {
                        showDateSeparator = true;
                      } else {
                        final prevMessage =
                            messagesList[index - 1].value as Map;
                        final prevTimestamp =
                            prevMessage['timestamp'] as int? ?? 0;
                        if (!_isSameDay(timestamp, prevTimestamp)) {
                          showDateSeparator = true;
                        }
                      }

                      return Column(
                        children: [
                          if (showDateSeparator)
                            _buildDateSeparator(timestamp, localization),
                          _buildMessageBubble(
                            message: text,
                            isMe: isMe,
                            timestamp: timestamp,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(localization),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(int timestamp, AppLocalizations localization) {
    // Day boundaries follow the Saudi calendar, so a message sent at 01:00 KSA
    // is filed under the KSA day for everyone reading the thread — and the
    // "Today" label agrees with the dates shown on the separators around it.
    final date = KsaTime.fromInstant(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
    final today = KsaTime.today;
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = localization.today;
    } else if (messageDate == yesterday) {
      dateText = localization.yesterday;
    } else {
      dateText = DateFormat('MMM dd, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isMe,
    required int timestamp,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.blue1 : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(timestamp),
              style: TextStyle(
                fontSize: 11,
                color: isMe ? Colors.white.withOpacity(0.8) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(AppLocalizations localization) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,

        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                onSubmitted: (_) => _sendMessage(),
                style: TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: localization.typeMessage,
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[500],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: _isLoading ? Colors.grey[400] : AppColors.blue1,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: Loader(color: AppColors.bgWhite, size: 16),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(int timestamp1, int timestamp2) {
    final date1 = DateTime.fromMillisecondsSinceEpoch(timestamp1);
    final date2 = DateTime.fromMillisecondsSinceEpoch(timestamp2);
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatTime(int timestamp) {
    if (timestamp == 0) return '';
    // Compare and render on the Saudi calendar, so "today" means today in KSA
    // and the clock matches every other time in the app.
    final dateTime = KsaTime.fromInstant(
      DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
    final now = KsaTime.now;
    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      return DateFormat.jm().format(dateTime);
    }
    return DateFormat('MMM d, h:mm a').format(dateTime);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _chatService.setActiveChat(widget.chatId);
      NotificationServices.setActiveChatId(widget.chatId);
      _chatService.markAsRead(widget.chatId, userType);
    } else {
      // paused / inactive / hidden / detached - the chat is no longer on
      // screen, so drop both the backend presence flag and the on-device
      // suppression. Anything that arrives from here on must alert the user.
      _chatService.clearActiveChat(widget.chatId);
      NotificationServices.setActiveChatId(null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatService.clearActiveChat(widget.chatId);
    // Clear active chat for notification suppression
    NotificationServices.setActiveChatId(null);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
