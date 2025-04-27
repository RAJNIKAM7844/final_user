import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

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
  List<String> _locations = [];
  final ImagePicker _picker = ImagePicker();
  XFile? _userImage;
  XFile? _shopImage;
  RealtimeChannel? _subscription; // For real-time updates

  static const String _emailPattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String _phonePattern = r'^\+?1?\d{9,15}$';
  static const int _minPasswordLength = 8;
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5MB

  @override
  void initState() {
    super.initState();
    _fetchLocations(); // Initial fetch
    _setupRealtimeSubscription(); // Set up real-time subscription
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _subscription?.unsubscribe(); // Unsubscribe from real-time updates
    super.dispose();
  }

  // Fetch locations from Supabase
  Future<void> _fetchLocations() async {
    try {
      final response = await Supabase.instance.client
          .from('delivery_areas')
          .select('area_name');

      if (response.isNotEmpty) {
        setState(() {
          _locations = (response as List<dynamic>)
              .map((item) => item['area_name'].toString())
              .toList()
            ..sort(); // Sort alphabetically for better UX
          // Reset selected location if it no longer exists
          if (_selectedLocation != null &&
              !_locations.contains(_selectedLocation)) {
            _selectedLocation = null;
          }
        });
      } else {
        setState(() {
          _locations = [];
          _selectedLocation = null; // Reset if no areas
        });
        _showSnackBar('No areas available');
      }
    } catch (e) {
      _showSnackBar('Error fetching areas: $e');
    }
  }

  // Set up real-time subscription for delivery_areas table
  void _setupRealtimeSubscription() {
    _subscription = Supabase.instance.client
        .channel('public:delivery_areas')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // Listen for all changes
          schema: 'public',
          table: 'delivery_areas',
          callback: (payload) {
            _fetchLocations(); // Refetch locations on change
            _showSnackBar('Locations updated');
          },
        )
        .subscribe();
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (!_validateInputs(email, password, confirmPassword, name, phone)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null && mounted) {
        final userId = response.user!.id;
        final timestamp = DateTime.now().millisecondsSinceEpoch;

        String? profileImageUrl;
        String? shopImageUrl;

        // Compress and upload profile image
        if (_userImage != null) {
          final file = File(_userImage!.path);
          if (await file.length() > _maxFileSizeBytes) {
            _showSnackBar('Profile image size must be less than 5MB');
            return;
          }

          // Compress the image to ~100KB
          final compressedFile =
              await _compressImage(file, userId, 'profile_$timestamp');
          if (compressedFile == null) {
            _showSnackBar('Failed to compress profile image');
            return;
          }

          final fileName = 'profile_$timestamp.jpg';
          final filePath = 'userprofile/$userId/$fileName';

          await Supabase.instance.client.storage
              .from('userprofile')
              .upload(filePath, compressedFile);

          profileImageUrl = Supabase.instance.client.storage
              .from('userprofile')
              .getPublicUrl(filePath);
        }

        // Compress and upload shop image
        if (_shopImage != null) {
          final shopFile = File(_shopImage!.path);
          if (await shopFile.length() > _maxFileSizeBytes) {
            _showSnackBar('Shop image size must be less than 5MB');
            return;
          }

          // Compress the image to ~100KB
          final compressedShopFile =
              await _compressImage(shopFile, userId, 'shop_$timestamp');
          if (compressedShopFile == null) {
            _showSnackBar('Failed to compress shop image');
            return;
          }

          final shopFileName = 'shop_$timestamp.jpg';
          final shopFilePath = 'shopimages/$userId/$shopFileName';

          await Supabase.instance.client.storage
              .from('shopimages')
              .upload(shopFilePath, compressedShopFile);

          shopImageUrl = Supabase.instance.client.storage
              .from('shopimages')
              .getPublicUrl(shopFilePath);
        }

        await Supabase.instance.client.from('users').insert({
          'id': userId,
          'full_name': name,
          'email': email,
          'phone': phone,
          'location': _selectedLocation,
          'profile_image': profileImageUrl,
          'shop_image': shopImageUrl,
        });

        // Navigate to the login page after successful registration
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on AuthException catch (e) {
      _showSnackBar('Signup failed: ${e.message}');
    } catch (e) {
      _showSnackBar('Signup failed: An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper method to compress images
  Future<File?> _compressImage(
      File file, String userId, String fileName) async {
    try {
      final tempDir = Directory.systemTemp;
      final targetPath = '${tempDir.path}/compressed_$fileName.jpg';

      // Compress the image
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, // Adjust quality to target ~100KB
        minWidth: 800, // Adjust resolution if needed
        minHeight: 800,
      );

      if (compressedFile == null) {
        return null;
      }

      final compressedSize = await compressedFile.length();
      if (compressedSize > 100 * 1024) {
        // If still larger than 100KB, try reducing quality further
        final furtherCompressedFile =
            await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: 50, // Further reduce quality
          minWidth: 600,
          minHeight: 600,
        );
        return furtherCompressedFile != null
            ? File(furtherCompressedFile.path)
            : null;
      }

      return File(compressedFile.path);
    } catch (e) {
      _showSnackBar('Error compressing image: $e');
      return null;
    }
  }

  bool _validateInputs(String email, String password, String confirmPassword,
      String name, String phone) {
    if (name.isEmpty) {
      _showSnackBar('Please enter your full name');
      return false;
    }

    if (email.isEmpty) {
      _showSnackBar('Please enter your email');
      return false;
    }

    if (!RegExp(_emailPattern).hasMatch(email)) {
      _showSnackBar('Please enter a valid email address');
      return false;
    }

    if (password.isEmpty) {
      _showSnackBar('Please enter a password');
      return false;
    }

    if (password.length < _minPasswordLength) {
      _showSnackBar('Password must be at least $_minPasswordLength characters');
      return false;
    }

    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$')
        .hasMatch(password)) {
      _showSnackBar('Password must contain letters and numbers');
      return false;
    }

    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match');
      return false;
    }

    if (phone.isEmpty) {
      _showSnackBar('Please enter your phone number');
      return false;
    }

    if (!RegExp(_phonePattern).hasMatch(phone)) {
      _showSnackBar('Please enter a valid phone number');
      return false;
    }

    if (_selectedLocation == null) {
      _showSnackBar('Please select a location');
      return false;
    }

    if (!_isChecked) {
      _showSnackBar('Please accept terms & conditions');
      return false;
    }

    if (_userImage == null && _shopImage == null) {
      _showSnackBar('Please upload at least one image');
      return false;
    }

    return true;
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pickImage(bool isProfile) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 160,
        child: Column(
          children: [
            const Text(
              "Upload Image",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final pickedFile =
                        await _picker.pickImage(source: ImageSource.camera);
                    if (pickedFile != null) {
                      setState(() {
                        if (isProfile) {
                          _userImage = pickedFile;
                        } else {
                          _shopImage = pickedFile;
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final pickedFile =
                        await _picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      setState(() {
                        if (isProfile) {
                          _userImage = pickedFile;
                        } else {
                          _shopImage = pickedFile;
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Gallery"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _fetchLocations, // Pull-to-refresh
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  const Text(
                    "Register Now",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Sign up with email and password and all fields to continue",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(Icons.person, "Full Name",
                      controller: _nameController),
                  _buildTextField(Icons.email, "Email Address",
                      controller: _emailController),
                  _buildTextField(Icons.lock, "Password",
                      obscureText: true, controller: _passwordController),
                  _buildTextField(Icons.lock, "Confirm Password",
                      obscureText: true,
                      controller: _confirmPasswordController),
                  const SizedBox(height: 10),
                  _buildTextField(Icons.phone, "Phone Number",
                      controller: _phoneController),
                  _locationDropdown(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _imageCircle(_userImage, Icons.person, true),
                      const SizedBox(width: 20),
                      _imageCircle(_shopImage, Icons.store, false),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _termsCheckbox(),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.black,
                    ),
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Register",
                            style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 10),
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(IconData icon, String hint,
      {bool obscureText = false, required TextEditingController controller}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            prefixIcon: Icon(icon, color: Colors.grey, size: 18),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            filled: true,
            fillColor: Colors.grey[200],
            border: InputBorder.none,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _locationDropdown() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
              hintText: _locations.isEmpty ? "Loading..." : "Select Location",
              hintStyle: const TextStyle(color: Colors.grey),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[200],
            ),
            value: _selectedLocation,
            items: _locations
                .map((location) => DropdownMenuItem(
                      value: location,
                      child: Text(location),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _selectedLocation = value),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _fetchLocations,
          tooltip: 'Refresh Locations',
        ),
      ],
    );
  }

  Widget _imageCircle(XFile? image, IconData icon, bool isProfile) {
    return GestureDetector(
      onTap: () => _pickImage(isProfile),
      child: CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[300],
        backgroundImage: image != null ? FileImage(File(image.path)) : null,
        child: image == null ? Icon(icon, size: 30, color: Colors.black) : null,
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
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Terms & Conditions"),
              content: const Text("Your terms and conditions here..."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            ),
          ),
          child: const Text(
            "Click Here to Accept Terms & Conditions",
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
