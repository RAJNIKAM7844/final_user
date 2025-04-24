import 'package:flutter/material.dart';
import '../widgets/custom_background.dart'; // adjust the path as needed

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Main Content
              SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 60),

                    // Title
                    Container(
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      child: const Text(
                        'About.',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Image
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/image.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Description
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: "Welcome to "),
                            TextSpan(
                              text: "HMS EGG DISTRIBUTORS",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ", your trusted source for premium-quality eggs. Founded with a passion for delivering freshness and flavor to every table, we are dedicated to providing our customers with the best eggs available.",
                            ),
                          ],
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),

              // Profile Icon (Top Right)
            ],
          ),
        ),
      ),
    );
  }
}
