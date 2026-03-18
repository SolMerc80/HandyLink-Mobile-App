import 'package:flutter/material.dart';

/// A page that displays a list of reviews from clients.
/// 
/// This widget handles rendering mock review data and allows for the 
/// simulation of adding a new review to the list.
class ViewReviewsPage extends StatefulWidget {
  const ViewReviewsPage({super.key});

  @override
  State<ViewReviewsPage> createState() => _ViewReviewsPageState();
}

class _ViewReviewsPageState extends State<ViewReviewsPage> {
  // Mock data to simulate reviews from clients
  List<Map<String, String>> reviews = [
    {'username': 'Client1', 'review': 'Great service!'},
    {'username': 'Client2', 'review': 'Excellent work, highly recommended.'},
    {'username': 'Client3', 'review': 'Will hire again.'},
  ];

  // Function to add a new review (called when a client submits a review)
  void addReview(String username, String reviewMessage) {
    setState(() {
      reviews.add({'username': username, 'review': reviewMessage});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Reviews'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: reviews.isEmpty
          ? const Center(child: Text('No reviews yet.'))
          : ListView.builder(
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                // Reversing the display so the newest is at the top might be nice
                // but standard chronological is fine too. Let's do chronological.
                final review = reviews[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      child: Icon(
                        Icons.person,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                    title: Text(
                      review['username'] ?? 'Unknown User',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(review['review'] ?? ''),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Simulate receiving a new review from a client
          addReview('New Client', 'Just got this done, amazing service!');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Simulated new review received')),
          );
        },
        label: const Text('Simulate New Review'),
        icon: const Icon(Icons.add_comment),
        tooltip: 'Simulate a client adding a review',
      ),
    );
  }
}
