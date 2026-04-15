import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A page for clients to view their past bookings and delete them.
class ClientBookingHistoryPage extends StatefulWidget {
  const ClientBookingHistoryPage({super.key});

  @override
  State<ClientBookingHistoryPage> createState() =>
      _ClientBookingHistoryPageState();
}

class _ClientBookingHistoryPageState extends State<ClientBookingHistoryPage> {
  final Set<String> _selectedBookingIds = {};
  bool _isSelectionMode = false;

  void _toggleSelection(String docId) {
    setState(() {
      if (_selectedBookingIds.contains(docId)) {
        _selectedBookingIds.remove(docId);
        if (_selectedBookingIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedBookingIds.add(docId);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _deleteSelectedBookings() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Bookings'),
          content: Text(
            'Are you sure you want to delete ${_selectedBookingIds.length} booking(s)?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selectedBookingIds) {
        final docRef = FirebaseFirestore.instance.collection('bookings').doc(id);
        batch.delete(docRef);
      }
      try {
        await batch.commit();
        setState(() {
          _selectedBookingIds.clear();
          _isSelectionMode = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected bookings deleted successfully.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete bookings: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode
            ? '${_selectedBookingIds.length} Selected'
            : 'Booking History'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedBookingIds.clear();
                    _isSelectionMode = false;
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelectedBookings,
            ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Not logged in.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('clientId', isEqualTo: user.uid)
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
                  return const Center(
                    child: Text(
                      'No booking history.',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final providerName = data['providerBusinessName'] ?? 'Unknown Provider';
                    final serviceType = data['serviceType'] ?? 'Service';
                    final status = data['status'] ?? 'pending';
                    final description = data['description'] ?? 'No description';

                    Timestamp? preferredDateTimestamp = data['preferredDate'];
                    DateTime currentDate = DateTime.now();
                    String dateString = 'Not specified';
                    if (preferredDateTimestamp != null) {
                      currentDate = preferredDateTimestamp.toDate();
                      dateString = '${currentDate.day}/${currentDate.month}/${currentDate.year}';
                    }

                    Color statusColor;
                    switch (status) {
                      case 'accepted':
                        statusColor = Colors.green;
                        break;
                      case 'declined':
                        statusColor = Colors.red;
                        break;
                      case 'pending':
                      default:
                        statusColor = Colors.orange;
                        break;
                    }

                    final isSelected = _selectedBookingIds.contains(docId);

                    return GestureDetector(
                      onLongPress: () => _toggleSelection(docId),
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(docId);
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: isSelected ? 4 : 2,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
                            : null,
                        shape: RoundedRectangleBorder(
                          side: isSelected
                              ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                              : BorderSide.none,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      providerName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                serviceType,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Date requested: $dateString',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Job details:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                description,
                                style: TextStyle(color: Colors.grey[800]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
