import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
            await prefs.setString('userName', responseData['name']);
            await prefs.setString('userEmail', responseData['email']);
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
                final List<dynamic> data = json.decode(response.body);
                return data.cast<Map<String, dynamic>>();
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
}
