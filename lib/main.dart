import 'package:flutter/material.dart';
import 'package:hms_pro/home_page.dart';
import 'package:hms_pro/reset_page.dart';
import 'package:hms_pro/login_page.dart';
import 'package:hms_pro/sign_up.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://kwoxhpztkxzqetwanlxx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt3b3hocHp0a3h6cWV0d2FubHh4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUxMjQyMTAsImV4cCI6MjA2MDcwMDIxMH0.jEIMSnX6-uEA07gjnQKdEXO20Zlpw4XPybfeLQr7W-M',
  );

  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  // Check if the user is already logged in
  final supabase = Supabase.instance.client;
  final isLoggedIn = supabase.auth.currentSession != null;

  runApp(MyApp(
    hasSeenOnboarding: hasSeenOnboarding,
    isLoggedIn: isLoggedIn,
  ));
}

class MyApp extends StatelessWidget {
  final bool hasSeenOnboarding;
  final bool isLoggedIn;

  const MyApp({
    super.key,
    required this.hasSeenOnboarding,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "HMS Egg Distributions",
      theme: ThemeData(
        fontFamily: 'Roboto',
        primarySwatch: Colors.orange,
      ),
      // Set initial route based on onboarding and login status
      initialRoute: isLoggedIn ? '/home' : (hasSeenOnboarding ? '/login' : '/'),
      routes: {
        '/': (context) => const PageOne(),
        '/page-two': (context) => const PageTwo(),
        '/page-three': (context) => const PageThree(),
        '/page-four': (context) => const PageFour(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomePage(),
        '/reset': (context) => const ResetPasswordPage(),
      },
    );
  }
}

// Page 1 - Rolling Egg Animation
class PageOne extends StatefulWidget {
  const PageOne({super.key});

  @override
  _PageOneState createState() => _PageOneState();
}

class _PageOneState extends State<PageOne> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/page-two');
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_animation.value, 0),
                    child: Image.asset('assets/egg.png', width: 150),
                  );
                },
              ),
              const SizedBox(height: 30),
              const Text(
                "HMS EGG DISTRIBUTIONS",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Page 2 - Stacked Eggs Design
class PageTwo extends StatelessWidget {
  const PageTwo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color.fromARGB(255, 51, 51, 51),
                width: 3,
              ),
            ),
            child: Image.asset('assets/image2.png', fit: BoxFit.cover),
          ),
          const Padding(
            padding: EdgeInsets.all(10.0),
            child: Text(
              "Welcome to HMS EGG DISTRIBUTORS",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "At HMS, we deliver only the finest quality eggs with a strong commitment to excellence and customer satisfaction.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 17,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/page-three');
            },
            child: const Text("CONTINUE"),
          ),
        ],
      ),
    );
  }
}

// Page 3 - Egg on Forks Design
class PageThree extends StatelessWidget {
  const PageThree({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            child: Image.asset('assets/image3.png', fit: BoxFit.cover),
          ),
          const Padding(
            padding: EdgeInsets.all(10.0),
            child: Text(
              "Trusted & Nutritious Eggs",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "We ensure freshness, hygiene, and nutritional value with every egg we deliver. Choose from a wide range of organic, free-range, and specialty eggs!",
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/page-four');
            },
            child: const Text("CONTINUE"),
          ),
        ],
      ),
    );
  }
}

// Page 4 - Final Page with CTA
class PageFour extends StatelessWidget {
  const PageFour({super.key});

  Future<void> _completeOnboarding(BuildContext context) async {
    // Set the onboarding flag to true
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    // Navigate to LoginPage
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            child: Image.asset('assets/image4.png', fit: BoxFit.cover),
          ),
          const Padding(
            padding: EdgeInsets.all(10.0),
            child: Text(
              "Why Choose HMS?",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "• Fast Delivery\n• Affordable Pricing\n• 100% Fresh Eggs\n• Trusted by 500+ customers",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _completeOnboarding(context),
            child: const Text("GET STARTED"),
          ),
        ],
      ),
    );
  }
}
