import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/gestures.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isChecked = false;
  String? _selectedLocation;
  final List<String> _locations = ["Area 1", "Area 2", "Area 3"];
  final ImagePicker _picker = ImagePicker();
  XFile? _userImage;
  XFile? _shopImage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match');
      return;
    }

    if (!_isChecked) {
      _showSnackBar('Please accept terms & conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null && mounted) {
        final userId = response.user!.id;
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        String? profileImageUrl;
        String? shopImageUrl;

        // Upload profile image
        if (_userImage != null) {
          final file = File(_userImage!.path);
          final fileName = 'profile_$timestamp.jpg';
          final filePath = 'userprofile/$userId/$fileName';

          final uploadResponse = await Supabase.instance.client.storage
              .from('userprofile')
              .upload(filePath, file);

          if (uploadResponse.isEmpty) {
            _showSnackBar(
                'Profile image upload failed: Unknown error occurred');
            return;
          }

          profileImageUrl = Supabase.instance.client.storage
              .from('userprofile')
              .getPublicUrl(filePath); // Actual URL
        }

        // Upload shop image
        if (_shopImage != null) {
          final shopFile = File(_shopImage!.path);
          final shopFileName = 'shop_$timestamp.jpg';
          final shopFilePath = 'shopimages/$userId/$shopFileName';

          final shopUploadResponse = await Supabase.instance.client.storage
              .from('shopimages')
              .upload(shopFilePath, shopFile);

          if (shopUploadResponse.isEmpty) {
            _showSnackBar('Shop image upload failed: Unknown error occurred');
            return;
          }

          shopImageUrl = Supabase.instance.client.storage
              .from('shopimages')
              .getPublicUrl(shopFilePath); // Actual URL
        }

        // Insert into users table
        await Supabase.instance.client.from('users').insert({
          'id': userId,
          'full_name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'location': _selectedLocation,
          'profile_image': profileImageUrl,
          'shop_image': shopImageUrl,
        });

        Navigator.pushReplacementNamed(this.context, '/home');
      }
    } catch (e) {
      _showSnackBar('Signup failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickImage({required bool isProfile}) async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          if (isProfile) {
            _userImage = pickedFile;
          } else {
            _shopImage = pickedFile;
          }
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Register Now",
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const Text("Create your account",
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 30),
                _buildTextField(Icons.person, "Full Name",
                    controller: _nameController),
                _buildTextField(Icons.email, "Email Address",
                    controller: _emailController),
                _buildTextField(Icons.lock, "Password",
                    obscureText: true, controller: _passwordController),
                _buildTextField(Icons.lock, "Confirm Password",
                    obscureText: true, controller: _confirmPasswordController),
                _buildTextField(Icons.phone, "Phone Number",
                    controller: _phoneController),
                const SizedBox(height: 15),
                _locationDropdown(),
                const SizedBox(height: 15),
                const Text("Upload Profile Image",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _profileImageSection(),
                const SizedBox(height: 15),
                const Text("Upload Shop Image",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _shopImageSection(),
                const SizedBox(height: 15),
                _termsCheckbox(),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.black,
                  ),
                  onPressed: _isLoading ||
                          _emailController.text.isEmpty ||
                          _passwordController.text.isEmpty ||
                          _confirmPasswordController.text.isEmpty ||
                          _nameController.text.isEmpty ||
                          _phoneController.text.isEmpty ||
                          !_isChecked ||
                          (_userImage == null && _shopImage == null)
                      ? null
                      : _signUp,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Register",
                          style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 25),
                Center(
                  child: RichText(
                    text: TextSpan(
                      text: "Already have an account? ",
                      style: const TextStyle(color: Colors.black),
                      children: [
                        TextSpan(
                          text: "Sign in",
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.pop(context),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(IconData icon, String hint,
      {bool obscureText = false, required TextEditingController controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        height: 50,
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey),
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15),
          ),
        ),
      ),
    );
  }

  Widget _locationDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      value: _selectedLocation,
      items: _locations
          .map((location) => DropdownMenuItem(
                value: location,
                child: Text(location),
              ))
          .toList(),
      onChanged: (value) => setState(() => _selectedLocation = value),
      hint: const Text("Select Location"),
    );
  }

  Widget _profileImageSection() {
    return GestureDetector(
      onTap: () => _pickImage(isProfile: true),
      child: CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey[200],
        backgroundImage:
            _userImage != null ? FileImage(File(_userImage!.path)) : null,
        child: _userImage == null
            ? const Icon(Icons.camera_alt, size: 30, color: Colors.black)
            : null,
      ),
    );
  }

  Widget _shopImageSection() {
    return GestureDetector(
      onTap: () => _pickImage(isProfile: false),
      child: CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey[200],
        backgroundImage:
            _shopImage != null ? FileImage(File(_shopImage!.path)) : null,
        child: _shopImage == null
            ? const Icon(Icons.store, size: 30, color: Colors.black)
            : null,
      ),
    );
  }

  Widget _termsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _isChecked,
          onChanged: (value) => setState(() => _isChecked = value ?? false),
        ),
        const Text("I agree to the "),
        GestureDetector(
          onTap: () => showDialog(
            context: this.context,
            builder: (context) => AlertDialog(
              title: const Text("Terms & Conditions"),
              content: const Text("Your terms and conditions here..."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                )
              ],
            ),
          ),
          child: const Text("Terms & Conditions",
              style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}
