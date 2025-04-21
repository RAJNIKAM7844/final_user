import 'package:flutter/material.dart';
import 'package:hms_pro/home_page.dart';

class FirstPage extends StatefulWidget {
  const FirstPage({super.key});

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double eggRate = 1.0;
  final double targetRate = 4.7;

  final List<String> images = [
    'assets/eggs1.png',
    'assets/eggs2.png',
    'assets/eggs3.png',
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
    animateRate();
  }

  void _startAutoScroll() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (_pageController.hasClients) {
        setState(() {
          _currentPage = (_currentPage + 1) % images.length;
        });
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
      return true;
    });
  }

  void animateRate() async {
    for (double i = 1.0; i <= targetRate; i += 0.01) {
      await Future.delayed(const Duration(milliseconds: 2));
      setState(() {
        eggRate = double.parse(i.toStringAsFixed(2));
      });
    }
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(images.length, (index) {
        return GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
            setState(() {
              _currentPage = index;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 12 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == index ? Colors.deepPurple : Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                height: MediaQuery.of(context).size.height * 0.3,
                decoration: const BoxDecoration(
                  color: Color(0xFFB3D2F2),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
              ),
              Expanded(
                child: Container(color: Colors.white),
              ),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4)
                          ],
                        ),
                        child: const Text('Credit : ₹0.0',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const HomePage(initialIndex: 3)),
                          );
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, color: Colors.black),
                        ),
                      )
                    ],
                  ),
                ),
                const Text(
                  'HMS EGG DISTRIBUTORS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: images.length,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(images[index], fit: BoxFit.cover),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildDotsIndicator(),
                const SizedBox(height: 30),
                const Text(
                  'NECC Egg Rate In Bengaluru',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Today :',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 8)
                    ],
                  ),
                  child: Text(
                    '₹${eggRate.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Last updated: 9 April, 6:32 AM',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "At ",
                          style: TextStyle(color: Colors.black),
                        ),
                        TextSpan(
                          text: "HMS EGG DISTRIBUTORS",
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              ", we take pride in delivering the finest quality eggs to your doorstep.....",
                          style: TextStyle(color: Colors.black),
                        ),
                      ],
                      style: TextStyle(fontSize: 18),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
