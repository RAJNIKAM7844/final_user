import 'package:flutter/material.dart';
import 'package:hms_pro/widgets/custom_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool _isLoading = true;
  String _errorMessage = '';
  String? _profileImageUrl;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userId = _supabase.auth.currentUser?.id;

      if (userId == null) {
        setState(() {
          _errorMessage = 'User is not logged in';
          _isLoading = false;
        });
        return;
      }

      final response =
          await _supabase.from('users').select().eq('id', userId).maybeSingle();

      if (response == null) {
        setState(() {
          _errorMessage = 'User profile not found';
          _isLoading = false;
        });
        return;
      }

      // Handle image URLs
      _profileImageUrl = await _getValidImageUrl(response['profile_image']);

      setState(() {
        userData = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<String?> _getValidImageUrl(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    try {
      // For Supabase Storage URLs, we need to properly format them
      if (imagePath.startsWith('userprofile/')) {
        final String publicUrl = _supabase.storage
            .from('userprofile') // Your bucket name
            .getPublicUrl(imagePath.replaceFirst('userprofile/', ''));

        // Verify the image exists
        await Supabase.instance.client.storage
            .from('userprofile')
            .download(imagePath.replaceFirst('userprofile/', ''));

        return publicUrl;
      }
      return imagePath;
    } catch (e) {
      print('Error verifying image URL: $e');
      return null;
    }
  }

  Future<void> _refreshData() async {
    await _fetchUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  alignment: Alignment.bottomLeft,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: const Text(
                    'Profile.',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey,
                      backgroundImage: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                      child: _profileImageUrl == null
                          ? const Icon(Icons.person,
                              size: 50, color: Colors.black)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Icon(Icons.edit, size: 20),
                  ),
                ),
                _buildInfoField(
                    icon: Icons.person,
                    text: userData?['full_name'] ?? "No name provided"),
                _buildInfoField(
                    icon: Icons.mail,
                    text: userData?['email'] ?? "No email provided"),
                _buildInfoField(
                    icon: Icons.location_on,
                    text: userData?['location'] ?? "No location provided"),
                _buildInfoField(
                    icon: Icons.phone,
                    text: userData?['phone'] ?? "No phone provided"),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A103D), // dark purple
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () async {
                        await _supabase.auth.signOut();
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: const Text(
                        "Log Out",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoField({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(15),
        ),
        height: 55,
        child: Row(
          children: [
            Icon(icon, color: Colors.grey),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
