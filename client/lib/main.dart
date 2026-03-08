import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  // 2. This is mandatory for async main functions in Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Initialize the actual Firebase link (using the file you generated)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase Auth
  // If no user is signed in, sign in anonymously. Otherwise, get the current user.
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    UserCredential userCredential = await FirebaseAuth.instance
        .signInAnonymously();
    user = userCredential.user;
  }
  final String userId = user!.uid;

  // 4. Set your offline settings
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 6. Finally, launch the UI
  runApp(
    MaterialApp(
      home: FashionScanner(userId: userId),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class FashionScanner extends StatefulWidget {
  final String userId;
  const FashionScanner({super.key, required this.userId});

  @override
  State<FashionScanner> createState() => _FashionScannerState();
}

class _FashionScannerState extends State<FashionScanner> {
  File? _imageFile;
  List<dynamic> _detections = [];
  bool _isLoading = false;

  // Use 10.0.2.2 for Android Emulator to reach localhost.
  // Change to your actual machine IP if using a physical device.
  final String _serverUrl = 'http://10.0.2.2:8000/detect';

  Future<void> _scanClothes() async {
    if (kDebugMode) print('[_scanClothes] Function entered.');
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85, // Reduce size for faster upload
    );

    if (image == null) {
      return;
    }

    setState(() {
      _imageFile = File(image.path);
      _isLoading = true;
      _detections = [];
    });

    if (kDebugMode) print('Starting _scanClothes try block...');
    try {
      if (kDebugMode) print('Attempting HTTP request to $_serverUrl');
      var request = http.MultipartRequest('POST', Uri.parse(_serverUrl));

      request.headers['ngrok-skip-browser-warning'] = 'true';

      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (kDebugMode) {
        print('HTTP Response Status Code: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
      if (kDebugMode) {
        print('HTTP Response Body: ${response.body}'); // Added debug print
      }
      final Map<String, dynamic> data = jsonDecode(response.body);        setState(() {
          _detections = data['detections'];
        });
        if (kDebugMode) {
          print('Detections received: ${_detections.length}');
        }
// Save detections to Firestore
if (kDebugMode) print('Attempting to save detections to Firestore...');
final userDocRef = FirebaseFirestore.instance
    .collection('users')
    .doc(widget.userId);
final scannedItemsCollection = userDocRef.collection('scanned_items');

for (var detection in _detections) {
  final List<dynamic> color = detection['color'] ?? [0, 0, 0];
  final List<dynamic>? complementaryColor = detection['complementary_color'] as List<dynamic>?; // Assuming server sends this

  await scannedItemsCollection.add({
    'label': detection['label'].toString(),
    'mainColor': color, // Store as a List<int>
    'complementaryColor': complementaryColor, // Store complementary color
    'timestamp': FieldValue.serverTimestamp(),
  });
  if (kDebugMode) {
    print('Saving complementaryColor to Firestore: $complementaryColor');
    print('Added detection to Firestore: ${detection['label']}');
  }
}
          if (kDebugMode) {
            print('Finished saving detections to Firestore.');
          }
      } else {
        _showError("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      if (kDebugMode) {
        print('Caught exception in _scanClothes: $e'); // Ensure this prints
      }
      _showError(
        "Connection failed. Ensure server is running at $_serverUrl. Error: $e",
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    print(message); // Always print to console for debugging
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<Size> _getImageSize(File imageFile) async {
    final Image image = Image.file(imageFile);
    final Completer<Size> completer = Completer<Size>();
    image.image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((ImageInfo info, bool synchronousCall) {
            completer.complete(
              Size(info.image.width.toDouble(), info.image.height.toDouble()),
            );
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

                    if (imageWidth / imageHeight >
                        containerWidth / containerHeight) {
                      scale = containerWidth / imageWidth;
                      offsetY = (containerHeight - imageHeight * scale) / 2;
                    } else {
                      scale = containerHeight / imageHeight;
                      offsetX = (containerWidth - imageWidth * scale) / 2;
                    }

                    if (kDebugMode) {
                      print('Original Image Size: $originalImageSize');
                      print(
                        'Container Size: ${constraints.maxWidth}x${constraints.maxHeight}',
                      );
                      print(
                        'Scale: $scale, OffsetX: $offsetX, OffsetY: $offsetY',
                      );
                    }

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(child: originalImage),
                        if (_isLoading)
                          const CircularProgressIndicator(color: Colors.indigo),
                        if (!_isLoading) ..._detections.map((d) {
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
                              print(
                                'Detection Box (Scaled): L:$scaledLeft, T:$scaledTop, W:$scaledWidth, H:$scaledHeight',
                              );
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
                          }),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Data Table Section (Now displaying stored items from Firestore)
          const Divider(height: 1, thickness: 2),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Saved Detections",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .collection('scanned_items')
                  .orderBy(
                    'timestamp',
                    descending: true,
                  ) // Order by latest first
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No saved items yet. Scan something!"),
                  );
                }

                final savedItems = snapshot.data!.docs;

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Colors.indigo[50],
                      ),
                      columns: const [
                        DataColumn(label: Text('Label')),
                        DataColumn(label: Text('Main Color')),
                        DataColumn(label: Text('Complementary Color')), // New Column
                        DataColumn(label: Text('Timestamp')),
                      ],
                      rows: savedItems.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final List<dynamic> color =
                            data['mainColor'] ?? [0, 0, 0];
                        final Color displayColor = Color.fromARGB(
                          255,
                          color[0].toInt(),
                          color[1].toInt(),
                          color[2].toInt(),
                        );
                        final List<dynamic>? complementaryColorData =
                            data['complementaryColor'] as List<dynamic>?;
                        final Color? displayComplementaryColor =
                            complementaryColorData != null
                                ? Color.fromARGB(
                                    255,
                                    complementaryColorData[0].toInt(),
                                    complementaryColorData[1].toInt(),
                                    complementaryColorData[2].toInt(),
                                  )
                                : null;
                        final Timestamp? timestamp =
                            data['timestamp'] as Timestamp?;
                        final String timestampText = timestamp == null
                            ? "Pending..."
                            : DateTime.fromMicrosecondsSinceEpoch(
                                timestamp.microsecondsSinceEpoch,
                              ).toLocal().toString().split(
                                '.',
                              )[0]; // Remove microseconds

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                data['label'].toString().toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
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
                                      border: Border.all(color: Colors.black26),
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
                            DataCell(
                              Row(
                                children: [
                                  if (displayComplementaryColor != null)
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: displayComplementaryColor,
                                        border: Border.all(
                                          color: Colors.black26,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (displayComplementaryColor != null)
                                    const SizedBox(width: 8),
                                  Text(
                                    displayComplementaryColor != null
                                        ? "RGB(${complementaryColorData![0]}, ${complementaryColorData[1]}, ${complementaryColorData[2]})"
                                        : "N/A",
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text(timestampText)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
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
