import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _signOut(BuildContext context) async {
    await _auth.signOut();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AuthScreen()));
  }

  void _startChat(BuildContext context, String otherUserId) async {
    final currentUser = _auth.currentUser!.uid;
    final chatRoomId = getChatRoomId(currentUser, otherUserId);

    final chatRoomDoc = _firestore.collection('chatRooms').doc(chatRoomId);
    final chatRoomSnapshot = await chatRoomDoc.get();

    if (!chatRoomSnapshot.exists) {
      await chatRoomDoc.set({
        'users': [currentUser, otherUserId],
        'unread': {
          currentUser: 0,
          otherUserId: 0,
        },
        'lastMessage': {
          'text': '',
          'userId': '',
        },
      });
    } else {
      // Reset the unread count for the current user to 0
      await chatRoomDoc.update({
        'unread.$currentUser': 0,
      });
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatRoomId: chatRoomId),
      ),
    );
  }



  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Users'),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: Offset(0, 4), // Shadow position
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by Name',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.teal[700]),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                ),
                style: TextStyle(color: Colors.teal[700]),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var filteredUsers = snapshot.data!.docs.where((user) {
                  final email = user['email'].toLowerCase();
                  return email.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    var user = filteredUsers[index];
                    if (user.id == _auth.currentUser!.uid) {
                      return Container(); // Don't show the current user
                    }

                    return  StreamBuilder<DocumentSnapshot>(
                      stream: _firestore.collection('chatRooms').doc(getChatRoomId(_auth.currentUser!.uid, user.id)).snapshots(),
                      builder: (context, chatSnapshot) {
                        String lastMessage = '';
                        int unreadCount = 0;

                        if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                          var chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
                          lastMessage = chatData['lastMessage']?['text'] ?? 'No messages yet';
                          unreadCount = chatData['unread']?[_auth.currentUser!.uid] ?? 0;
                        }

                        return InkWell(
                          onTap: () => _startChat(context, user.id),
                          child: Card(
                            elevation: 5,
                            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: Colors.white,
                            child: ListTile(
                              contentPadding: EdgeInsets.all(16),
                              leading: CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.teal[300],
                                child: Text(
                                  user['email'][0].toUpperCase(),
                                  style: TextStyle(color: Colors.white, fontSize: 20),
                                ),
                              ),
                              title: Text(
                                user['email'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.teal[800],
                                ),
                              ),
                              subtitle: Text(
                                lastMessage,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              trailing: unreadCount > 0
                                  ? CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.red,
                                child: Text(
                                  '$unreadCount',
                                  style: TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              )
                                  : null,
                            ),
                          ),
                        );
                      },
                    );

                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String getChatRoomId(String userA, String userB) {
  return userA.compareTo(userB) < 0 ? '${userA}_$userB' : '${userB}_$userA';
}
