import 'package:cloud_firestore/cloud_firestore.dart';

class SuspenseAccountService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createSuspenseRecord(String bookingId, double totalAmount) async {
    final querySnapshot = await _db
        .collection('suspense_accounts')
        .where('booking_id', isEqualTo: bookingId)
        .get();

    // Idempotency check: don't create if it already exists
    if (querySnapshot.docs.isNotEmpty) {
      return; 
    }

    await _db.collection('suspense_accounts').add({
      'booking_id': bookingId,
      'total_amount': totalAmount,
      'status': 'held',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> releaseFunds(String bookingId, String providerId) async {
    final querySnapshot = await _db
        .collection('suspense_accounts')
        .where('booking_id', isEqualTo: bookingId)
        .where('status', isEqualTo: 'held')
        .get();

    if (querySnapshot.docs.isEmpty) return;

    final providerRef = _db.collection('service_providers').doc(providerId);
    
    for (var doc in querySnapshot.docs) {
      await _db.runTransaction((transaction) async {
        final providerDoc = await transaction.get(providerRef);
        final suspenseDoc = await transaction.get(doc.reference);

        if (!suspenseDoc.exists || suspenseDoc.data()?['status'] != 'held') return;

        double amount = (suspenseDoc.data()?['total_amount'] as num?)?.toDouble() ?? 0.0;
        double currentWallet = (providerDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;

        transaction.update(providerRef, {'walletBalance': currentWallet + amount});
        transaction.update(doc.reference, {'status': 'released'});
      });
    }
  }

  Future<void> refundFunds(String bookingId) async {
    final querySnapshot = await _db
        .collection('suspense_accounts')
        .where('booking_id', isEqualTo: bookingId)
        .where('status', isEqualTo: 'held')
        .get();

    if (querySnapshot.docs.isEmpty) return;

    for (var doc in querySnapshot.docs) {
      await _db.collection('suspense_accounts').doc(doc.id).update({
        'status': 'refunded',
      });
    }
  }
}
