import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewReviewsPage extends StatefulWidget {
  const ViewReviewsPage({super.key});

  @override
  State<ViewReviewsPage> createState() => _ViewReviewsPageState();
}

class _ViewReviewsPageState extends State<ViewReviewsPage> {
  Future<Map<String, dynamic>> _fetchClientData(String clientId) async {
    try {
      if (clientId.isEmpty) return {};
      final doc = await FirebaseFirestore.instance.collection('clients').doc(clientId).get();
      if (doc.exists) {
        return doc.data()!;
      }
    } catch (_) {}
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('View Reviews')),
        body: const Center(child: Text('Not logged in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('View Reviews'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('service_providers')
            .doc(user.uid)
            .collection('reviews')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No reviews yet.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final reviewData = docs[index].data() as Map<String, dynamic>;
              final String reviewText = reviewData['review'] ?? '';
              final num ratingNum = reviewData['rating'] ?? 0;
              final String clientId = reviewData['clientId'] ?? '';

              return FutureBuilder<Map<String, dynamic>>(
                future: _fetchClientData(clientId),
                builder: (context, clientSnap) {
                  String username = 'Client';
                  if (clientSnap.hasData && clientSnap.data!.isNotEmpty) {
                    final data = clientSnap.data!;
                    username = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
                    if (username.isEmpty) username = 'Client';
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        child: Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              username,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(ratingNum.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                            ],
                          ),
                        ],
                      ),
                      subtitle: reviewText.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(reviewText),
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
