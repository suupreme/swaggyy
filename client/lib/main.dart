import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() => runApp(
  const MaterialApp(home: FashionScanner(), debugShowCheckedModeBanner: false),
);

class FashionScanner extends StatefulWidget {
  const FashionScanner({super.key});

  @override
  State<FashionScanner> createState() => _FashionScannerState();
}

class _FashionScannerState extends State<FashionScanner> {
  File? _imageFile;
  List<dynamic> _detections = [];
  bool _isLoading = false;

  // Use 10.0.2.2 for Android Emulator to reach localhost.
  // Change to your actual machine IP if using a physical device.
  final String _serverUrl = 'https://1575-97-104-30-252.ngrok-free.app/detect';

  Future<void> _scanClothes() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85, // Reduce size for faster upload
    );

    if (image == null) return;

    setState(() {
      _imageFile = File(image.path);
      _isLoading = true;
      _detections = [];
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(_serverUrl));

      request.headers['ngrok-skip-browser-warning'] = 'true';

      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _detections = data['detections'];
        });
      } else {
        _showError("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Connection failed. Ensure server is running at $_serverUrl");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (kDebugMode) print(message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

    Future<Size> _getImageSize(File imageFile) async {
    final Image image = Image.file(imageFile);
    final Completer<Size> completer = Completer<Size>();
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool synchronousCall) {
        completer.complete(Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
      }),
    );
    return completer.future;
    }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fashion Scanner"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Image Preview Section
          Expanded(
            flex: 2,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (_imageFile == null) {
                  return Container(
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text("Capture a photo to detect clothes"),
                    ),
                  );
                }

                // Get actual image dimensions
                final originalImage = Image.file(_imageFile!);
                return FutureBuilder<Size>(
                  future: _getImageSize(_imageFile!),
                  builder: (BuildContext context, AsyncSnapshot<Size> snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final originalImageSize = snapshot.data!;
                    
                    // Calculate displayed image size and offset based on BoxFit.contain
                    final imageWidth = originalImageSize.width;
                    final imageHeight = originalImageSize.height;
                    final containerWidth = constraints.maxWidth;
                    final containerHeight = constraints.maxHeight;

                    double scale = 1.0;
                    double offsetX = 0.0;
                    double offsetY = 0.0;

                    if (imageWidth / imageHeight > containerWidth / containerHeight) {
                      scale = containerWidth / imageWidth;
                      offsetY = (containerHeight - imageHeight * scale) / 2;
                    } else {
                      scale = containerHeight / imageHeight;
                      offsetX = (containerWidth - imageWidth * scale) / 2;
                    }

                    if (kDebugMode) {
                      print('Original Image Size: $originalImageSize');
                      print('Container Size: ${constraints.maxWidth}x${constraints.maxHeight}');
                      print('Scale: $scale, OffsetX: $offsetX, OffsetY: $offsetY');
                    }

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(child: originalImage),
                        if (_isLoading)
                          const CircularProgressIndicator(color: Colors.indigo),
                        if (!_isLoading)
                          ..._detections.map((d) {
                            final box = d['box'];
                            final List<dynamic> color =
                                d['color'] ?? [255, 0, 0];
                            final Color displayColor = Color.fromARGB(
                              255,
                              color[0].toInt(),
                              color[1].toInt(),
                              color[2].toInt(),
                            );

                            // Apply scaling and offset to bounding box coordinates
                            final scaledLeft = box[0] * scale + offsetX;
                            final scaledTop = box[1] * scale + offsetY;
                            final scaledWidth = (box[2] - box[0]) * scale;
                            final scaledHeight = (box[3] - box[1]) * scale;

                            if (kDebugMode) {
                              print('Detection Box (Original): $box');
                              print('Detection Box (Scaled): L:$scaledLeft, T:$scaledTop, W:$scaledWidth, H:$scaledHeight');
                            }

                            return Positioned(
                              left: scaledLeft,
                              top: scaledTop,
                              width: scaledWidth,
                              height: scaledHeight,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: displayColor,
                                    width: 3,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Data Table Section
          const Divider(height: 1, thickness: 2),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Detections (${_detections.length})",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: _detections.isEmpty
                ? const Center(child: Text("No data to display"))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(
                          Colors.indigo[50],
                        ),
                        columns: const [
                          DataColumn(label: Text('Label')),
                          DataColumn(label: Text('Confidence')),
                          DataColumn(label: Text('Main Color')),
                          DataColumn(
                            label: Text('Box (xmin, ymin, xmax, ymax)'),
                          ),
                        ],
                        rows: _detections.map((d) {
                          final List<dynamic> color = d['color'] ?? [0, 0, 0];
                          final List<dynamic> box = d['box'];
                          final Color displayColor = Color.fromARGB(
                            255,
                            color[0].toInt(),
                            color[1].toInt(),
                            color[2].toInt(),
                          );

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  d['label'].toString().toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  "${(d['confidence'] * 100).toStringAsFixed(1)}%",
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: displayColor,
                                        border: Border.all(
                                          color: Colors.black26,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "RGB(${color[0]}, ${color[1]}, ${color[2]})",
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text(box.join(", "))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _scanClothes,
        backgroundColor: Colors.indigo,
        label: const Text("Scan Clothing"),
        icon: const Icon(Icons.camera_alt),
      ),
    );
  }
}
