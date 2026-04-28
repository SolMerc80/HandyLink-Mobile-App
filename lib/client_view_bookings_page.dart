import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'package:handy_link/wallet_service.dart';
import 'package:handy_link/services/paynow_service.dart';

class ClientViewBookingsPage extends StatefulWidget {
  const ClientViewBookingsPage({super.key});

  @override
  State<ClientViewBookingsPage> createState() => _ClientViewBookingsPageState();
}

class _ClientViewBookingsPageState extends State<ClientViewBookingsPage> {
  Future<void> _submitReview(String docId, String providerId, int rating, String reviewText) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final batch = FirebaseFirestore.instance.batch();
      
      final bookingRef = FirebaseFirestore.instance.collection('bookings').doc(docId);
      batch.update(bookingRef, {'isReviewed': true});
      
      final reviewRef = FirebaseFirestore.instance.collection('service_providers').doc(providerId).collection('reviews').doc();
      batch.set(reviewRef, {
        'clientId': user.uid,
        'rating': rating,
        'review': reviewText,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();

      final reviewsSnapshot = await FirebaseFirestore.instance.collection('service_providers').doc(providerId).collection('reviews').get();
      if (reviewsSnapshot.docs.isNotEmpty) {
        double totalRating = 0.0;
        for (var doc in reviewsSnapshot.docs) {
          totalRating += (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
        }
        double averageRating = totalRating / reviewsSnapshot.docs.length;
        await FirebaseFirestore.instance.collection('service_providers').doc(providerId).update({
          'rating': averageRating,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit review: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showReviewDialog(String docId, String providerId, String providerName) {
    int _rating = 5;
    final TextEditingController _reviewController = TextEditingController();
    bool _isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Rate $providerName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How was the service?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setModalState(() {
                            _rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reviewController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Write a review (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : () async {
                    setModalState(() => _isSubmitting = true);
                    await _submitReview(docId, providerId, _rating, _reviewController.text.trim());
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                      'You have no booking requests.',
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
                    final providerId = data['providerId'] ?? '';
                    final providerName = data['providerBusinessName'] ?? 'Unknown Provider';
                    final isProviderVerified = data['providerIsVerified'] ?? false;
                    final serviceType = data['serviceType'] ?? 'Service';
                    final status = data['status'] ?? 'pending';
                    final isReviewed = data['isReviewed'] ?? false;
                    final description = data['description'] ?? 'No description';
                    final bool depositPaid = data['deposit_paid'] == true;

                    Timestamp? preferredDateTimestamp = data['preferredDate'];
                    String dateString = 'Not specified';
                    if (preferredDateTimestamp != null) {
                      final date = preferredDateTimestamp.toDate();
                      dateString = '${date.day}/${date.month}/${date.year}';
                    }

                    Color statusColor;
                    switch (status) {
                      case 'accepted':
                        statusColor = Colors.green;
                        break;
                      case 'declined':
                        statusColor = Colors.red;
                        break;
                      case 'finished':
                        statusColor = Colors.blue;
                        break;
                      case 'awaiting_payment':
                        statusColor = Colors.purple;
                        break;
                      case 'pending':
                      default:
                        statusColor = Colors.orange;
                        break;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
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
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          providerName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isProviderVerified) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified, color: Colors.blue, size: 20),
                                      ],
                                    ],
                                  ),
                                ),
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
                            
                            const SizedBox(height: 16),
                            if (status == 'awaiting_payment') ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  children: [
                                    Text('Fee Proposed: \$${data['feeAmount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 8),
                                    if (depositPaid) 
                                      const Text('Deposit of 20% Paid via Paynow', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                                    else
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          double feeAmt = (data['feeAmount'] as num?)?.toDouble() ?? 0.0;
                                          double depositAmt = feeAmt * 0.20;
                                          final _phoneController = TextEditingController();
                                          
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) {
                                              bool isWaiting = false;
                                              return StatefulBuilder(
                                                builder: (context, setModalState) {
                                                  return AlertDialog(
                                                    title: const Text('Mobile Money Deposit'),
                                                    content: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text('Pay \$${depositAmt.toStringAsFixed(2)} via EcoCash/OneMoney'),
                                                        const SizedBox(height: 16),
                                                        if (!isWaiting)
                                                          TextField(
                                                            controller: _phoneController,
                                                            keyboardType: TextInputType.phone,
                                                            decoration: const InputDecoration(
                                                              labelText: 'EcoCash/OneMoney Number (e.g. 0771234567)',
                                                              border: OutlineInputBorder(),
                                                            ),
                                                          )
                                                        else
                                                          Column(
                                                            children: [
                                                              const SizedBox(height: 20, width: 20, child: CircularProgressIndicator()),
                                                              const SizedBox(height: 16),
                                                              Text(
                                                                'A USSD prompt has been sent to ${_phoneController.text}.\nPlease enter your PIN on your phone to approve the transaction.',
                                                                textAlign: TextAlign.center,
                                                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                                              ),
                                                            ],
                                                          ),
                                                      ],
                                                    ),
                                                    actions: [
                                                      if (!isWaiting)
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: const Text('Cancel'),
                                                        ),
                                                      if (!isWaiting)
                                                        ElevatedButton.icon(
                                                          onPressed: () async {
                                                            if (_phoneController.text.isEmpty) return;
                                                            setModalState(() => isWaiting = true);
                                                            
                                                            try {
                                                              // Simulate the time taken for user to enter their Pin on USSD Prompt
                                                              await Future.delayed(const Duration(seconds: 4));

                                                              await PaynowService().processPaymentCallback(
                                                                bookingId: docId,
                                                                providerId: providerId,
                                                                depositAmount: depositAmt,
                                                                pollUrl: 'simulate',
                                                                paynowHash: 'simulated_push',
                                                              );
                                                              
                                                              if (mounted) {
                                                                Navigator.pop(context);
                                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful!'), backgroundColor: Colors.green));
                                                              }
                                                            } catch (e) {
                                                              setModalState(() => isWaiting = false);
                                                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: $e'), backgroundColor: Colors.red));
                                                            }
                                                          },
                                                          icon: const Icon(Icons.payment),
                                                          label: const Text('Initiate Payment'),
                                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                                        ),
                                                    ],
                                                  );
                                                }
                                              );
                                            }
                                          );
                                        },
                                        icon: const Icon(Icons.payment),
                                        label: const Text('Pay 20% Deposit via Paynow'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                      )
                                  ]
                                )
                              ),
                              const SizedBox(height: 16),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            otherUserId: providerId,
                                            otherUserName: providerName,
                                            userRole: 'client',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.message),
                                    label: const Text('Message Provider'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: (depositPaid && (status == 'accepted' || status == 'finished')) ? Colors.blue : Colors.grey,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                if (status == 'finished' && !isReviewed) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showReviewDialog(docId, providerId, providerName),
                                      icon: const Icon(Icons.star),
                                      label: const Text('Rate'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber,
                                        foregroundColor: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
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
