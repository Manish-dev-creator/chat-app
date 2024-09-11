import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatelessWidget {
  final String chatRoomId;
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ChatScreen({required this.chatRoomId});

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      final currentUser = _auth.currentUser!;
      final otherUserId = _getOtherUserId();

      // Add message to Firestore
      await _firestore.collection('chatRooms').doc(chatRoomId).collection('messages').add({
        'text': _messageController.text,
        'createdAt': Timestamp.now(),
        'userId': currentUser.uid,
      });

      // Update the last message for the chat room
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': {
          'text': _messageController.text,
          'userId': currentUser.uid,
        },
        'unread.$otherUserId': FieldValue.increment(1),
      });

      // Update the last seen timestamp for the current user
      await _firestore.collection('users').doc(currentUser.uid).update({
        'lastSeen': Timestamp.now(),
      });

      _messageController.clear();
    }
  }

  String _getOtherUserId() {
    final currentUser = _auth.currentUser!.uid;
    final users = chatRoomId.split('_');
    return users[0] == currentUser ? users[1] : users[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Room'),
        backgroundColor: Colors.deepPurple[600], // Dark purple for app bar
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple[50]!, Colors.deepPurple[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder(
                stream: _firestore
                    .collection('chatRooms')
                    .doc(chatRoomId)
                    .collection('messages')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  return ListView.builder(
                    reverse: true,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var message = snapshot.data!.docs[index];
                      return MessageBubble(
                        text: message['text'],
                        userId: message['userId'],
                        createdAt: message['createdAt'],
                        isMe: message['userId'] == _auth.currentUser!.uid,
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        labelText: 'Type your message...',
                        labelStyle: TextStyle(color: Colors.deepPurple[700]), // Dark purple for label
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30), // Rounded corners
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.deepPurple[700]), // Matching send button color
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String text;
  final String userId;
  final Timestamp createdAt;
  final bool isMe;

  const MessageBubble({
    required this.text,
    required this.userId,
    required this.createdAt,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox();
        }

        var user = snapshot.data!;
        String userEmail = user['email'] ?? 'Unknown';
        String userAvatar = userEmail[0].toUpperCase();
        String lastSeenFormatted = _formatDate(createdAt);

        return Container(
          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) CircleAvatar(
                backgroundColor: Colors.deepPurple[400], // Purple for other user
                child: Text(userAvatar, style: TextStyle(color: Colors.white)),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                decoration: BoxDecoration(
                  color: isMe ? Colors.deepPurple[700] : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                    ),
                    SizedBox(height: 5),
                    Text(
                      lastSeenFormatted,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isMe) SizedBox(width: 8),
              if (isMe) CircleAvatar(
                backgroundColor: Colors.deepPurple[400], // Purple for current user
                child: Text(userAvatar, style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    Duration difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 7) {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
