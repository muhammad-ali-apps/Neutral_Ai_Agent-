import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cleans raw AI response text to eliminate unwanted brackets, Python tuple syntax, 
/// stringified JSON/dicts, leading/trailing JSON noise (like `,{`), quotes, escaped characters,
/// and prevents unwanted markdown transformations inside code blocks.
String cleanAiResponse(dynamic rawReply) {
  if (rawReply == null) return '';

  if (rawReply is List) {
    return rawReply.map((e) => cleanAiResponse(e)).where((e) => e.isNotEmpty).join('\n\n');
  }

  if (rawReply is Map) {
    if (rawReply.containsKey('reply')) {
      return cleanAiResponse(rawReply['reply']);
    } else if (rawReply.containsKey('text')) {
      return cleanAiResponse(rawReply['text']);
    } else if (rawReply.containsKey('content')) {
      return cleanAiResponse(rawReply['content']);
    } else if (rawReply.containsKey('message')) {
      return cleanAiResponse(rawReply['message']);
    } else if (rawReply.containsKey('response')) {
      return cleanAiResponse(rawReply['response']);
    } else {
      return rawReply.values.map((e) => cleanAiResponse(e)).where((e) => e.isNotEmpty).join('\n\n');
    }
  }

  String text = rawReply.toString().trim();
  if (text.isEmpty) return '';

  // 1. Clean leading/trailing JSON/tuple noise like `,{`, `},`, `,{ "reply": ... }`
  text = text.replaceAll(RegExp(r'^\s*[\,\:\`\*\+]*[\,\{\}]+\s*'), '').trim();

  // 2. If text looks like stringified JSON or Python dict/tuple e.g. `{"reply": ...}` or `({'reply': ...}, 200)`
  if ((text.startsWith('{') && text.endsWith('}')) ||
      (text.startsWith('[') && text.endsWith(']')) ||
      (text.startsWith('(') && text.endsWith(')')) ||
      text.startsWith('{"') || text.startsWith("{'") || text.startsWith('({')) {
    
    // Try native JSON decode
    try {
      final decoded = json.decode(text);
      if (decoded != null && (decoded is Map || decoded is List)) {
        return cleanAiResponse(decoded);
      }
    } catch (_) {}

    // Try extracting Python tuple e.g. `("response text",)` or `('response text', 200)`
    final tupleMatch = RegExp(r'''^\s*[\(\[]\s*["']([\s\S]*?)["']\s*,\s*[\s\S]*[\)\]]\s*$''').firstMatch(text);
    if (tupleMatch != null && tupleMatch.group(1) != null) {
      return cleanAiResponse(tupleMatch.group(1));
    }

    final tupleSimpleMatch = RegExp(r'''^\s*[\(\[]\s*["']([\s\S]*?)["']\s*[\)\]]\s*$''').firstMatch(text);
    if (tupleSimpleMatch != null && tupleSimpleMatch.group(1) != null) {
      return cleanAiResponse(tupleSimpleMatch.group(1));
    }

    // Try extracting JSON key "reply": "..." or "content": "..." via Regex if JSON parsing failed
    final jsonKeyMatch = RegExp(r'''["'](?:reply|text|content|message|response)["']\s*:\s*["']([\s\S]*?)["']\s*[\}\]]?\s*$''').firstMatch(text);
    if (jsonKeyMatch != null && jsonKeyMatch.group(1) != null) {
      return cleanAiResponse(jsonKeyMatch.group(1));
    }
  }

  // 3. Strip outer enclosing quotes or brackets if still wrapped
  if ((text.startsWith('(') && text.endsWith(')')) ||
      (text.startsWith('[') && text.endsWith(']')) ||
      (text.startsWith('{') && text.endsWith('}'))) {
    text = text.substring(1, text.length - 1).trim();
  }
  if ((text.startsWith('"') && text.endsWith('"')) ||
      (text.startsWith("'") && text.endsWith("'"))) {
    text = text.substring(1, text.length - 1).trim();
  }

  // Strip residual leading `,{` or `,{` or `,` or `}` if left after unwrapping
  text = text.replaceAll(RegExp(r'^\s*[\,\{\}]+\s*'), '').replaceAll(RegExp(r'\s*[\,\{\}]+\s*$'), '').trim();

  // 4. Unescape common escape sequences if double-escaped e.g. `\n` -> `\n`
  if (text.contains(r'\n') || text.contains(r'\"') || text.contains(r"\'") || text.contains(r'\t')) {
    text = text
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'");
  }

  // Normalize hyphens
  text = text.replaceAll('\u2011', '-').replaceAll('\u00AD', '-');

  // Normalize Sphinx / RST double backticks ``code`` -> `code`
  text = text.replaceAllMapped(RegExp(r'``([^`\n]+)``'), (m) => '`${m[1]}`');

  // 5. Convert NumPy / RST docstring section headers ONLY outside code blocks
  text = _convertDocstringHeadersOutsideCodeBlocks(text);

  return text.trim();
}

