import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'secrets.dart';

class ImageUploadService {
  static const String _apiKey = Secrets.imgbbApiKey; 

  final ImagePicker _picker = ImagePicker();

  /// Picks an image from gallery and returns the File
  Future<File?> pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Compress for faster upload
    );
    
    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  /// Uploads image to ImgBB and returns the direct URL
  Future<String?> uploadImage(File imageFile) async {
    if (_apiKey.isEmpty || _apiKey == 'YOUR_IMGBB_API_KEY') {
      throw Exception('Please provide a valid ImgBB API Key in secrets.dart');
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.imgbb.com/1/upload?key=$_apiKey'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        return jsonResponse['data']['url'];
      } else {
        return null;
      }
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }
}
