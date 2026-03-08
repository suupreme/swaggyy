import 'dart:convert';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

// Data models for clothing items and outfit suggestions
class ClothingItem {
  final String id; // Unique ID from Firestore
  final String label;
  final List<int> colorRgb;

  ClothingItem({required this.id, required this.label, required this.colorRgb});

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'color': 'RGB(${colorRgb[0]}, ${colorRgb[1]}, ${colorRgb[2]})',
  };
}

class SuggestedOutfitItem {
  final String id;
  final String label;
  final String color; // Stored as 'RGB(r,g,b)' string

  SuggestedOutfitItem({
    required this.id,
    required this.label,
    required this.color,
  });

  factory SuggestedOutfitItem.fromJson(Map<String, dynamic> json) {
    return SuggestedOutfitItem(
      id: json['id'] ?? 'unknown_id', // Provide a default if 'id' is missing
      label: json['label'],
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'color': color};
}

class OutfitSuggestion {
  final SuggestedOutfitItem top;
  final SuggestedOutfitItem bottom;
  final String reason;

  OutfitSuggestion({
    required this.top,
    required this.bottom,
    required this.reason,
  });

  factory OutfitSuggestion.fromJson(Map<String, dynamic> json) {
    return OutfitSuggestion(
      top: SuggestedOutfitItem.fromJson(json['top']),
      bottom: SuggestedOutfitItem.fromJson(json['bottom']),
      reason: json['reason'],
    );
  }

  Map<String, dynamic> toJson() => {
    'top': top.toJson(),
    'bottom': bottom.toJson(),
    'reason': reason,
  };
}

class OllamaService {
  final String _ollamaApiUrl;
  final String userId;

  OllamaService(this._ollamaApiUrl, {required this.userId});

  String _generateSingleOutfitPrompt(
    List<ClothingItem> tops,
    List<ClothingItem> bottoms,
  ) {
    final StringBuffer prompt = StringBuffer();
    prompt.writeln(
      'You are an expert fashion stylist. Your task is to suggest one complete outfit (one top and one bottom) from the provided list of available clothing items. Focus strictly on creating aesthetically pleasing and harmonious color combinations.',
    );
    prompt.writeln();
    prompt.writeln('Available Clothing Items:');
    prompt.writeln('[BEGIN_ITEMS]');

    prompt.writeln('Tops:');
    if (tops.isEmpty) {
      prompt.writeln('- None');
    } else {
      for (var top in tops) {
        prompt.writeln(
          '- Label: "${top.label}", Color: RGB(${top.colorRgb[0]}, ${top.colorRgb[1]}, ${top.colorRgb[2]})',
        );
      }
    }

    prompt.writeln();
    prompt.writeln('Bottoms:');
    if (bottoms.isEmpty) {
      prompt.writeln('- None');
    } else {
      for (var bottom in bottoms) {
        prompt.writeln(
          '- Label: "${bottom.label}", Color: RGB(${bottom.colorRgb[0]}, ${bottom.colorRgb[1]}, ${bottom.colorRgb[2]})',
        );
      }
    }
    prompt.writeln('[END_ITEMS]');
    prompt.writeln();
    prompt.writeln(
      'Please provide your suggestion in JSON format. Do not include any text outside the JSON block. Return an empty JSON object `{}` if no good outfit combinations can be found.',
    );
    prompt.writeln();
    prompt.writeln('''
{
  "outfit_suggestion": {
    "top": {
      "label": "[label of chosen top]",
      "color": "RGB([r],[g],[b])"
    },
    "bottom": {
      "label": "[label of chosen bottom]",
      "color": "RGB([r],[g],[b])"
    },
    "reason": "Explain briefly why this combination works well (e.g., 'The colors are complementary and create a balanced look.')"
  }
}
''');
    return prompt.toString();
  }

  String _generateMultiOutfitPrompt(
    List<ClothingItem> tops,
    List<ClothingItem> bottoms,
  ) {
    final StringBuffer prompt = StringBuffer();
    prompt.writeln(
      'You are an expert fashion stylist. Your task is to suggest multiple complete outfits (each with one top and one bottom) from the provided list of available clothing items. Focus strictly on creating aesthetically pleasing and harmonious color combinations. Prioritize unique combinations and avoid repeating the same top-bottom pairs. If you run out of good combinations, you can stop returning outfits.',
    );
    prompt.writeln();
    prompt.writeln('Available Clothing Items:');
    prompt.writeln('[BEGIN_ITEMS]');

    prompt.writeln('Tops:');
    if (tops.isEmpty) {
      prompt.writeln('- None');
    } else {
      for (var top in tops) {
        prompt.writeln(
          '- ID: "${top.id}", Label: "${top.label}", Color: RGB(${top.colorRgb[0]}, ${top.colorRgb[1]}, ${top.colorRgb[2]})',
        );
      }
    }

    prompt.writeln();
    prompt.writeln('Bottoms:');
    if (bottoms.isEmpty) {
      prompt.writeln('- None');
    } else {
      for (var bottom in bottoms) {
        prompt.writeln(
          '- ID: "${bottom.id}", Label: "${bottom.label}", Color: RGB(${bottom.colorRgb[0]}, ${bottom.colorRgb[1]}, ${bottom.colorRgb[2]})',
        );
      }
    }
    prompt.writeln('[END_ITEMS]');
    prompt.writeln();
    prompt.writeln(
      'Please provide your suggestions in JSON format. Do not include any text outside the JSON block. Return an empty JSON array `[]` if no good outfit combinations can be found.',
    );
    prompt.writeln();
    prompt.writeln('''
[
  {
    "top": {
      "id": "[ID of chosen top]",
      "label": "[label of chosen top]",
      "color": "RGB([r],[g],[b])"
    },
    "bottom": {
      "id": "[ID of chosen bottom]",
      "label": "[label of chosen bottom]",
      "color": "RGB([r],[g],[b])"
    },
    "reason": "Explain briefly why this combination works well."
  },
  // Add more outfit suggestions here
]
''');
    return prompt.toString();
  }

