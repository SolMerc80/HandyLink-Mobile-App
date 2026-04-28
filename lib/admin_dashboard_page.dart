import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:handy_link/login_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;
  bool _isSidebarOpen = false;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Widget _buildDashboardOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize: 32, 
              fontWeight: FontWeight.w800, 
              color: Colors.grey[900],
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Monitor system activity and manage users.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _buildStatCard('Total Clients', 'clients', Icons.group, const Color(0xFF1976D2)),
              _buildStatCard('Service Providers', 'service_providers', Icons.engineering, const Color(0xFF388E3C)),
            ],
          ),
          const SizedBox(height: 24),
          _buildEscrowCard(),
        ],
      ),
    );
  }

  Widget _buildEscrowCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isNarrow = constraints.maxWidth < 600;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade800, Colors.orange.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('suspense_accounts').where('status', isEqualTo: 'held').snapshots(),
              builder: (context, snapshot) {
                double balance = 0.0;
                if (snapshot.hasData && snapshot.data != null) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    balance += (data['total_amount'] as num?)?.toDouble() ?? 0.0;
                  }
                }
                
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance, size: 40, color: Colors.white),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Escrow Funds (Suspense)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '\$${balance.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isNarrow) ...[
                      const SizedBox(width: 24),
                      const Icon(Icons.security, size: 60, color: Colors.white24),
                    ]
                  ],
                );
              },
            ),
          ),
        );
      }
    );
  }

  Widget _buildStatCard(String title, String collection, IconData icon, Color accentColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: const BoxConstraints(minWidth: 280),
          width: (MediaQuery.of(context).size.width - 72) / 2,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(collection).snapshots(),
            builder: (context, snapshot) {
              int count = 0;
              if (snapshot.hasData) {
                count = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final email = data['email'] ?? '';
                  return email.isNotEmpty;
                }).length;
              }
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 32, color: accentColor),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$count',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          title,
                          style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildProvidersList() {
    return _buildListContainer(
      title: 'Service Providers',
      subtitle: 'Manage and monitor all registered providers.',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('service_providers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Something went wrong'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final providers = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final email = data['email'] ?? '';
            return email.isNotEmpty;
          }).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: providers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var data = providers[index].data() as Map<String, dynamic>;
              String name = (data['businessName'] ?? '').toString();
              if (name.isEmpty) {
                 name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
              }
              if (name.isEmpty) name = 'Unnamed Provider';
              String email = data['email'] ?? 'No email';
              bool isSuspended = data['isSuspended'] ?? false;
              String uid = providers[index].id;

              return _buildUserTile(
                name: name,
                email: email,
                isSuspended: isSuspended,
                uid: uid,
                collection: 'service_providers',
                roleIcon: Icons.engineering,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildClientsList() {
    return _buildListContainer(
      title: 'Clients',
      subtitle: 'Manage and monitor all registered clients.',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clients').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Something went wrong'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final clients = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final email = data['email'] ?? '';
            return email.isNotEmpty;
          }).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: clients.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var data = clients[index].data() as Map<String, dynamic>;
              String name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
              if (name.isEmpty) name = 'Unnamed Client';
              String email = data['email'] ?? 'No email';
              bool isSuspended = data['isSuspended'] ?? false;
              String uid = clients[index].id;

              return _buildUserTile(
                name: name,
                email: email,
                isSuspended: isSuspended,
                uid: uid,
                collection: 'clients',
                roleIcon: Icons.person,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildUserTile({
    required String name, 
    required String email, 
    required bool isSuspended, 
    required String uid, 
    required String collection,
    required IconData roleIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: isSuspended ? Colors.red.shade50 : Colors.blue.shade50,
          child: Icon(isSuspended ? Icons.block : roleIcon, color: isSuspended ? Colors.red : Colors.blue.shade700),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
        subtitle: Text(email, style: TextStyle(color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSuspended ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isSuspended ? 'Suspended' : 'Active',
                style: TextStyle(
                  color: isSuspended ? Colors.red.shade700 : Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Switch(
              value: isSuspended,
              activeColor: Colors.red,
              onChanged: (value) async {
                await FirebaseFirestore.instance.collection(collection).doc(uid).update({'isSuspended': value});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationsList() {
    return _buildListContainer(
      title: 'Pending Verifications',
      subtitle: 'Review and approve identity documents.',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('service_providers')
            .where('verificationStatus', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Something went wrong'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final pendingProviders = snapshot.data!.docs;

          if (pendingProviders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('All verifications are up to date!', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: pendingProviders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var data = pendingProviders[index].data() as Map<String, dynamic>;
              String name = data['fullName'] ?? 'Unknown Name';
              String uid = pendingProviders[index].id;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.pending_actions, color: Colors.white),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  subtitle: const Text('New identity document submitted', overflow: TextOverflow.ellipsis),
                  trailing: ElevatedButton(
                    onPressed: () => _showVerificationDialog(data, uid),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Review'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSuspenseAccountsList() {
     return _buildListContainer(
      title: 'Suspense Accounts',
      subtitle: 'Track funds currently held in escrow.',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('suspense_accounts')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Something went wrong'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final suspenseAccounts = snapshot.data!.docs;

          if (suspenseAccounts.isEmpty) {
            return const Center(child: Text('No suspense transactions found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: suspenseAccounts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var data = suspenseAccounts[index].data() as Map<String, dynamic>;
              String bookingId = data['booking_id'] ?? 'Unknown';
              double totalAmount = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
              String status = data['status'] ?? 'unknown';
              DateTime createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();

              Color statusColor;
              IconData statusIcon;

              if (status == 'held') {
                statusColor = Colors.orange;
                statusIcon = Icons.lock_clock;
              } else if (status == 'released') {
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
              } else if (status == 'refunded') {
                statusColor = Colors.red;
                statusIcon = Icons.money_off;
              } else {
                statusColor = Colors.grey;
                statusIcon = Icons.help;
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(statusIcon, color: statusColor),
                  ),
                  title: Text('Booking: ${bookingId.length > 8 ? bookingId.substring(0, 8) : bookingId}...', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Created: ${createdAt.toLocal().toString().split('.')[0]}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
                      Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10)),
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

  Widget _buildReportsList() {
     return _buildListContainer(
      title: 'User Reports',
      subtitle: 'Review complaints and feedback from the community.',
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Something went wrong'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!.docs;

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No active reports to review.', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: reports.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var data = reports[index].data() as Map<String, dynamic>;
              String reporterName = data['reporterName'] ?? 'Unknown';
              String subject = data['subject'] ?? 'No Subject';
              String message = data['message'] ?? 'No Message';
              DateTime timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              String dateStr = timestamp.toLocal().toString().split(' ')[0];

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ExpansionTile(
                  leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.report_problem, color: Colors.white, size: 20)),
                  title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  subtitle: Text('From: $reporterName • $dateStr', overflow: TextOverflow.ellipsis),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Message Detail:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                            child: Text(message, style: const TextStyle(height: 1.5)),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('reports').doc(reports[index].id).delete();
                                },
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Mark as Resolved'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildListContainer({required String title, required String subtitle, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 16), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  void _showVerificationDialog(Map<String, dynamic> data, String uid) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Identity Review'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow(Icons.person, 'Name on ID', data['fullName'] ?? 'N/A'),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.badge, 'ID Number', data['nationalId'] ?? 'N/A'),
                const SizedBox(height: 24),
                const Text('Document Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (data['idImageUrl'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      data['idImageUrl'],
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const Center(child: Text('No image attached')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800], foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('service_providers').doc(uid).update({
                  'verificationStatus': 'rejected',
                  'isVerified': false,
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Reject'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              onPressed: () async {
                String fullName = data['fullName'] ?? '';
                List<String> parts = fullName.split(' ');
                String firstName = parts.isNotEmpty ? parts[0] : '';
                String lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

                await FirebaseFirestore.instance.collection('service_providers').doc(uid).update({
                  'verificationStatus': 'approved',
                  'isVerified': true,
                  'firstName': firstName,
                  'lastName': lastName,
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Approve Identity'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    double sidebarWidth = MediaQuery.of(context).size.width * 0.50; // Set to 50%
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(_isSidebarOpen ? Icons.menu_open : Icons.menu),
          onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
        ),
        title: const Text('Administrator Panel', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -1)),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
        actions: [
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  'HandyLink System',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.bold),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Content
          Positioned.fill(
            child: _selectedIndex == 0
                ? _buildDashboardOverview()
                : _selectedIndex == 1
                    ? _buildClientsList()
                    : _selectedIndex == 2
                        ? _buildProvidersList()
                        : _selectedIndex == 3
                            ? _buildVerificationsList()
                            : _selectedIndex == 4
                                ? _buildSuspenseAccountsList()
                                : _buildReportsList(),
          ),
          
          // Sidebar Overlay Background
          if (_isSidebarOpen)
            GestureDetector(
              onTap: () => setState(() => _isSidebarOpen = false),
              child: Container(
                color: Colors.black54,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            
          // Sidebar Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: _isSidebarOpen ? 0 : -sidebarWidth,
            top: 0,
            bottom: 0,
            curve: Curves.easeInOut,
            child: Container(
              width: sidebarWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  if (_isSidebarOpen)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(5, 0),
                    ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red.shade100, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.red.shade50,
                      child: Icon(Icons.shield, size: 40, color: Colors.red[800]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Super Administrator',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Main System Controller',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 32),
                  const Divider(indent: 20, endIndent: 20),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        _buildSidebarItem(0, Icons.grid_view_rounded, 'Dashboard Home'),
                        _buildSidebarItem(1, Icons.people_rounded, 'User Clients'),
                        _buildSidebarItem(2, Icons.engineering_rounded, 'Service Providers'),
                        _buildSidebarItem(3, Icons.how_to_reg_rounded, 'Verifications'),
                        _buildSidebarItem(4, Icons.payments_rounded, 'Escrow Accounts'),
                        _buildSidebarItem(5, Icons.flag_rounded, 'Conflict Reports'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'v1.0.4 - HandyLink',
                      style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        selected: isSelected,
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _isSidebarOpen = false; // Auto-close on selection
          });
        },
        leading: Icon(
          icon, 
          color: isSelected ? Colors.red[800] : Colors.grey[500],
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.red[800] : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected ? Colors.red.withOpacity(0.08) : Colors.transparent,
        visualDensity: const VisualDensity(vertical: -1),
      ),
    );
  }
}
