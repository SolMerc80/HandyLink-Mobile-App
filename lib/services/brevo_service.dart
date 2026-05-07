import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:handy_link/secrets.dart';

class BrevoService {
  static const String _baseUrl = 'https://api.brevo.com/v3/smtp/email';

  static Future<bool> sendVerificationCode(String recipientEmail, String recipientName, String code) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'accept': 'application/json',
        'api-key': Secrets.brevoApiKey,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'sender': {
          'name': Secrets.brevoSenderName,
          'email': Secrets.brevoSenderEmail,
        },
        'to': [
          {
            'email': recipientEmail,
            'name': recipientName,
          }
        ],
        'subject': 'Verify Your HandyLink Account',
        'htmlContent': '''
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 10px; }
              .header { background-color: #673AB7; color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0; }
              .content { padding: 30px; text-align: center; }
              .code { font-size: 32px; font-weight: bold; color: #673AB7; letter-spacing: 5px; margin: 20px 0; padding: 10px; border: 2px dashed #673AB7; display: inline-block; }
              .footer { font-size: 12px; color: #777; text-align: center; margin-top: 20px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>HandyLink.</h1>
              </div>
              <div class="content">
                <h2>Email Verification</h2>
                <p>Hello $recipientName,</p>
                <p>Thank you for registering with HandyLink. Please use the following code to verify your email address:</p>
                <div class="code">$code</div>
                <p>This code will expire in 10 minutes. If you did not request this, please ignore this email.</p>
              </div>
              <div class="footer">
                &copy; 2026 HandyLink. All rights reserved.
              </div>
            </div>
          </body>
          </html>
        ''',
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    } else {
      print('Brevo Error: ${response.body}');
      return false;
    }
  }
}
