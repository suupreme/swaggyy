import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() => runApp(const MaterialApp(home: FashionScanner()));

class FashionScanner extends StatefulWidget {
  const FashionScanner({super.key});

  @override
  State<FashionScanner> createState() => _FashionScannerState();
}

class _FashionScannerState extends State<FashionScanner> {
  File? _imageFile;
  List<dynamic> _detections = [];
  bool _isLoading = false;

  // This is your function, integrated into the State class
  Future<void> _scanClothes() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    setState(() {
      _imageFile = File(image.path);
      _isLoading = true;
      _detections = []; // Clear old results
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'http://127.0.0.1:8000/detect',
        ), // Use your G14's Tailscale IP!
      );
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        setState(() {
          _detections = jsonDecode(response.body)['detections'];
        });
      }
    } catch (e) {
      print("Connection error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gator Fashion Scanner")),
      body: Center(
        child: Column(
          children: [
            if (_imageFile != null)
              // This is where we show the image
              Expanded(child: Image.file(_imageFile!))
            else
              const Expanded(
                child: Center(child: Text("Take a photo to start")),
              ),

            // Show a loading spinner while the G14 is crunching the numbers
            if (_isLoading) const CircularProgressIndicator(),

            // List the found items
            ..._detections.map(
              (d) => ListTile(
                title: Text(d['label']),
                subtitle: Text("Confidence: ${d['confidence']}"),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanClothes,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
