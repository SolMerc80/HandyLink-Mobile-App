import 'package:cloud_firestore/cloud_firestore.dart';

class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> topUpWallet(String collection, String uid, double amount) async {
    final userRef = _db.collection(collection).doc(uid);
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(userRef);
      if (!doc.exists) throw Exception("User does not exist!");
      
      final currentBalance = (doc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
      transaction.update(userRef, {'walletBalance': currentBalance + amount});
    });
  }

  Future<void> payToEscrow(String clientId, String bookingId, double amount) async {
    final clientRef = _db.collection('clients').doc(clientId);
    final suspenseRef = _db.collection('system').doc('escrow');
    final bookingRef = _db.collection('bookings').doc(bookingId);

    await _db.runTransaction((transaction) async {
      final clientDoc = await transaction.get(clientRef);
      final suspenseDoc = await transaction.get(suspenseRef);

      final clientBalance = (clientDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
      if (clientBalance < amount) {
        throw Exception("Insufficient funds in wallet.");
      }

      double currentEscrow = 0.0;
      if (suspenseDoc.exists) {
        currentEscrow = (suspenseDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      } else {
         transaction.set(suspenseRef, {'balance': 0.0});
      }

      transaction.update(clientRef, {'walletBalance': clientBalance - amount});
      transaction.update(suspenseRef, {'balance': currentEscrow + amount});
      transaction.update(bookingRef, {'status': 'accepted'});
    });
  }

  Future<void> releaseEscrowToProvider(String providerId, String bookingId, double amount) async {
    final providerRef = _db.collection('service_providers').doc(providerId);
    final suspenseRef = _db.collection('system').doc('escrow');
    final bookingRef = _db.collection('bookings').doc(bookingId);

    await _db.runTransaction((transaction) async {
      final providerDoc = await transaction.get(providerRef);
      final suspenseDoc = await transaction.get(suspenseRef);

      double currentEscrow = (suspenseDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      if (currentEscrow < amount) {
        throw Exception("System error: escrow funds mismatched.");
      }

      final providerBalance = (providerDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;

      transaction.update(suspenseRef, {'balance': currentEscrow - amount});
      transaction.update(providerRef, {'walletBalance': providerBalance + amount});
      transaction.update(bookingRef, {'status': 'finished'});
    });
  }
}
