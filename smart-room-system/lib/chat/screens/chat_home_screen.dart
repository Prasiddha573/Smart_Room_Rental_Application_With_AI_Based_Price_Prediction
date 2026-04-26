// lib/chat/screens/chat_home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';

import '../services/chat_service.dart';
import '../../../services/auth_service.dart';
import '../models/chat_user.dart';
import '../models/chat_message.dart';
import 'chat_screen.dart';
import '../models/conversation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../screens/owner/owner_room_details_dialog.dart';

class ChatHomeScreen extends StatefulWidget {
  final String? preSelectedUserId; // Optional: user to highlight

  const ChatHomeScreen({super.key, this.preSelectedUserId});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  final ChatService _chatService = Get.find<ChatService>();
  final AuthService _authService = Get.find<AuthService>();

  String _activeTab = 'all';
  bool _isSelectionMode = false;
  final Set<String> _selectedConversations = {};
  String _searchQuery = '';
  late FocusNode _searchFocusNode;
  late TextEditingController _searchController;
  Timer? _refreshTimer;

  // Update the initState method in chat_home_screen.dart
  @override
void initState() {
  // INITIALIZE THESE FIRST!
  _searchFocusNode = FocusNode();
  _searchController = TextEditingController();
  
  super.initState();
  
  print('🎯 ChatHomeScreen loaded for user: ${_chatService.currentUserId}');
}

