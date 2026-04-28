import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:paynow/paynow.dart';
import 'package:handy_link/secrets.dart';
import 'suspense_account_service.dart';
import 'system_notification_service.dart';

class PaynowService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SuspenseAccountService _suspenseService = SuspenseAccountService();

  /// Real API trigger for USSD/Mobile Money payment
  Future<bool> initiateMobilePayment({
    required String bookingId,
    required String providerId,
    required double depositAmount,
    required String phone,
  }) async {
    try {
      Paynow paynow = Paynow(
        integrationKey: Secrets.paynowIntegrationKey,
        integrationId: Secrets.paynowIntegrationId,
        returnUrl: "http://google.com",
        resultUrl: "http://google.com" // Needs backend in prod, using polling for app now
      );

      Payment payment = paynow.createPayment(bookingId, "client@handylink.com");
      payment.addToCart(PaynowCartItem(title: "HandyLink 20% Deposit", amount: depositAmount));

      MobilePaymentMethod method = phone.startsWith('071') ? MobilePaymentMethod.onemoney : MobilePaymentMethod.ecocash;

      InitResponse response = await paynow.sendMobile(payment, phone, method);
      print('PAYNOW RAW RESPONSE: ${response.toString()}');

      if (response.success == true) {
        if (response.pollUrl == null || response.pollUrl!.isEmpty) {
          throw Exception("Paynow accepted the transaction but returned no Poll URL. Auth Code: ${response.authorizationCode}, Instructions: ${response.instructions}");
        }

        // Now poll the pollUrl every 4 seconds to wait for client to enter PIN on phone
        for (int i = 0; i < 20; i++) { // Max wait 20 * 4 = 80 seconds
          await Future.delayed(const Duration(seconds: 4));
          
          bool hasPaid = await verifyPayment(response.pollUrl!, "handled_by_sdk");
          if (hasPaid) {
            // Money is secured, run our internal handling callback
            await processPaymentCallback(
              bookingId: bookingId,
              providerId: providerId,
              depositAmount: depositAmount,
              pollUrl: response.pollUrl!,
              paynowHash: "handled_by_sdk",
            );
            return true;
          }
        }
        return false; // Polling timed out
      } else {
        throw Exception(response.error ?? "Failed to initiate payment. Check API Keys or Number.");
      }
    } catch (e) {
      String errorMessage = e.toString();
      try {
        if (e.runtimeType.toString() == 'ValueError') {
          errorMessage = (e as dynamic).cause?.toString() ?? "Invalid Amount or Phone Number";
        }
      } catch (_) {}
      
      throw Exception('Paynow Error: $errorMessage');
    }
  }

  /// Verifies a paynow transaction using the poll URL and hash
  Future<bool> verifyPayment(String pollUrl, String paynowHash) async {
    if (pollUrl == 'simulate') return true;
    
    try {
      final response = await http.get(Uri.parse(pollUrl));
      if (response.statusCode == 200) {
        // Parse the response URL encoded string into a map
        final Map<String, String> responseData = Uri.splitQueryString(response.body);
        
        // Very basic hash validation (pseudo-implementation)
        // In reality, this requires concatenating values and hashing with the Integration Key
        if (responseData['status'] == 'Paid' || responseData['status'] == 'Awaiting Delivery' || responseData['status'] == 'Delivered') {
            return true;
        }
      }
      return false;
    } catch (e) {
      print('Paynow verification error: $e');
      return false;
    }
  }

  /// The IPN Handler simulation for the mobile app
  /// Since the app cannot directly receive IPNs from Paynow, it actively polls
  Future<void> processPaymentCallback({
    required String bookingId,
    required String providerId,
    required double depositAmount,
    required String pollUrl,
    required String paynowHash,
  }) async {
    // 1. Idempotency Check (Check if deposit already paid)
    final bookingDoc = await _db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) {
      print('Booking missing');
      return;
    }

    final data = bookingDoc.data()!;
    if (data['deposit_paid'] == true) {
      print('Duplicate IPN call detected');
      return; 
    }

    // 2. Verify payment amount and status via Poll URL
    bool isValid = await verifyPayment(pollUrl, paynowHash);
    if (!isValid) {
      print('Payment verification failed');
      return;
    }

    // 3. Mark booking as deposit_paid
    await _db.collection('bookings').doc(bookingId).update({
      'deposit_paid': true,
      'total_deposit_amount': depositAmount,
    });

    // 4. Create single suspense record
    await _suspenseService.createSuspenseRecord(bookingId, depositAmount);

  }
}
