import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'map_screen.dart';
import 'chat_screen.dart';
import 'package:handy_link/wallet_service.dart';
import 'package:handy_link/services/suspense_account_service.dart';

class ServiceProviderRequestsPage extends StatefulWidget {
  const ServiceProviderRequestsPage({super.key});

  @override
  State<ServiceProviderRequestsPage> createState() =>
      _ServiceProviderRequestsPageState();
}

class _ServiceProviderRequestsPageState
    extends State<ServiceProviderRequestsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateRequestStatus(String docId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(docId)
          .update({'status': status});
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request $status successfully!'),
            backgroundColor: status == 'accepted' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _proposeFee(String docId) async {
    final TextEditingController feeController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Enter Service Fee'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Propose a fee for this job. The client will authorize this amount to proceed.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: feeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Fee Amount (\$)',
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
                  onPressed: isSubmitting ? null : () async {
                    if (feeController.text.isEmpty) return;
                    setModalState(() => isSubmitting = true);
                    try {
                      double fee = double.parse(feeController.text);
                      await FirebaseFirestore.instance
                          .collection('bookings')
                          .doc(docId)
                          .update({
                            'status': 'awaiting_payment',
                            'feeAmount': fee,
                          });
                      if (mounted) Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fee proposed! Waiting on client.'), backgroundColor: Colors.orange));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                      setModalState(() => isSubmitting = false);
                    }
                  },
                  child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text('Submit Fee'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildRequestsList(bool isPending) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not logged in.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('providerId', isEqualTo: user.uid)
          .where('status', whereIn: isPending ? ['pending', 'awaiting_payment'] : ['accepted', 'declined', 'finished'])
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
          return Center(
            child: Text(
              isPending ? 'No pending requests.' : 'No past requests.',
              style: const TextStyle(fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;

            final clientName = data['clientName'] ?? 'Unknown Client';
            final clientId = data['clientId'] ?? '';
            final description = data['description'] ?? 'No description';
            final status = data['status'] ?? 'pending';
            
            final bool depositPaid = data['deposit_paid'] == true;
  
            Timestamp? preferredDateTimestamp = data['preferredDate'];
            String dateString = 'Not specified';
            if (preferredDateTimestamp != null) {
              final date = preferredDateTimestamp.toDate();
              dateString = '${date.day}/${date.month}/${date.year}';
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
                          child: Text(
                            clientName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'pending'
                                ? Colors.orange.shade100
                                : status == 'accepted'
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: status == 'pending'
                                  ? Colors.orange.shade800
                                  : status == 'accepted'
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Preferred Date: $dateString',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Job Description:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    if (status == 'pending') ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _updateRequestStatus(docId, 'declined'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _proposeFee(docId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Propose Fee'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ] else if (status == 'awaiting_payment') ...[
                       Container(
                         padding: const EdgeInsets.all(12),
                         color: depositPaid ? Colors.green.shade50 : Colors.orange.shade50,
                         child: Row(
                           children: [
                             Icon(depositPaid ? Icons.check_circle : Icons.hourglass_bottom, color: depositPaid ? Colors.green : Colors.orange),
                             const SizedBox(width: 8),
                             Expanded(
                               child: Text(
                                 depositPaid 
                                    ? 'Client has paid 20% deposit. You can now accept the booking.'
                                    : 'Waiting for client to pay 20% deposit via Paynow.', 
                                 style: TextStyle(color: depositPaid ? Colors.green : Colors.orange)
                               )
                             ),
                           ],
                         ),
                       ),
                       const SizedBox(height: 8),
                       if (depositPaid) ...[
                         SizedBox(
                           width: double.infinity,
                           child: ElevatedButton(
                             onPressed: () => _updateRequestStatus(docId, 'accepted'),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.green,
                               foregroundColor: Colors.white,
                             ),
                             child: const Text('Accept Booking'),
                           ),
                         ),
                         const SizedBox(height: 8),
                       ],
                    ] else if (status == 'accepted') ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MapScreen(
                                      userRole: 'provider',
                                      targetId: data['clientId'],
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map),
                              label: const Text('Track'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Finish Job'),
                                    content: const Text('Are you sure you want to mark this job as finished? The held deposit will be transferred to your wallet.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          try {
                                            // Mark booking as finished
                                            await FirebaseFirestore.instance.collection('bookings').doc(docId).update({'status': 'finished'});
                                            // Release held deposit funds to provider wallet
                                            await SuspenseAccountService().releaseFunds(docId, user.uid);
                                            
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job finished! Deposit transferred to your wallet.'), backgroundColor: Colors.green));
                                            }
                                          } catch(e) {
                                            if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                        child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Finish'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Universal Message button at the bottom of the card
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (!depositPaid || (status != 'accepted' && status != 'finished')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Chat is only available after deposit is paid and booking is accepted.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                otherUserId: clientId,
                                otherUserName: clientName,
                                userRole: 'provider',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('Message Client'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (depositPaid && (status == 'accepted' || status == 'finished')) ? Colors.blue : Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Requests'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestsList(true),  // Pending tab
          _buildRequestsList(false), // History tab
        ],
      ),
    );
  }
}