  @override
  void dispose() {
    _refreshTimer?.cancel(); // Cancel the timer to prevent memory leaks
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          print('🔄 Manual refresh triggered');
          setState(() {});
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: Column(
          children: [
            // Search Bar
            _buildSearchBar(),

            // Show tabs only when not searching
            if (_searchQuery.isEmpty) _buildTabBar(),

            // Chat List or Search Results
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildChatList()
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isSelectionMode ? _buildSelectionBottomBar() : null,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      title: _isSelectionMode
          ? Text(
              '${_selectedConversations.length} selected',
              style: GoogleFonts.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            )
          : Text(
              'Chats',
              style: GoogleFonts.quicksand(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
      centerTitle: true,
      leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close, color: Colors.black87),
              onPressed: _toggleSelectionMode,
            )
          : null,
      actions: [
        if (!_isSelectionMode)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) {
              if (value == 'select') {
                _toggleSelectionMode();
              } else if (value == 'refresh') {
                setState(() {});
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'select',
                child: Row(
                  children: [
                    const Icon(Icons.check_box_outlined, color: Colors.black87),
                    const SizedBox(width: 8),
                    Text('Select chats', style: GoogleFonts.quicksand()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    const Icon(Icons.refresh, color: Colors.black87),
                    const SizedBox(width: 8),
                    Text('Refresh', style: GoogleFonts.quicksand()),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: false,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search users...',
                  hintStyle: GoogleFonts.quicksand(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                style: GoogleFonts.quicksand(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  _searchFocusNode.unfocus();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTabButton('all', 'All'),
          const SizedBox(width: 8),
          _buildTabButton('unread', 'Unread'),
          const SizedBox(width: 8),
          _buildTabButton('favorite', 'Favourite'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String value, String label) {
    final isActive = _activeTab == value;
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? const Color(0xFFE7F3FF)
              : Colors.grey[100],
          foregroundColor: isActive ? Colors.blue : Colors.grey[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () => setState(() => _activeTab = value),
        child: Text(
          label,
          style: GoogleFonts.quicksand(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<List<Conversation>>(
      stream: _chatService.getUserConversations(),
      builder: (context, snapshot) {
        // DEBUG: Print connection state
        print('🔄 Chat List StreamBuilder: ${snapshot.connectionState}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('⏳ Loading conversations...');
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
        }

        if (snapshot.hasError) {
          print('❌ Error loading conversations: ${snapshot.error}');
          print('❌ Stack trace: ${snapshot.stackTrace}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading conversations',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    print('🔄 Retrying conversations load...');
                    setState(() {});
                  },
                  child: Text(
                    'Retry',
                    style: GoogleFonts.quicksand(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          print('📭 No data in snapshot');
          return _buildEmptyState();
        }

        final conversations = snapshot.data!;
        print('✅ Found ${conversations.length} conversations');

        // DEBUG: Print each conversation
        for (var i = 0; i < conversations.length; i++) {
          final conv = conversations[i];
          print('   [$i] ID: ${conv.conversationId}');
          print('       Users: ${conv.user1Id} ↔ ${conv.user2Id}');
          print('       Last message: ${conv.lastMessage}');
          print('       Last time: ${conv.lastMessageTime}');
          final unread =
              conv.unreadCount[_chatService.currentUserId ?? ''] ?? 0;
          print('       Unread count: $unread');
        }

        final filteredConversations = _filterConversations(conversations);
        print('🔍 Filtered to ${filteredConversations.length} conversations');

        if (filteredConversations.isEmpty) {
          print('📭 No conversations after filtering');
          return _buildEmptyState();
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: filteredConversations.length,
          itemBuilder: (context, index) {
            final conversation = filteredConversations[index];
            final isSelected = _selectedConversations.contains(
              conversation.conversationId,
            );

            print(
              '👤 Loading user for conversation: ${conversation.conversationId}',
            );

            return FutureBuilder<ChatUser?>(
              future: _getOtherUser(conversation),
              builder: (context, userSnapshot) {
                print(
                  '   👤 User snapshot state: ${userSnapshot.connectionState}',
                );

                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  print('   ⏳ Loading user data...');
                  return _buildLoadingChatItem();
                }

                if (userSnapshot.hasError) {
                  print('   ❌ Error loading user: ${userSnapshot.error}');
                  print('   ❌ Stack trace: ${userSnapshot.stackTrace}');
                  return const SizedBox();
                }

                if (!userSnapshot.hasData) {
                  print('   ❌ No user data found');
                  return const SizedBox();
                }

                final otherUser = userSnapshot.data!;
                final unreadCount =
                    conversation.unreadCount[_chatService.currentUserId ??
                        ''] ??
                    0;
                final isUnread = unreadCount > 0;
                final isFavorite =
                    conversation.isFavorite[_chatService.currentUserId ?? ''] ??
                    false;

                print(
                  '   ✅ User loaded: ${otherUser.name} (${otherUser.sessionId})',
                );
                print('   📱 Unread: $unreadCount, Favorite: $isFavorite');

                return _buildChatItem(
                  conversation: conversation,
                  otherUser: otherUser,
                  isSelected: isSelected,
                  isUnread: isUnread,
                  isFavorite: isFavorite,
                  unreadCount: unreadCount,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingChatItem() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[200],
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      title: Container(height: 16, width: 120, color: Colors.grey[200]),
      subtitle: Container(
        height: 12,
        width: 80,
        margin: const EdgeInsets.only(top: 4),
        color: Colors.grey[200],
      ),
    );
  }

  Widget _buildChatItem({
    required Conversation conversation,
    required ChatUser otherUser,
    required bool isSelected,
    required bool isUnread,
    required bool isFavorite,
    required int unreadCount,
  }) {
    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleConversationSelection(conversation.conversationId);
        } else {
          _openChatScreen(conversation, otherUser);
        }
      },
      onLongPress: () => _showChatOptions(conversation),
      child: Container(
        color: isSelected ? Colors.blue[50] : Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Stack(
            children: [
              _buildProfilePicture(otherUser),
              if (isFavorite)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  otherUser.name,
                  style: GoogleFonts.quicksand(
                    fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 16,
                    color: isUnread ? Colors.black : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isFavorite) Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                _formatTimestamp(conversation.lastMessageTime),
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  color: isUnread ? Colors.black87 : Colors.grey[600],
                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                  conversation.lastMessage,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.quicksand(
                    color: isUnread ? Colors.black87 : Colors.grey[600],
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isUnread && unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: GoogleFonts.quicksand(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          trailing: _isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (_) =>
                      _toggleConversationSelection(conversation.conversationId),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildProfilePicture(ChatUser user) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue, width: 1.5),
      ),
      child: ClipOval(
        child: user.profilePath.isNotEmpty
            ? Image.network(
                user.profilePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultProfilePicture(user);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildDefaultProfilePicture(user);
                },
              )
            : _buildDefaultProfilePicture(user),
      ),
    );
  }

  Widget _buildDefaultProfilePicture(ChatUser user) {
    return Container(
      color: Colors.blue[100],
      child: Center(
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
          style: GoogleFonts.quicksand(
            color: Colors.blue,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBottomBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.mark_email_read, color: Colors.amber),
            label: Text(
              'Read all',
              style: GoogleFonts.quicksand(
                color: Colors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: _markSelectedAsRead,
          ),
          Container(height: 30, width: 1, color: Colors.grey[300]),
          TextButton.icon(
            icon: const Icon(Icons.delete, color: Colors.red),
            label: Text(
              'Delete',
              style: GoogleFonts.quicksand(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: _deleteSelectedConversations,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          Text(
            'No conversations yet',
            style: GoogleFonts.quicksand(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start a chat by messaging a room owner',
            style: GoogleFonts.quicksand(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          // Optional: Add a refresh button
          ElevatedButton.icon(
            onPressed: () {
              print('🔄 Manual refresh triggered');
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Chat List'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return StreamBuilder<List<Conversation>>(
      stream: _chatService.getUserConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No conversations found',
              style: GoogleFonts.quicksand(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          );
        }

        final conversations = snapshot.data!;

        // Group conversations by other user and sort by most recent
        // Also filter out self-conversations
        final userMap = <String, Conversation>{};
        for (final conv in conversations) {
          // Skip self-conversations
          if (conv.user1Id == conv.user2Id) continue;

          final otherUserId = conv.user1Id == _chatService.currentUserId
              ? conv.user2Id
              : conv.user1Id;
          if (!userMap.containsKey(otherUserId) ||
              conv.lastMessageTime.isAfter(
                userMap[otherUserId]!.lastMessageTime,
              )) {
            userMap[otherUserId] = conv;
          }
        }

        // Sort by most recent message time
        final sortedUsers = userMap.entries.toList()
          ..sort(
            (a, b) =>
                b.value.lastMessageTime.compareTo(a.value.lastMessageTime),
          );

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: sortedUsers.length,
          itemBuilder: (context, index) {
            final entry = sortedUsers[index];
            final conversation = entry.value;

            return FutureBuilder<ChatUser?>(
              future: _chatService.getUserById(entry.key),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingChatItem();
                }

                if (!userSnapshot.hasData || userSnapshot.hasError) {
                  return const SizedBox();
                }

                final user = userSnapshot.data!;
                final userName = user.name.toLowerCase();
                final userEmail = user.email.toLowerCase();
                final query = _searchQuery.toLowerCase();

                // Filter by search query
                if (!userName.contains(query) && !userEmail.contains(query)) {
                  return const SizedBox();
                }

                return _buildSearchResultItem(user, conversation);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResultItem(ChatUser user, Conversation conversation) {
    final isFavorite =
        conversation.isFavorite[_chatService.currentUserId ?? ''] ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Stack(
        children: [
          _buildProfilePicture(user),
          if (isFavorite)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.star, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              user.name,
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isFavorite) Icon(Icons.star, size: 16, color: Colors.amber),
        ],
      ),
      subtitle: Text(
        user.email,
        style: GoogleFonts.quicksand(color: Colors.grey[600]),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        'Tap to chat',
        style: GoogleFonts.quicksand(
          fontSize: 12,
          color: Colors.blue,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        _openChatScreen(conversation, user);
      },
    );
  }

  // Helper Methods
  Future<ChatUser?> _getOtherUser(Conversation conversation) async {
    try {
      final currentUserId = _chatService.currentUserId;
      if (currentUserId == null) {
        print('❌ No current user ID found');
        return null;
      }

      print(
        '🔍 Getting other user for conversation: ${conversation.conversationId}',
      );
      print('   Current user: $currentUserId');
      print(
        '   User1: ${conversation.user1Id}, User2: ${conversation.user2Id}',
      );

      final otherUserId = conversation.user1Id == currentUserId
          ? conversation.user2Id
          : conversation.user1Id;

      print('   Other user ID: $otherUserId');

      if (otherUserId.isEmpty) {
        print('❌ Other user ID is empty');
        return null;
      }

      final otherUser = await _chatService.getUserById(otherUserId);

      if (otherUser == null) {
        print('❌ No user found with ID: $otherUserId');
        print('   Creating temporary user...');

        // Create a temporary user as fallback
        return ChatUser(
          id: otherUserId,
          name: 'User $otherUserId',
          email: '',
          phone: '',
          sessionId: otherUserId,
          profilePath: '',
          createdAt: DateTime.now(),
          isOnline: false,
        );
      }

      print('✅ Found other user: ${otherUser.name}');
      return otherUser;
    } catch (e) {
      print('❌ Error getting other user: $e');
      print('Stack trace: ${e.toString()}');
      return null;
    }
  }

  List<Conversation> _filterConversations(List<Conversation> conversations) {
    final currentUserId = _chatService.currentUserId;
    if (currentUserId == null) return [];

    // First, filter out self-conversations (where user is chatting with themselves)
    final validConversations = conversations.where((conv) {
      return conv.user1Id != conv.user2Id;
    }).toList();

    switch (_activeTab) {
      case 'unread':
        return validConversations.where((conv) {
          final unreadCount = conv.unreadCount[currentUserId] ?? 0;
          return unreadCount > 0;
        }).toList();

      case 'favorite':
        return validConversations.where((conv) {
          return conv.isFavorite[currentUserId] ?? false;
        }).toList();

      default:
        return validConversations;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
      final minute = timestamp.minute.toString().padLeft(2, '0');
      final amPm = timestamp.hour < 12 ? 'AM' : 'PM';
      return '$hour:$minute $amPm';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (timestamp.isAfter(weekAgo)) {
      switch (messageDate.weekday) {
        case 1:
          return 'Mon';
        case 2:
          return 'Tue';
        case 3:
          return 'Wed';
        case 4:
          return 'Thu';
        case 5:
          return 'Fri';
        case 6:
          return 'Sat';
        case 7:
          return 'Sun';
        default:
          return '';
      }
    } else {
      return '${timestamp.month}/${timestamp.day}';
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedConversations.clear();
      }
    });
  }

  void _toggleConversationSelection(String conversationId) {
    setState(() {
      if (_selectedConversations.contains(conversationId)) {
        _selectedConversations.remove(conversationId);
        if (_selectedConversations.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedConversations.add(conversationId);
      }
    });
  }

  void _showChatOptions(Conversation conversation) {
    final currentUserId = _chatService.currentUserId;
    if (currentUserId == null) return;

    final unreadCount = conversation.unreadCount[currentUserId] ?? 0;
    final isUnread = unreadCount > 0;
    final isFavorite = conversation.isFavorite[currentUserId] ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              // Favorite/Unfavorite option
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: isFavorite
                      ? const Color(0xFFFFF7E7)
                      : const Color(0xFFFFF7E7),
                  child: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                ),
                title: Text(
                  isFavorite ? 'Remove from favorite' : 'Add to favorite',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleFavorite(conversation);
                },
              ),
              // Read/Unread option
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: isUnread
                      ? const Color(0xFFE7F3FF)
                      : const Color(0xFFE7F3FF),
                  child: Icon(
                    isUnread ? Icons.mark_email_read : Icons.markunread,
                    color: isUnread ? Colors.green : Colors.blue,
                  ),
                ),
                title: Text(
                  isUnread ? 'Mark as read' : 'Mark as unread',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (isUnread) {
                    _markConversationAsRead(conversation);
                  } else {
                    _markConversationAsUnread(conversation);
                  }
                },
              ),
              // Delete option
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFE7E7),
                  child: Icon(Icons.delete, color: Colors.red),
                ),
                title: Text(
                  'Delete',
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteConversation(conversation);
                },
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _openChatScreen(Conversation conversation, ChatUser otherUser) {
    // Mark messages as read when opening chat
    _chatService.markMessagesAsRead(conversation.conversationId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatScreen(conversation: conversation, otherUser: otherUser),
      ),
    );
  }

  void _markSelectedAsRead() {
    if (_selectedConversations.isEmpty) return;

    for (final conversationId in _selectedConversations) {
      _chatService.markMessagesAsRead(conversationId);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Marked ${_selectedConversations.length} conversation${_selectedConversations.length > 1 ? 's' : ''} as read',
          style: GoogleFonts.quicksand(),
        ),
        backgroundColor: Colors.green,
      ),
    );

    _selectedConversations.clear();
    _toggleSelectionMode();
  }

  void _deleteSelectedConversations() {
    if (_selectedConversations.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Conversations',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedConversations.length} conversation${_selectedConversations.length > 1 ? 's' : ''}?',
          style: GoogleFonts.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.quicksand(color: Colors.blue),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Implement delete conversations from Firestore
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Deleted ${_selectedConversations.length} conversation${_selectedConversations.length > 1 ? 's' : ''}',
                    style: GoogleFonts.quicksand(),
                  ),
                  backgroundColor: Colors.red,
                ),
              );
              _selectedConversations.clear();
              _toggleSelectionMode();
            },
            child: Text(
              'Delete',
              style: GoogleFonts.quicksand(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(Conversation conversation) async {
    try {
      final currentUserId = _chatService.currentUserId;
      if (currentUserId == null) return;

      final newFavoriteStatus =
          !(conversation.isFavorite[currentUserId] ?? false);

      // Update Firestore
      await _chatService.toggleFavorite(
        conversation.conversationId,
        currentUserId,
        newFavoriteStatus,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newFavoriteStatus ? 'Added to favorites' : 'Removed from favorites',
            style: GoogleFonts.quicksand(),
          ),
          backgroundColor: newFavoriteStatus ? Colors.green : Colors.amber,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e', style: GoogleFonts.quicksand()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markConversationAsRead(Conversation conversation) async {
    try {
      await _chatService.markMessagesAsRead(conversation.conversationId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Marked as read'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _markConversationAsUnread(Conversation conversation) async {
    try {
      final currentUserId = _chatService.currentUserId;
      if (currentUserId == null) return;

      // Increment unread count by 1
      await _chatService.markConversationAsUnread(conversation.conversationId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Marked as unread'),
          backgroundColor: Colors.amber,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _deleteConversation(Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Conversation',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete this conversation?',
          style: GoogleFonts.quicksand(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.quicksand(color: Colors.blue),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement delete conversation from Firestore
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Conversation deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text(
              'Delete',
              style: GoogleFonts.quicksand(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