/// Converts docstring section headers (e.g. Parameters\n----------) to ### Parameters,
/// but preserves code inside fenced code blocks (```...```) untouched.
String _convertDocstringHeadersOutsideCodeBlocks(String text) {
  final codeBlockRegex = RegExp(r'```[\s\S]*?```');
  final matches = codeBlockRegex.allMatches(text);

  if (matches.isEmpty) {
    return _applySectionHeaderRegex(text);
  }

  final buffer = StringBuffer();
  int lastIndex = 0;

  for (final match in matches) {
    if (match.start > lastIndex) {
      final nonCode = text.substring(lastIndex, match.start);
      buffer.write(_applySectionHeaderRegex(nonCode));
    }
    // Code block is kept unchanged
    buffer.write(text.substring(match.start, match.end));
    lastIndex = match.end;
  }

  if (lastIndex < text.length) {
    buffer.write(_applySectionHeaderRegex(text.substring(lastIndex)));
  }

  return buffer.toString();
}

String _applySectionHeaderRegex(String segment) {
  return segment.replaceAllMapped(
    RegExp(r'(\n|^)([A-Za-z0-9 _\-\(\)\.\,\:\`\*\+]+)\n\s*([-\=]{3,})\s*(\n|$)'),
    (m) => '${m[1]}### ${m[2]}\n${m[4]}',
  );
}

class ApiService{
    static const String baseUrl = "http://127.0.0.1:8000/api";

    // ─── Auth helpers ───

    static Future<Map<String, String>> _authHeaders() async {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? token = prefs.getString('token');
        return {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
        };
    }

    static Future<bool> registerUser(String name,String email, String password) async{
        try {
            final response = await http.post(
                Uri.parse('$baseUrl/auth/register'),
                headers:{
                    'Content-Type':'application/json',
                    'Accept':'application/json'
                },
                body: json.encode({
                    'name':name,
                    'email':email,
                    'password':password,
                    'password_confirmation':password,
                })
            );
            if(response.statusCode == 200 || response.statusCode == 201){
                
                print('User registered successfully: ${response.body}');
                return true;
            }else{
                // print('User registration failed');
                print('User registration failed: ${response.statusCode}');
                print('Error Body: ${response.body}'); 
                return false;
            }
        }catch(e){
            print('Error: $e');
            return false;
        }
    }
    static Future<bool> loginUser(String email, String password) async{
        try {
            final response = await http.post(
                Uri.parse('$baseUrl/auth/login'),
                headers:{
                    'Content-Type':'application/json',
                    'Accept':'application/json'
                },
                body: json.encode({
                    'email':email,
                    'password':password
                })
            );
            if(response.statusCode == 200){
                print('User login successfully: ${response.body}');
                var data = jsonDecode(response.body);
                String token = data['access_token'];
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setString('token', token);

                var user = data['user'] ?? data;
                if (user != null) {
                    if (user['name'] != null) await prefs.setString('userName', user['name'].toString());
                    if (user['email'] != null) await prefs.setString('userEmail', user['email'].toString());
                    String? role = user['role']?.toString() ?? data['role']?.toString();
                    if (role != null) {
                        await prefs.setString('userRole', role);
                    }
                }
                return true;
            }else{
                print('User login failed: ${response.statusCode}');
                print('Error Body: ${response.body}');
                return false;
            }
        }catch(e){
            print('Error: $e');
            return false;
        }
    }