  Future<OutfitSuggestion?> getOutfitSuggestion(
    List<ClothingItem> tops,
    List<ClothingItem> bottoms, {
    bool forceRefresh = false,
  }) async {
    final String cacheCollectionPath = 'users/$userId/cached_ootd';
    const String cacheDocumentId = 'current_ootd';
    const Duration maxCacheAge = Duration(hours: 24);

    if (!forceRefresh) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> doc =
            await FirebaseFirestore.instance
                .collection(cacheCollectionPath)
                .doc(cacheDocumentId)
                .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final Timestamp? timestamp = data['timestamp'] as Timestamp?;
            if (timestamp != null) {
              final DateTime cacheTime = timestamp.toDate();
              if (DateTime.now().difference(cacheTime) < maxCacheAge) {
                if (kDebugMode) print('Returning cached OOTD suggestion.');
                return OutfitSuggestion.fromJson(
                  data['suggestion'] as Map<String, dynamic>,
                );
              } else {
                if (kDebugMode)
                  print('Cached OOTD suggestion is stale. Refetching.');
              }
            }
          }
        } else {
          if (kDebugMode)
            print('No cached OOTD suggestion found. Fetching from Ollama.');
        }
      } catch (e) {
        if (kDebugMode) print('Error retrieving cached OOTD suggestion: $e');
      }
    } else {
      if (kDebugMode)
        print('Force refreshing OOTD suggestion. Bypassing cache.');
    }

    final String prompt = _generateSingleOutfitPrompt(tops, bottoms);

    if (kDebugMode) {
      print('Ollama Prompt:\n$prompt');
    }

    try {
      final response = await http.post(
        Uri.parse(_ollamaApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'mistral',
          'prompt': prompt,
          'stream': false,
          'options': {'temperature': 0.7, 'top_p': 0.9},
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (kDebugMode) {
          print('Ollama Raw Response: $data');
        }

        final String llmResponseText = data['response'] ?? '';

        if (llmResponseText.isEmpty) {
          if (kDebugMode) print('Ollama returned an empty response.');
          return null;
        }

        final jsonStartIndex = llmResponseText.indexOf('{');
        final jsonEndIndex = llmResponseText.lastIndexOf('}');

        if (jsonStartIndex != -1 &&
            jsonEndIndex != -1 &&
            jsonEndIndex > jsonStartIndex) {
          final jsonString = llmResponseText.substring(
            jsonStartIndex,
            jsonEndIndex + 1,
          );
          final Map<String, dynamic> jsonResponse = jsonDecode(jsonString);

          if (jsonResponse.containsKey('outfit_suggestion')) {
            final OutfitSuggestion suggestion = OutfitSuggestion.fromJson(
              jsonResponse['outfit_suggestion'],
            );

            // Save to Firestore cache
            try {
              await FirebaseFirestore.instance
                  .collection(cacheCollectionPath)
                  .doc(cacheDocumentId)
                  .set({
                    'timestamp': FieldValue.serverTimestamp(),
                    'suggestion': suggestion.toJson(),
                  });
              if (kDebugMode) print('OOTD suggestion cached successfully.');
            } catch (e) {
              if (kDebugMode)
                print('Error saving OOTD suggestion to cache: $e');
            }

            return suggestion;
          } else if (jsonResponse.isEmpty) {
            return null;
          }
        }
        if (kDebugMode)
          print(
            'Could not find/parse JSON from Ollama response: $llmResponseText',
          );
        return null;
      } else {
        if (kDebugMode) {
          print('Ollama API Error: ${response.statusCode} - ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error calling Ollama API: $e');
      }
      return null;
    }
  }

  Future<List<OutfitSuggestion>> getAllOutfitCombinations(
    List<ClothingItem> tops,
    List<ClothingItem> bottoms, {
    bool forceRefresh = false,
  }) async {
    // Add forceRefresh parameter
    final String cacheCollectionPath = 'users/$userId/cached_outfits';
    const String cacheDocumentId = 'wardrobe_combinations';
    const Duration maxCacheAge = Duration(hours: 24);

    if (!forceRefresh) {
      // Check cache only if not forcing refresh
      try {
        final DocumentSnapshot<Map<String, dynamic>> doc =
            await FirebaseFirestore.instance
                .collection(cacheCollectionPath)
                .doc(cacheDocumentId)
                .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final Timestamp? timestamp = data['timestamp'] as Timestamp?;
            final List<dynamic>? cachedTopIds = data['top_ids'] as List<dynamic>?;
            final List<dynamic>? cachedBottomIds = data['bottom_ids'] as List<dynamic>?;

            if (timestamp != null && cachedTopIds != null && cachedBottomIds != null) {
              final DateTime cacheTime = timestamp.toDate();
              // Check if cache is still fresh
              if (DateTime.now().difference(cacheTime) < maxCacheAge) {
                // Compare current items with cached items to ensure they are for the same wardrobe state
                final List<String> currentTopIds = tops.map((e) => e.id).toList()..sort();
                final List<String> currentBottomIds = bottoms.map((e) => e.id).toList()..sort();

                // Convert cached IDs to List<String> and sort them for comparison
                final List<String> sortedCachedTopIds = List<String>.from(cachedTopIds)..sort();
                final List<String> sortedCachedBottomIds = List<String>.from(cachedBottomIds)..sort();

                if (listEquals(sortedCachedTopIds, currentTopIds) && listEquals(sortedCachedBottomIds, currentBottomIds)) {
                  if (kDebugMode)
                    print('Returning cached outfit combinations.');
                  final List<dynamic> suggestionsData =
                      data['suggestions'] as List<dynamic>;
                  return suggestionsData
                      .map(
                        (item) => OutfitSuggestion.fromJson(
                          item as Map<String, dynamic>,
                        ),
                      )
                      .toList();
                } else {
                  if (kDebugMode)
                    print(
                      'Cached item IDs do not match current items. Refetching.',
                    );
                }
              } else {
                if (kDebugMode)
                  print('Cached outfit combinations are stale. Refetching.');
              }
            }
          }
        } else {
          if (kDebugMode)
            print('No cached outfit combinations found. Fetching from Ollama.');
        }
      } catch (e) {
        if (kDebugMode)
          print('Error retrieving cached outfit combinations: $e');
        // Continue to fetch from Ollama if cache retrieval fails
      }
    } else {
      if (kDebugMode)
        print('Force refreshing outfit combinations. Bypassing cache.');
    }

    // If cache is not fresh or not found, proceed to call Ollama
    final String prompt = _generateMultiOutfitPrompt(tops, bottoms);

    if (kDebugMode) {
      print('Ollama Multi-Outfit Prompt:\n$prompt');
    }

    try {
      final response = await http.post(
        Uri.parse(_ollamaApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'mistral',
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature':
                0.8, // Slightly higher temperature for more creativity
            'top_p': 0.9,
          },
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (kDebugMode) {
          print('Ollama Raw Multi-Outfit Response: $data');
        }

        final String llmResponseText = data['response'] ?? '';

        if (llmResponseText.isEmpty) {
          if (kDebugMode) print('Ollama returned an empty response.');
          return [];
        }

        final jsonStartIndex = llmResponseText.indexOf('[');
        final jsonEndIndex = llmResponseText.lastIndexOf(']');

        if (jsonStartIndex != -1 &&
            jsonEndIndex != -1 &&
            jsonEndIndex > jsonStartIndex) {
          final jsonString = llmResponseText.substring(
            jsonStartIndex,
            jsonEndIndex + 1,
          );
          final List<dynamic> jsonResponse = jsonDecode(jsonString);

          final List<OutfitSuggestion> suggestions = jsonResponse
              .map(
                (item) =>
                    OutfitSuggestion.fromJson(item as Map<String, dynamic>),
              )
              .toList();

          // Save to Firestore cache
          try {
            await FirebaseFirestore.instance
                .collection(cacheCollectionPath)
                .doc(cacheDocumentId)
                .set({
                  'timestamp': FieldValue.serverTimestamp(),
                  'suggestions': suggestions.map((s) => s.toJson()).toList(),
                  'top_ids': tops.map((e) => e.id).toList(), // Store current tops for comparison
                  'bottom_ids': bottoms.map((e) => e.id).toList(), // Store current bottoms for comparison
                });
            if (kDebugMode) print('Outfit combinations cached successfully.');
          } catch (e) {
            if (kDebugMode)
              print('Error saving outfit combinations to cache: $e');
          }

          return suggestions;
        }
        if (kDebugMode)
          print(
            'Could not find/parse JSON array from Ollama response: $llmResponseText',
          );
        return [];
      } else {
        if (kDebugMode) {
          print('Ollama API Error: ${response.statusCode} - ${response.body}');
        }
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error calling Ollama API: $e');
      }
      return [];
    }
  }
}
