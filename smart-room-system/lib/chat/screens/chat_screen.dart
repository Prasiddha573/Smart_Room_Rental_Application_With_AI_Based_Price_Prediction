// lib/screens/chat_screen.dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async'; 
import 'package:get/get.dart';

import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/chat_service.dart';
import '../widgets/profile_image.dart';
import '../helper/my_date_util.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final ChatUser otherUser;

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = Get.find<ChatService>();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isUploading = false;
  List<ChatMessage> _messages = [];
  StreamSubscription? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessages() {
    _messagesSubscription?.cancel();
    _messagesSubscription = _chatService
        .getMessages(widget.conversation.conversationId)
        .listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
  final message = _messageController.text.trim();
  if (message.isEmpty) return;

  final currentUserId = _chatService.currentUserId;
  if (currentUserId == null) return;

  final optimisticMessage = ChatMessage(
      messageId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversation.conversationId,
      senderId: currentUserId,
      receiverId: widget.otherUser.sessionId,
      message: message,
      type: MessageType.text,
      timestamp: DateTime.now(),
      isRead: false,
      isDeleted: false,
    );

  // Add optimistic message immediately
  setState(() {
    _messages.insert(0, optimisticMessage);
  });
  
  _messageController.clear();
  _scrollToBottom();

  try {
    // Send actual message
    await _chatService.sendTextMessage(
      receiverId: widget.otherUser.sessionId,
      text: message,
    );
    
    // Refresh messages list
    _loadMessages();
    
    // Force a refresh in chat home screen
    Get.find<ChatService>().getUserConversations();
  } catch (e) {
    // Remove optimistic message on error
    setState(() {
      _messages.removeWhere((msg) => msg.messageId.startsWith('temp_'));
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to send message: $e', style: GoogleFonts.quicksand()),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  Future<void> _sendImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() => _isUploading = true);

      try {
        await _chatService.sendImageMessage(
          receiverId: widget.otherUser.sessionId,
          imageFile: File(pickedFile.path),
        );
      } catch (e) {
        _showErrorSnackbar('Failed to send image: $e');
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _takePhoto() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() => _isUploading = true);

      try {
        await _chatService.sendImageMessage(
          receiverId: widget.otherUser.sessionId,
          imageFile: File(pickedFile.path),
        );
      } catch (e) {
        _showErrorSnackbar('Failed to send image: $e');
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.quicksand()),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: FocusScope.of(context).unfocus,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 234, 248, 255),
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              // Messages List
              Expanded(
                child: _buildMessagesList(),
              ),

              // Uploading indicator
              if (_isUploading)
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),

              // Message Input
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: SafeArea(
        child: Row(
          children: [
            // Back Button
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.black54),
            ),

            // Profile Image
            ProfileImage(
              size: MediaQuery.of(context).size.height * .05,
              imageUrl: widget.otherUser.profilePath,
            ),

            const SizedBox(width: 10),

            // User Info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Name
                  Text(
                    widget.otherUser.name,
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 2),

                  // Online Status
                  Text(
                    widget.otherUser.isOnline
                        ? 'Online'
                        : MyDateUtil.getLastActiveTime(
                            context: context,
                            lastActive: widget.otherUser.lastSeen != null
                                ? widget.otherUser.lastSeen!
                                    .millisecondsSinceEpoch
                                    .toString()
                                : DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                          ),
                    style: GoogleFonts.quicksand(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'Say Hii! 👋',
          style: GoogleFonts.quicksand(
            fontSize: 20,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).size.height * .01,
        bottom: 10,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == _chatService.currentUserId;
        final isOptimistic = message.messageId.startsWith('temp_');

        return Opacity(
          opacity: isOptimistic ? 0.7 : 1.0,
          child: _buildMessageBubble(message, isMe, isOptimistic),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe, bool isOptimistic) {
    final isImage = message.type == MessageType.image;
    final messageTime = MyDateUtil.getMessageTime(
      time: message.timestamp.millisecondsSinceEpoch.toString(),
    );

    return Container(
      margin: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isMe ? MediaQuery.of(context).size.width * .3 : 8,
        right: isMe ? 8 : MediaQuery.of(context).size.width * .3,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Message Bubble
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * .7,
              ),
              padding: isImage
                  ? const EdgeInsets.all(2)
                  : const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color.fromARGB(255, 218, 255, 176)
                    : const Color.fromARGB(255, 221, 245, 255),
                border: Border.all(
                  color: isMe ? Colors.lightGreen : Colors.lightBlue,
                  width: 1,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(30),
                  topRight: const Radius.circular(30),
                  bottomLeft: isMe
                      ? const Radius.circular(30)
                      : const Radius.circular(0),
                  bottomRight: isMe
                      ? const Radius.circular(0)
                      : const Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: isImage
                  ? GestureDetector(
                      onTap: () => _showImageFullscreen(message.message),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: message.message,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(
                                Icons.image,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.message,
                          style: GoogleFonts.quicksand(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        if (isOptimistic)
                          const SizedBox(width: 8),
                        if (isOptimistic)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1,
                            ),
                          ),
                      ],
                    ),
            ),

            // Timestamp
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(
                right: isMe ? 8 : 0,
                left: isMe ? 0 : 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    messageTime,
                    style: GoogleFonts.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (isOptimistic)
                    const SizedBox(width: 4),
                  if (isOptimistic)
                    Text(
                      'Sending...',
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: MediaQuery.of(context).size.height * .01,
        horizontal: MediaQuery.of(context).size.width * .025,
      ),
      child: Row(
        children: [
          // Input field with buttons
          Expanded(
            child: Card(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(15)),
              ),
              elevation: 2,
              child: Row(
                children: [
                  // Image Gallery Button
                  IconButton(
                    onPressed: _sendImage,
                    icon: const Icon(
                      Icons.image,
                      color: Colors.blueAccent,
                      size: 26,
                    ),
                  ),

                  // Camera Button
                  IconButton(
                    onPressed: _takePhoto,
                    icon: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.blueAccent,
                      size: 26,
                    ),
                  ),

                  // Text Field
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type Something...',
                        hintStyle: GoogleFonts.quicksand(
                          color: Colors.blueAccent,
                        ),
                        border: InputBorder.none,
                      ),
                      style: GoogleFonts.quicksand(
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ),

                  SizedBox(width: MediaQuery.of(context).size.width * .02),
                ],
              ),
            ),
          ),

          // Send Button
          MaterialButton(
            onPressed: _sendMessage,
            minWidth: 0,
            padding: const EdgeInsets.only(
              top: 10,
              bottom: 10,
              right: 5,
              left: 10,
            ),
            shape: const CircleBorder(),
            color: Colors.green,
            child: const Icon(
              Icons.send,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  void _showImageFullscreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}