    static Future<bool> isUserLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    try {
        final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
        },
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
            var responseData = json.decode(response.body);
            final prefs = await SharedPreferences.getInstance();
            var user = responseData['user'] ?? responseData;
            if (user['name'] != null) await prefs.setString('userName', user['name'].toString());
            if (user['email'] != null) await prefs.setString('userEmail', user['email'].toString());
            String? role = user['role']?.toString() ?? responseData['role']?.toString();
            if (role != null) {
                await prefs.setString('userRole', role);
            }
            print('User is logged in: ${response.body}');
            return true;
        } else {
            print('User is not logged in: ${response.body}');
            return false;
        }
    } catch (e) {
        print('Error: $e');
        return false;
    }
    }
    
    static Future<bool> logoutUser() async {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? token = prefs.getString('token');
        try {
            final response = await http.post(
                Uri.parse('$baseUrl/auth/logout'),
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': 'Bearer $token',
                },
            );
            if (response.statusCode == 200 || response.statusCode == 201) {
                await prefs.remove('token');
                await prefs.remove('userName');
                await prefs.remove('userEmail');
                await prefs.remove('userRole');
                return true;
            } else {
                print('Logout failed: ${response.body}');
                return false;
            }
        } catch (e) {
            print('Error during logout: $e');
            return false;
        }
    }

    // ─── LLM Models CRUD ───

    /// GET /api/llm-models — fetch all models.
    static Future<List<Map<String, dynamic>>?> fetchLlmModels() async {
        try {
            final headers = await _authHeaders();
            final response = await http.get(
                Uri.parse('$baseUrl/llm-models'),
                headers: headers,
            );
            if (response.statusCode == 200) {
                final decoded = json.decode(response.body);
                List<dynamic> list = [];
                if (decoded is List) {
                    list = decoded;
                } else if (decoded is Map) {
                    if (decoded['data'] is List) {
                        list = decoded['data'];
                    } else if (decoded['models'] is List) {
                        list = decoded['models'];
                    } else if (decoded['llm_models'] is List) {
                        list = decoded['llm_models'];
                    }
                }
                return list.cast<Map<String, dynamic>>();
            } else {
                print('Fetch LLM models failed: ${response.statusCode}');
                print('Error Body: ${response.body}');
                return null;
            }
        } catch (e) {
            print('Error fetching LLM models: $e');
            return null;
        }
    }

    /// POST /api/llm-models — create a new model.
    static Future<Map<String, dynamic>?> createLlmModel(Map<String, dynamic> data) async {
        try {
            final headers = await _authHeaders();
            final response = await http.post(
                Uri.parse('$baseUrl/llm-models'),
                headers: headers,
                body: json.encode(data),
            );
            if (response.statusCode == 200 || response.statusCode == 201) {
                print('LLM model created: ${response.body}');
                return json.decode(response.body) as Map<String, dynamic>;
            } else {
                print('Create LLM model failed: ${response.statusCode}');
                print('Error Body: ${response.body}');
                return null;
            }
        } catch (e) {
            print('Error creating LLM model: $e');
            return null;
        }
    }

    /// PUT /api/llm-models/{id} — update a model.
    static Future<Map<String, dynamic>?> updateLlmModel(String id, Map<String, dynamic> data) async {
        try {
            final headers = await _authHeaders();
            final response = await http.put(
                Uri.parse('$baseUrl/llm-models/$id'),
                headers: headers,
                body: json.encode(data),
            );
            if (response.statusCode == 200) {
                print('LLM model updated: ${response.body}');
                return json.decode(response.body) as Map<String, dynamic>;
            } else {
                print('Update LLM model failed: ${response.statusCode}');
                print('Error Body: ${response.body}');
                return null;
            }
        } catch (e) {
            print('Error updating LLM model: $e');
            return null;
        }
    }

    /// DELETE /api/llm-models/{id} — delete a model.
    static Future<bool> deleteLlmModel(String id) async {
        try {
            final headers = await _authHeaders();
            final response = await http.delete(
                Uri.parse('$baseUrl/llm-models/$id'),
                headers: headers,
            );
            if (response.statusCode == 200) {
                print('LLM model deleted');
                return true;
            } else {
                print('Delete LLM model failed: ${response.statusCode}');
                print('Error Body: ${response.body}');
                return false;
            }
        } catch (e) {
            print('Error deleting LLM model: $e');
            return false;
        }
    }

    // ─── Comparison Models Preference API ───

    /// GET /api/user/comparison-models — fetch user saved comparison models and active available models.
    static Future<Map<String, dynamic>?> fetchComparisonModels() async {
        try {
            final headers = await _authHeaders();
            final response = await http.get(
                Uri.parse('$baseUrl/user/comparison-models'),
                headers: headers,
            );
            if (response.statusCode == 200) {
                return json.decode(response.body) as Map<String, dynamic>;
            } else {
                print('Fetch comparison models failed: ${response.statusCode}');
                print('Error Body: ${response.body}');
                return null;
            }
        } catch (e) {
            print('Error fetching comparison models: $e');
            return null;
        }
    }

    /// POST /api/user/comparison-models — update user preferred comparison models.
    static Future<bool> updateComparisonModels(List<String> modelIds) async {
        try {
            final headers = await _authHeaders();
            final response = await http.post(
                Uri.parse('$baseUrl/user/comparison-models'),
                headers: headers,
                body: json.encode({'model_ids': modelIds}),
            );
            if (response.statusCode == 200) {
                print('Updated user comparison models: ${response.body}');
                return true;
            } else {
                print('Update comparison models failed: ${response.statusCode}');
                print('Error Body: ${response.body}');
                return false;
            }
        } catch (e) {
            print('Error updating comparison models: $e');
            return false;
        }
    }

    // ─── Chat API ───

    /// POST /api/chat/send — send prompt in smart routing or comparison mode.
    static Future<Map<String, dynamic>?> sendChatMessage({
        required String prompt,
        String? sessionId,
        String mode = 'smart',
        List<String>? selectedModels,
    }) async {
        try {
            final headers = await _authHeaders();
            final bodyMap = <String, dynamic>{
                'prompt': prompt,
                'mode': mode,
                if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
                if (mode == 'compare' && selectedModels != null && selectedModels.isNotEmpty)
                    'selected_models': selectedModels,
            };
            final response = await http.post(
                Uri.parse('$baseUrl/chat/send'),
                headers: headers,
                body: json.encode(bodyMap),
            );
            if (response.statusCode == 200 || response.statusCode == 201) {
                print('Chat response received: ${response.body}');
                var resMap = json.decode(response.body) as Map<String, dynamic>;
                if (resMap.containsKey('reply')) {
                  resMap['reply'] = cleanAiResponse(resMap['reply']);
                }
                return resMap;
            } else {
                print('Chat send failed: ${response.statusCode}');
                print('Error Body: ${response.body}');
                return null;
            }
        } catch (e) {
            print('Error sending chat message: $e');
            return null;
        }
    }

    // ─── Chat Sessions History API ───

    /// GET /api/chat-sessions — fetch all user chat sessions.
    static Future<List<Map<String, dynamic>>?> fetchChatSessions() async {
        try {
            final headers = await _authHeaders();
            final response = await http.get(
                Uri.parse('$baseUrl/chat-sessions'),
                headers: headers,
            );
            if (response.statusCode == 200) {
                final decoded = json.decode(response.body);
                List<dynamic> list = [];
                if (decoded is List) {
                    list = decoded;
                } else if (decoded is Map) {
                    if (decoded['data'] is List) {
                        list = decoded['data'];
                    } else if (decoded['sessions'] is List) {
                        list = decoded['sessions'];
                    }
                }
                return list.cast<Map<String, dynamic>>();
            } else {
                print('Fetch chat sessions failed: ${response.statusCode}');
                print('Error Body: ${response.body}');
                return null;
            }
        } catch (e) {
            print('Error fetching chat sessions: $e');
            return null;
        }
    }

    /// GET /api/chat-sessions/{id} — fetch a single chat session with full messages.
    static Future<Map<String, dynamic>?> fetchChatSessionById(String id) async {
        try {
            final headers = await _authHeaders();
            final response = await http.get(
                Uri.parse('$baseUrl/chat-sessions/$id'),
                headers: headers,
            );
            if (response.statusCode == 200) {
                return json.decode(response.body) as Map<String, dynamic>;
            } else {
                print('Fetch chat session by ID failed: ${response.statusCode}');
                return null;
            }
        } catch (e) {
            print('Error fetching chat session by ID: $e');
            return null;
        }
    }

    /// PUT /api/chat-sessions/{id} — rename/update chat session.
    static Future<bool> renameChatSession(String id, String newTitle) async {
        try {
            final headers = await _authHeaders();
            final response = await http.put(
                Uri.parse('$baseUrl/chat-sessions/$id'),
                headers: headers,
                body: json.encode({'title': newTitle}),
            );
            if (response.statusCode == 200) {
                print('Renamed chat session successfully');
                return true;
            } else {
                print('Rename chat session failed: ${response.statusCode}');
                return false;
            }
        } catch (e) {
            print('Error renaming chat session: $e');
            return false;
        }
    }

    /// DELETE /api/chat-sessions/{id} — delete chat session.
    static Future<bool> deleteChatSession(String id) async {
        try {
            final headers = await _authHeaders();
            final response = await http.delete(
                Uri.parse('$baseUrl/chat-sessions/$id'),
                headers: headers,
            );
            if (response.statusCode == 200) {
                print('Deleted chat session successfully');
                return true;
            } else {
                print('Delete chat session failed: ${response.statusCode}');
                return false;
            }
        } catch (e) {
            print('Error deleting chat session: $e');
            return false;
        }
    }
}

