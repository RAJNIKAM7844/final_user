import 'package:flutter/material.dart';
import 'package:hms_pro/home_page.dart';
import 'package:hms_pro/trans.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Added for DateTime formatting

// Transaction Model
class Transaction {
  final String date;
  final double credit;
  final double paid;
  final double balance;
  final String modeOfPayment;

  Transaction({
    required this.date,
    required this.credit,
    required this.paid,
    required this.balance,
    required this.modeOfPayment,
  });
}

// Transaction Data
final List<Transaction> transactions = [
  Transaction(
      date: "Mar 22",
      credit: 2000,
      paid: 500,
      balance: 500,
      modeOfPayment: "Cash"),
  Transaction(
      date: "Mar 22",
      credit: 5000,
      paid: 2000,
      balance: 3000,
      modeOfPayment: "Cash"),
  Transaction(
      date: "Mar 22",
      credit: 2000,
      paid: 1000,
      balance: 1000,
      modeOfPayment: "Cash"),
  Transaction(
      date: "Mar 22",
      credit: 4000,
      paid: 2000,
      balance: 2000,
      modeOfPayment: "Online"),
  Transaction(
      date: "Mar 22",
      credit: 6000,
      paid: 5000,
      balance: 2000,
      modeOfPayment: "Cash"),
  Transaction(
      date: "Mar 22",
      credit: 1000,
      paid: 6000,
      balance: 4000,
      modeOfPayment: "Online"),
  Transaction(
      date: "Mar 22",
      credit: 2000,
      paid: 1000,
      balance: 1000,
      modeOfPayment: "Cash"),
  Transaction(
      date: "Mar 22",
      credit: 5000,
      paid: 4000,
      balance: 1000,
      modeOfPayment: "Online"),
  Transaction(
      date: "Mar 22",
      credit: 7800,
      paid: 6000,
      balance: 2200,
      modeOfPayment: "Online"),
  Transaction(
      date: "Mar 22",
      credit: 2700,
      paid: 5000,
      balance: 2000,
      modeOfPayment: "Cash"),
  Transaction(
      date: "Mar 22",
      credit: 2300,
      paid: 2000,
      balance: 1000,
      modeOfPayment: "Cash"),
];

class FirstPage extends StatefulWidget {
  const FirstPage({super.key});

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double eggRate = 1.0;
  double targetRate = 4.7;
  String? _profileImageUrl;
  bool _isLoadingProfileImage = true;
  DateTime? _lastUpdated; // Variable to store updated_at timestamp

  final List<String> images = [
    'assets/eggs1.png',
    'assets/eggs2.png',
    'assets/eggs3.png',
  ];

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
    _loadEggRate();
    _fetchProfileImage();
  }

  Future<void> _loadEggRate() async {
    try {
      final response = await _supabase
          .from('egg_rates')
          .select('rate, updated_at') // Fetch rate and updated_at
          .eq('id', 1)
          .maybeSingle();

      if (response != null && response['rate'] != null) {
        setState(() {
          targetRate = response['rate'].toDouble();
          _lastUpdated = response['updated_at'] != null
              ? DateTime.parse(response['updated_at'])
              : null; // Store updated_at if available
        });
      } else {
        setState(() {
          targetRate = 4.7;
          _lastUpdated = null; // No timestamp if no data
        });
      }
    } catch (e) {
      print('Error fetching egg rate: $e');
      setState(() {
        targetRate = 4.7;
        _lastUpdated = null;
      });
    }
    animateRate();
  }

  Future<void> _fetchProfileImage() async {
    setState(() {
      _isLoadingProfileImage = true;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;

      if (userId == null) {
        setState(() {
          _isLoadingProfileImage = false;
        });
        return;
      }

      final response = await _supabase
          .from('users')
          .select('profile_image')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && response['profile_image'] != null) {
        final imagePath = response['profile_image'];
        if (imagePath.startsWith('userprofile/')) {
          _profileImageUrl = _supabase.storage
              .from('userprofile')
              .getPublicUrl(imagePath.replaceFirst('userprofile/', ''));
        } else {
          _profileImageUrl = imagePath;
        }
      }
    } catch (e) {
      print('Error fetching profile image: $e');
    } finally {
      setState(() {
        _isLoadingProfileImage = false;
      });
    }
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

  // Format DateTime to a readable string (e.g., "9 April, 6:32 AM")
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    final formatter = DateFormat('d MMMM, h:mm a');
    return formatter.format(dateTime);
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadEggRate(),
      _fetchProfileImage(),
    ]);
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
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Stack(
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
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreditDetailsPage(
                                    creditBalance: 0.0,
                                    transactions: transactions,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black12, blurRadius: 4),
                                ],
                              ),
                              child: const Text(
                                'Credit : ₹0.0',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
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
                              backgroundImage: _profileImageUrl != null &&
                                      !_isLoadingProfileImage
                                  ? NetworkImage(_profileImageUrl!)
                                  : null,
                              child: _profileImageUrl == null ||
                                      _isLoadingProfileImage
                                  ? const Icon(Icons.person,
                                      color: Colors.black)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'HMS EGG DISTRIBUTORS',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
                              child:
                                  Image.asset(images[index], fit: BoxFit.cover),
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
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Today :',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8),
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
                    Text(
                      'Last updated: ${_formatDateTime(_lastUpdated)}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
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
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
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
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreditDetailsPage extends StatelessWidget {
  final double creditBalance;
  final List<Transaction> transactions;

  const CreditDetailsPage({
    super.key,
    required this.creditBalance,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Details'),
        backgroundColor: const Color(0xFFB3D2F2),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Credit Balance:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${creditBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Make a Payment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Payment functionality coming soon!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Pay Now',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Transaction History',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(
                          label: Text('Date',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Credit',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Paid',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Balance',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Mode',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: transactions.map((transaction) {
                      return DataRow(cells: [
                        DataCell(Text(transaction.date)),
                        DataCell(
                            Text('₹${transaction.credit.toStringAsFixed(2)}')),
                        DataCell(
                            Text('₹${transaction.paid.toStringAsFixed(2)}')),
                        DataCell(
                            Text('₹${transaction.balance.toStringAsFixed(2)}')),
                        DataCell(Text(transaction.modeOfPayment)),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
