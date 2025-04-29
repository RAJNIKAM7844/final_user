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
  double creditBalance = 0.0; // Will store the correct balance
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
    _setupRealtimeSubscription();
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
        // Calculate creditBalance as sum of credits minus sum of paid
        double totalCredit = transactionsResponse.fold(0.0, (sum, t) {
          return sum + (t['credit']?.toDouble() ?? 0.0);
        });
        double totalPaid = transactionsResponse.fold(0.0, (sum, t) {
          return sum + (t['paid']?.toDouble() ?? 0.0);
        });
        creditBalance = totalCredit - totalPaid;

        transactions = transactionsResponse.map<Transaction>((t) {
          String dateStr =
              t['date']?.toString() ?? DateTime.now().toIso8601String();
          DateTime parsedDate;
          try {
            parsedDate = DateTime.parse(dateStr);
          } catch (e) {
            try {
              parsedDate = DateFormat('MMM dd').parse(dateStr);
              parsedDate = DateTime(
                  DateTime.now().year, parsedDate.month, parsedDate.day);
            } catch (e) {
              print('Error parsing date $dateStr with fallback: $e');
              parsedDate = DateTime.now();
            }
          }
          return Transaction(
            date: DateFormat('MMM dd').format(parsedDate),
            credit: t['credit']?.toDouble() ?? 0.0,
            paid: t['paid']?.toDouble() ?? 0.0,
            balance: t['balance']?.toDouble() ?? 0.0,
            modeOfPayment: t['mode_of_payment']?.toString() ?? 'N/A',
          );
        }).toList();
      });

      print('Updated creditBalance in FirstPage: $creditBalance');
      print('Updated transactions count: ${transactions.length}');
    } catch (e) {
      print('Error fetching credit data: $e');
      setState(() {
        creditBalance = 0.0;
        transactions = [];
      });
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
        .channel('transactions_user_$userId')
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
            _loadCreditData();
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
    _supabase.channel('transactions_user_*').unsubscribe();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Building FirstPage with creditBalance: $creditBalance');
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

class CreditDetailsPage extends StatefulWidget {
  final double creditBalance;
  final List<Transaction> transactions;

  const CreditDetailsPage({
    super.key,
    required this.creditBalance,
    required this.transactions,
  });

  @override
  State<CreditDetailsPage> createState() => _CreditDetailsPageState();
}

class _CreditDetailsPageState extends State<CreditDetailsPage> {
  double creditBalance = 0.0;
  List<Transaction> transactions = [];
  final _supabase = Supabase.instance.client;
  bool isLoading = false;
  int currentPage = 1;
  static const int itemsPerPage = 5;
  String sortBy = 'date';
  bool sortAscending = true;
  String? searchQuery;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    creditBalance = widget.creditBalance;
    transactions = widget.transactions;
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      print('No userId for real-time subscription in CreditDetailsPage');
      return;
    }

    print('Setting up real-time subscription for CreditDetailsPage: $userId');

    _supabase
        .channel('credit_details_user_$userId')
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
                'Real-time transaction update in CreditDetailsPage for userId $userId: $payload');
            _loadCreditData();
          },
        )
        .subscribe();
  }

  Future<void> _loadCreditData() async {
    setState(() {
      isLoading = true;
    });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('No authenticated user found');
        return;
      }

      final transactionsResponse = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);

      setState(() {
        double totalCredit = transactionsResponse.fold(0.0, (sum, t) {
          return sum + (t['credit']?.toDouble() ?? 0.0);
        });
        double totalPaid = transactionsResponse.fold(0.0, (sum, t) {
          return sum + (t['paid']?.toDouble() ?? 0.0);
        });
        creditBalance = totalCredit - totalPaid;

        transactions = transactionsResponse.map<Transaction>((t) {
          String dateStr =
              t['date']?.toString() ?? DateTime.now().toIso8601String();
          DateTime parsedDate;
          try {
            parsedDate = DateTime.parse(dateStr);
          } catch (e) {
            try {
              parsedDate = DateFormat('MMM dd').parse(dateStr);
              parsedDate = DateTime(
                  DateTime.now().year, parsedDate.month, parsedDate.day);
            } catch (e) {
              print('Error parsing date $dateStr with fallback: $e');
              parsedDate = DateTime.now();
            }
          }
          return Transaction(
            date: DateFormat('MMM dd').format(parsedDate),
            credit: t['credit']?.toDouble() ?? 0.0,
            paid: t['paid']?.toDouble() ?? 0.0,
            balance: t['balance']?.toDouble() ?? 0.0,
            modeOfPayment: t['mode_of_payment']?.toString() ?? 'N/A',
          );
        }).toList();

        _sortTransactions();
        _filterTransactions();
      });
    } catch (e) {
      print('Error fetching credit data in CreditDetailsPage: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transactions: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _sortTransactions() {
    transactions.sort((a, b) {
      switch (sortBy) {
        case 'date':
          return sortAscending
              ? a.date.compareTo(b.date)
              : b.date.compareTo(a.date);
        case 'credit':
          return sortAscending
              ? a.credit.compareTo(b.credit)
              : b.credit.compareTo(a.credit);
        case 'paid':
          return sortAscending
              ? a.paid.compareTo(b.paid)
              : b.paid.compareTo(a.paid);
        case 'balance':
          return sortAscending
              ? a.balance.compareTo(b.balance)
              : b.balance.compareTo(a.balance);
        case 'modeOfPayment':
          return sortAscending
              ? a.modeOfPayment.compareTo(b.modeOfPayment)
              : b.modeOfPayment.compareTo(a.modeOfPayment);
        default:
          return 0;
      }
    });
  }

  void _filterTransactions() {
    if (searchQuery == null || searchQuery!.isEmpty) return;
    transactions = transactions.where((t) {
      final query = searchQuery!.toLowerCase();
      return t.date.toLowerCase().contains(query) ||
          t.modeOfPayment.toLowerCase().contains(query) ||
          t.credit.toString().contains(query) ||
          t.paid.toString().contains(query) ||
          t.balance.toString().contains(query);
    }).toList();
  }

  void _showPaymentDialog() {
    final TextEditingController amountController = TextEditingController();
    String? selectedPaymentMode;
    final List<String> paymentModes = ['Cash', 'UPI', 'Bank Transfer'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make a Payment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount to Pay (₹)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedPaymentMode,
                decoration: const InputDecoration(
                  labelText: 'Mode of Payment',
                  border: OutlineInputBorder(),
                ),
                items: paymentModes.map((mode) {
                  return DropdownMenuItem<String>(
                    value: mode,
                    child: Text(mode),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedPaymentMode = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () async {
                    final amountText = amountController.text.trim();
                    final amount = double.tryParse(amountText);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter a valid amount')),
                      );
                      return;
                    }
                    if (selectedPaymentMode == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please select a mode of payment')),
                      );
                      return;
                    }
                    if (amount > creditBalance) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Amount cannot exceed current balance')),
                      );
                      return;
                    }

                    setState(() {
                      isLoading = true;
                    });

                    try {
                      final userId = _supabase.auth.currentUser?.id;
                      if (userId == null) {
                        throw Exception('User not authenticated');
                      }

                      final newBalance = creditBalance - amount;
                      await _supabase.from('transactions').insert({
                        'user_id': userId,
                        'date': DateTime.now().toIso8601String(),
                        'credit': 0.0,
                        'paid': amount,
                        'balance': newBalance,
                        'mode_of_payment': selectedPaymentMode,
                      });

                      setState(() {
                        creditBalance = newBalance;
                        isLoading = false;
                      });

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Payment recorded successfully')),
                      );
                    } catch (e) {
                      setState(() {
                        isLoading = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to record payment: $e')),
                      );
                    }
                  },
            child: isLoading
                ? const CircularProgressIndicator()
                : const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _supabase.channel('credit_details_user_*').unsubscribe();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Building CreditDetailsPage with creditBalance: $creditBalance');
    final paginatedTransactions = transactions
        .skip((currentPage - 1) * itemsPerPage)
        .take(itemsPerPage)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Details'),
        backgroundColor: const Color(0xFFB3D2F2),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sort By'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<String>(
                        value: sortBy,
                        items: [
                          'date',
                          'credit',
                          'paid',
                          'balance',
                          'modeOfPayment'
                        ]
                            .map((String value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value.capitalize()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            sortBy = value!;
                            _sortTransactions();
                          });
                          Navigator.pop(context);
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Ascending'),
                        value: sortAscending,
                        onChanged: (value) {
                          setState(() {
                            sortAscending = value;
                            _sortTransactions();
                          });
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
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
                child: Column(
                  children: [
                    Row(
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
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Credit:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '₹${transactions.fold(0.0, (sum, t) => sum + t.credit).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Paid:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '₹${transactions.fold(0.0, (sum, t) => sum + t.paid).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search (Date, Mode, Amount)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          searchController.clear();
                          searchQuery = null;
                          _filterTransactions();
                        });
                      },
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                      _filterTransactions();
                    });
                  },
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
                      onPressed:
                          creditBalance > 0 ? () => _showPaymentDialog() : null,
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
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else if (paginatedTransactions.isEmpty)
                const Center(
                    child: Text(
                  'No transactions found.',
                  style: TextStyle(color: Colors.grey),
                ))
              else
                Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paginatedTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = paginatedTransactions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 2,
                          child: ListTile(
                            title: Text(
                              'Date: ${transaction.date}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Credit: ₹${transaction.credit.toStringAsFixed(2)}'),
                                Text(
                                    'Paid: ₹${transaction.paid.toStringAsFixed(2)}'),
                                Text(
                                    'Balance: ₹${transaction.balance.toStringAsFixed(2)}'),
                                Text('Mode: ${transaction.modeOfPayment}'),
                              ],
                            ),
                            trailing: const Icon(Icons.receipt),
                          ),
                        );
                      },
                    ),
                    if (transactions.length > itemsPerPage)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: currentPage > 1
                                ? () {
                                    setState(() {
                                      currentPage--;
                                    });
                                  }
                                : null,
                          ),
                          Text('Page $currentPage'),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: currentPage <
                                    (transactions.length / itemsPerPage).ceil()
                                ? () {
                                    setState(() {
                                      currentPage++;
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Extension to capitalize strings for dropdown
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}
