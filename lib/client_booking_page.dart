import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'location_service.dart';

class ServiceProviderModel {
  final String uid;
  final String name;
  final String serviceType;
  final double rating;
  final String description;
  final String phone;
  final bool isVerified;
  final double? latitude;
  final double? longitude;
  double? distance;

  ServiceProviderModel({
    required this.uid,
    required this.name,
    required this.serviceType,
    required this.rating,
    required this.description,
    required this.phone,
    required this.isVerified,
    this.latitude,
    this.longitude,
    this.distance,
  });
}

class ClientBookingPage extends StatefulWidget {
  const ClientBookingPage({super.key});

  @override
  State<ClientBookingPage> createState() => _ClientBookingPageState();
}

class _ClientBookingPageState extends State<ClientBookingPage> {
  final TextEditingController _searchController = TextEditingController();

  String _formatDistance(double? meters) {
    if (meters == null) return '';
    if (meters < 1000) return '${meters.toStringAsFixed(0)}m away';
    return '${(meters / 1000).toStringAsFixed(1)}km away';
  }

  String _selectedServiceType = 'All';
  double _minRating = 0.0;
  String _searchQuery = '';
  
  bool _isLoading = true;

  final List<String> _serviceTypes = [
    'All',
    'Plumbing',
    'Electrical',
    'Carpentry',
    'Cleaning',
    'Painting',
    'Gardening',
    'Other',
  ];

  List<ServiceProviderModel> _allProviders = [];
  List<ServiceProviderModel> _filteredProviders = [];

  @override
  void initState() {
    super.initState();
    _fetchProviders();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProviders() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('service_providers').get();
      
      final providers = snapshot.docs.map((doc) {
        final data = doc.data();
        return ServiceProviderModel(
          uid: doc.id,
          name: data['businessName'] ?? data['name'] ?? data['firstName'] ?? 'Unknown Provider',
          serviceType: data['serviceType'] ?? 'Other',
          rating: double.tryParse(data['rating']?.toString() ?? '') ?? 0.0, // Default to 0.0 for now
          description: data['description'] ?? 'No description provided.',
          phone: data['phoneNumber'] ?? '',
          isVerified: data['isVerified'] == true,
          latitude: (data['latitude'] as num?)?.toDouble(),
          longitude: (data['longitude'] as num?)?.toDouble(),
        );
      }).toList();

      final currentPos = LocationService().currentPosition;
      if (currentPos != null) {
        for (var provider in providers) {
          if (provider.latitude != null && provider.longitude != null) {
            provider.distance = LocationService().calculateDistance(
              currentPos.latitude, currentPos.longitude, 
              provider.latitude!, provider.longitude!
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _allProviders = providers;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load providers: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredProviders = _allProviders.where((provider) {
        final matchesSearch =
            provider.name.toLowerCase().contains(_searchQuery) ||
            provider.serviceType.toLowerCase().contains(_searchQuery);
        final matchesType =
            _selectedServiceType == 'All' ||
            provider.serviceType.toLowerCase().trim() == _selectedServiceType.toLowerCase().trim();
        final matchesRating = provider.rating >= _minRating;

        return matchesSearch && matchesType && matchesRating;
      }).toList();

      final currentPos = LocationService().currentPosition;
      if (currentPos != null) {
        _filteredProviders.sort((a, b) {
          if (a.distance != null && b.distance != null) {
            return a.distance!.compareTo(b.distance!);
          } else if (a.distance != null) {
            return -1; // a has distance, push up
          } else if (b.distance != null) {
            return 1; // b has distance, push up
          }
          return b.rating.compareTo(a.rating);
        });
      } else {
        _filteredProviders.sort((a, b) => b.rating.compareTo(a.rating));
      }
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Providers',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text(
                    'Service Type',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    children: _serviceTypes.map((type) {
                      return ChoiceChip(
                        label: Text(type),
                        selected: _selectedServiceType == type,
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        onSelected: (bool selected) {
                          setModalState(() {
                            _selectedServiceType = type;
                          });
                          _applyFilters();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Minimum Rating',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_minRating.toStringAsFixed(1)} Stars & Up',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _minRating,
                    min: 0.0,
                    max: 5.0,
                    divisions: 10,
                    label: '${_minRating.toStringAsFixed(1)} Stars',
                    onChanged: (value) {
                      setModalState(() {
                        _minRating = value;
                      });
                      _applyFilters();
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBookingDialog(ServiceProviderModel provider) {
    final TextEditingController descriptionController = TextEditingController();
    DateTime? selectedDate = DateTime.now().add(const Duration(days: 1));
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Book ${provider.name}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  
                  // Job Description
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Job Description',
                      hintText: 'Describe what you need help with...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Preferred Date
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Preferred Date'),
                    subtitle: Text(
                      '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                    ),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate!,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null && picked != selectedDate) {
                        setModalState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (descriptionController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a job description')),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              try {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user == null) throw Exception('User not logged in');

                                // Get client info
                                final clientDoc = await FirebaseFirestore.instance.collection('clients').doc(user.uid).get();
                                final clientName = clientDoc.exists 
                                    ? '${clientDoc.data()?['firstName'] ?? ''} ${clientDoc.data()?['lastName'] ?? ''}'.trim()
                                    : 'Client';

                                await FirebaseFirestore.instance.collection('bookings').add({
                                  'clientId': user.uid,
                                  'providerId': provider.uid,
                                  'clientName': clientName,
                                  'providerBusinessName': provider.name,
                                  'providerIsVerified': provider.isVerified,
                                  'serviceType': provider.serviceType,
                                  'description': descriptionController.text.trim(),
                                  'preferredDate': Timestamp.fromDate(selectedDate!),
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'status': 'pending',
                                });

                                if (mounted) {
                                  Navigator.pop(context); // Close modal
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Booking request sent successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to send request: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setModalState(() => isSubmitting = false);
                                }
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Send Request', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
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
        title: const Text('Book a Service'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search and Filter Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search painting, plumbing...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.filter_list, color: Colors.white),
                          onPressed: _showFilterDialog,
                          tooltip: 'Filter',
                        ),
                      ),
                    ],
                  ),
                ),

                // Results Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        '${_filteredProviders.length} Providers Found',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      if (_selectedServiceType != 'All' ||
                          _minRating > 0 ||
                          _searchQuery.isNotEmpty) ...[
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _selectedServiceType = 'All';
                              _minRating = 0.0;
                              _applyFilters();
                            });
                          },
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ],
                  ),
                ),

                // Provider List
                Expanded(
                  child: _filteredProviders.isEmpty
                      ? const Center(
                          child: Text(
                            'No service providers found.',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                          ).copyWith(bottom: 16.0),
                          itemCount: _filteredProviders.length,
                          itemBuilder: (context, index) {
                            final provider = _filteredProviders[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 30,
                                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                          child: Text(
                                            provider.name.isNotEmpty 
                                                ? provider.name.substring(0, 1).toUpperCase() 
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 24,
                                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      provider.name,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (provider.isVerified) ...[
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.verified, color: Colors.blue, size: 20),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                provider.serviceType,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Theme.of(context).colorScheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.star, color: Colors.amber, size: 18),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    provider.rating.toStringAsFixed(1),
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  if (provider.distance != null) ...[
                                                    const SizedBox(width: 12),
                                                    const Icon(Icons.location_on, color: Colors.grey, size: 16),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      _formatDistance(provider.distance),
                                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                provider.description,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => _showBookingDialog(provider),
                                            style: ElevatedButton.styleFrom(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              backgroundColor: Theme.of(context).colorScheme.primary,
                                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            child: const Text('Book Now'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
