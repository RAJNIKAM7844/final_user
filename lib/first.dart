import 'package:flutter/material.dart';
import 'package:hms_pro/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
  DateTime? _lastUpdated;
  double creditBalance = 0.0; // Will store the sum of transaction credits
  List<Transaction> transactions = []; // To store fetched transactions

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
    _loadCreditData();
    _setupRealtimeSubscription(); // Set up real-time subscription
  }

  // Load balance and transactions from Supabase with robust date parsing
  Future<void> _loadCreditData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('No authenticated user found');
        return;
      }

      print('Fetching credit data for userId: $userId');

      // Fetch transactions from transactions table
      final transactionsResponse = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);

      print('Transactions response for userId $userId: $transactionsResponse');

      setState(() {
        // Calculate creditBalance as the sum of all credit values
        creditBalance = transactionsResponse.fold(0.0, (sum, t) {
          return sum + (t['credit']?.toDouble() ?? 0.0);
        });
        transactions = transactionsResponse.map<Transaction>((t) {
          String dateStr =
              t['date']?.toString() ?? DateTime.now().toIso8601String();
          DateTime parsedDate;
          try {
            // Try ISO 8601 format first
            parsedDate = DateTime.parse(dateStr);
          } catch (e) {
            // Fallback to MMM dd format if ISO fails
            try {
              parsedDate = DateFormat('MMM dd').parse(dateStr);
              // Ensure year is set to current year for consistency
              parsedDate = DateTime(
                  DateTime.now().year, parsedDate.month, parsedDate.day);
            } catch (e) {
              print('Error parsing date $dateStr with fallback: $e');
              parsedDate = DateTime.now(); // Final fallback
            }
          }
          return Transaction(
            date: DateFormat('MMM dd').format(parsedDate),
            credit: t['credit'].toDouble(),
            paid: t['paid'].toDouble(),
            balance: t['balance'].toDouble(),
            modeOfPayment: t['mode_of_payment']?.toString() ?? 'N/A',
          );
        }).toList();
      });

      print(
          'Updated creditBalance (sum of credits) in FirstPage: $creditBalance');
      print('Updated transactions count: ${transactions.length}');
    } catch (e) {
      print('Error fetching credit data: $e');
    }
  }

  // Set up real-time subscription for balance and transactions
  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      print('No userId for real-time subscription');
      return;
    }

    print('Setting up real-time subscription for userId: $userId');

    _supabase
        .channel('users')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            print(
                'Real-time balance update received for userId $userId: $payload');
            // Note: This subscription is kept for compatibility, but we'll rely on transaction updates
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            print(
                'Real-time transaction update received for userId $userId: $payload');
            _loadCreditData(); // Refresh transactions and recalculate creditBalance
          },
        )
        .subscribe();
  }

  Future<void> _loadEggRate() async {
    try {
      final response = await _supabase
          .from('egg_rates')
          .select('rate, updated_at')
          .eq('id', 1)
          .maybeSingle();

      print('Egg rate response: $response');

      if (response != null && response['rate'] != null) {
        setState(() {
          targetRate = response['rate'].toDouble();
          _lastUpdated = response['updated_at'] != null
              ? DateTime.parse(response['updated_at'].toString())
              : null;
        });
      } else {
        setState(() {
          targetRate = 4.7;
          _lastUpdated = null;
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
        print('No userId for fetching profile image');
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

      print('Profile image response: $response');

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

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    final formatter = DateFormat('d MMMM, h:mm a');
    return formatter.format(dateTime);
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadEggRate(),
      _fetchProfileImage(),
      _loadCreditData(),
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
  void dispose() {
    _supabase.channel('users').unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(
        'Building FirstPage with creditBalance: $creditBalance'); // Debug UI build
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
                                    creditBalance: creditBalance,
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
                              child: Text(
                                'Credit: ₹${creditBalance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
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
    print(
        'Building CreditDetailsPage with creditBalance: $creditBalance'); // Debug UI build
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
