import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils/sample_generator_utils.dart';

// ignore_for_file: avoid_print

const String model = 'claude-3-sonnet-20240229';

void main() async {
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'];
  if (apiKey == null || apiKey.trim().isEmpty) {
    print('Error: ANTHROPIC_API_KEY environment variable is not set or empty');
    exit(1);
  }

  try {
    final response = await generateSample(apiKey);
    await updateFiles(response, apiKey);
  } catch (e) {
    print('Error during sample generation: $e');
    exit(1);
  }
}

Future<Map<String, dynamic>> generateSample(String apiKey) async {
  final url = Uri.parse('https://api.anthropic.com/v1/messages');
  final today = DateTime.now().toIso8601String().split('T')[0];
  
  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey.trim(),
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': 4000,
        'messages': [
          {
            'role': 'user',
            'content': '''Generate a flutter showcase single sample, try to complex yet simple and use different combinations of widgets, Flutter implementations and patterns. The widget must be entirely self-contained (no external parameters or dependencies) and showcase at least one interactive or animated element.

Requirements:
1. Respond ONLY with a single valid JSON object – no extra text, explanations, or code comments.
2. The JSON must include exactly these keys: "name", "code", and "metadata".
3. The "name" field should use snake_case for the widget’s class name (e.g., "my_cool_sample").
4. The "code" field must:
   - Contain a fully self-contained Flutter code snippet in a properly escaped string.
   - Include ALL necessary imports (e.g., material.dart).
   - Use a constructor with no required parameters (e.g., `const MyCoolSample({super.key});`).
   - Feature at least one interactive or animated element.
5. The "metadata" field can include any relevant details or categorization (e.g., "interactive", "animation"), but keep it concise.
6. Ensure all quotes and special characters are properly escaped so the JSON is valid.
7. Provide no additional commentary, instructions, or text outside of the single JSON object.

Example response format (respond exactly like this format):
{
  "name": "widget_name",
  "code": "import 'package:flutter/material.dart';\\n\\n// Rest of the dart code here",
  "metadata": {
    "description": "A brief description",
    "generated_at": "$today",
    "model": "$model",
    "complexity_level": "beginner"
  }
}'''
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw 'API request failed with status ${response.statusCode}: ${response.body}';
    }
    
    final responseBody = jsonDecode(response.body);
    if (responseBody['content'] == null || responseBody['content'].isEmpty) {
      throw 'Invalid API response format: No content found';
    }
    
    final content = responseBody['content'][0]['text'];
    
    if (content == null || content.trim().isEmpty) {
      throw 'API response content is empty or null.';
    }
    
    try {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch == null) {
        throw 'No JSON object found in the response';
      }
      
      final parsed = jsonDecode(jsonMatch.group(0)!);
      
      if (!parsed.containsKey('name') || !parsed.containsKey('code') || !parsed.containsKey('metadata')) {
        throw 'Missing required fields in JSON response';
      }
      
      final widgetName = parsed['name']
          .split('_')
          .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
          .join('');
      
      if (parsed['metadata'] != null) {
        parsed['metadata']['generated_at'] = today;
        parsed['metadata']['widget_name'] = widgetName;
      }
      
      return parsed;
    } catch (e) {
      throw 'Failed to parse sample JSON. Error: $e';
    }
  } catch (e) {
    throw 'Failed to generate sample: $e';
  }
}

Future<void> updateFiles(Map<String, dynamic> sample, String apiKey) async {
  await generateWithRetry(sample, () => generateSample(apiKey));
}
