import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../utils/download_helper.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<dynamic>> _pendingPaymentsFuture;
  late Future<List<dynamic>> _receiptsFuture;

  static const _paper = Color(0xFFF4F2ED);
  static const _surface = Color(0xFFFFFEFB);
  static const _ink = Color(0xFF17202A);
  static const _navy = Color(0xFF172B4D);
  static const _blue = Color(0xFF356AE6);
  static const _orange = Color(0xFFE47543);
  static const _green = Color(0xFF278B68);
  static const _red = Color(0xFFC84C43);
  static const _muted = Color(0xFF6E7681);
  static const _line = Color(0xFFE2DED5);
  static const _soft = Color(0xFFF0EEE8);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPayments();
  }

  void _loadPayments({bool forceRefresh = false}) {
    _pendingPaymentsFuture =
        _getPendingPayments(forceRefresh: forceRefresh);
    _receiptsFuture = _getReceipts(forceRefresh: forceRefresh);
  }

  Future<List<dynamic>> _getPendingPayments({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final mem = StorageService.getMemoryCache('payments');
      if (mem is List && mem.isNotEmpty) {
        return List<dynamic>.from(mem);
      }

      final disk = await StorageService.getCache('payments');
      if (disk is List && disk.isNotEmpty) {
        return List<dynamic>.from(disk);
      }
    }

    final auth = ref.read(authProvider);

    try {
      final fresh = await apiService.fetchPendingPayments(
        username: auth.username ?? '',
        password: auth.password ?? '',
      );

      if (fresh.isNotEmpty) {
        await StorageService.setCache('payments', fresh);
        return fresh;
      }
    } catch (e) {
      debugPrint(
        'PaymentsScreen: Pending payments fetch failed ($e). '
        'Checking cache...',
      );

      final fallback = StorageService.getMemoryCache('payments') ??
          await StorageService.getCache('payments');

      if (fallback is List && fallback.isNotEmpty) {
        return List<dynamic>.from(fallback);
      }

      rethrow;
    }

    final fallback = StorageService.getMemoryCache('payments') ??
        await StorageService.getCache('payments');

    if (fallback is List && fallback.isNotEmpty) {
      return List<dynamic>.from(fallback);
    }

    return [];
  }

  Future<List<dynamic>> _getReceipts({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final mem = StorageService.getMemoryCache('receipts');
      if (mem is List && mem.isNotEmpty) {
        return List<dynamic>.from(mem);
      }

      final disk = await StorageService.getCache('receipts');
      if (disk is List && disk.isNotEmpty) {
        return List<dynamic>.from(disk);
      }
    }

    final auth = ref.read(authProvider);

    try {
      final fresh = await apiService.fetchPaymentReceipts(
        username: auth.username ?? '',
        password: auth.password ?? '',
      );

      if (fresh.isNotEmpty) {
        await StorageService.setCache('receipts', fresh);
        return fresh;
      }
    } catch (e) {
      debugPrint(
        'PaymentsScreen: Receipts fetch failed ($e). '
        'Checking cache...',
      );

      final fallback = StorageService.getMemoryCache('receipts') ??
          await StorageService.getCache('receipts');

      if (fallback is List && fallback.isNotEmpty) {
        return List<dynamic>.from(fallback);
      }

      rethrow;
    }

    final fallback = StorageService.getMemoryCache('receipts') ??
        await StorageService.getCache('receipts');

    if (fallback is List && fallback.isNotEmpty) {
      return List<dynamic>.from(fallback);
    }

    return [];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshPending() async {
    setState(() {
      _pendingPaymentsFuture =
          _getPendingPayments(forceRefresh: true);
    });
    await _pendingPaymentsFuture;
  }

  Future<void> _refreshReceipts() async {
    setState(() {
      _receiptsFuture = _getReceipts(forceRefresh: true);
    });
    await _receiptsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPendingTab(),
                  _buildReceiptsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 13),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _navy,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FINANCE',
                  style: GoogleFonts.spaceGrotesk(
                    color: _orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Payments & Dues',
                  style: GoogleFonts.dmSans(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              if (_tabController.index == 0) {
                _refreshPending();
              } else {
                _refreshReceipts();
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _line),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: _navy,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _line),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _line),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: _navy,
          unselectedLabelColor: _muted,
          labelStyle: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions_rounded, size: 16),
              text: 'Pending Dues',
            ),
            Tab(
              icon: Icon(Icons.receipt_long_rounded, size: 16),
              text: 'Receipts',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTab() {
    return RefreshIndicator(
      color: _blue,
      backgroundColor: _surface,
      onRefresh: _refreshPending,
      child: FutureBuilder<List<dynamic>>(
        future: _pendingPaymentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoading('Loading payment dues...');
          }

          if (snapshot.hasError) {
            return _buildError(
              'Could not load pending dues',
              snapshot.error!,
              _refreshPending,
            );
          }

          final payments = snapshot.data ?? [];

          if (payments.isEmpty) {
            return _buildNoDues();
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
            children: [
              _buildOverview(
                eyebrow: 'CURRENT BALANCE',
                title: '${payments.length} pending '
                    '${payments.length == 1 ? 'payment' : 'payments'}',
                subtitle: 'University dues requiring attention',
                icon: Icons.account_balance_wallet_rounded,
                color: _red,
                background: const Color(0xFFFCEDEA),
              ),
              const SizedBox(height: 18),
              _buildSectionLabel(
                'PENDING PAYMENTS',
                '${payments.length} DUE',
              ),
              const SizedBox(height: 10),
              ...payments.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildPaymentCard(entry.value, entry.key),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentCard(dynamic payment, int index) {
    final description =
        payment['fee_description']?.toString() ?? 'Fee Description';
    final dueDate = payment['due_date']?.toString() ?? 'Immediate';
    final amount = payment['amount']?.toString() ?? '0';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0617202A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFCEDEA),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: _red,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      color: _muted,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Due: $dueDate',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: _muted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'AMOUNT',
                style: GoogleFonts.spaceGrotesk(
                  color: _muted,
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .65,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '₹$amount',
                style: GoogleFonts.dmSans(
                  color: _red,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptsTab() {
    return RefreshIndicator(
      color: _blue,
      backgroundColor: _surface,
      onRefresh: _refreshReceipts,
      child: FutureBuilder<List<dynamic>>(
        future: _receiptsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoading('Loading payment receipts...');
          }

          if (snapshot.hasError) {
            return _buildError(
              'Could not load payment receipts',
              snapshot.error!,
              _refreshReceipts,
            );
          }

          final receipts = snapshot.data ?? [];

          if (receipts.isEmpty) {
            return _buildNoReceipts();
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
            children: [
              _buildOverview(
                eyebrow: 'PAYMENT HISTORY',
                title: '${receipts.length} recorded '
                    '${receipts.length == 1 ? 'receipt' : 'receipts'}',
                subtitle: 'Completed university payment records',
                icon: Icons.verified_rounded,
                color: _green,
                background: const Color(0xFFE8F4EF),
              ),
              const SizedBox(height: 18),
              _buildSectionLabel(
                'RECEIPT HISTORY',
                '${receipts.length} RECORDS',
              ),
              const SizedBox(height: 10),
              ...receipts.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildReceiptCard(entry.value, entry.key),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReceiptCard(dynamic receipt, int index) {
    final receiptNo = receipt['receipt_number']?.toString() ??
        receipt['receipt_no']?.toString() ??
        'Receipt';
    final date = receipt['transaction_date']?.toString() ??
        receipt['receipt_date']?.toString() ??
        '';
    final amount = receipt['amount']?.toString() ?? '0';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0617202A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4EF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.receipt_rounded,
              color: _green,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receiptNo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                if (date.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.event_outlined,
                        color: _muted,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          date,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            color: _muted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                Text(
                  '₹$amount',
                  style: GoogleFonts.dmSans(
                    color: _green,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _downloadReceipt(receiptNo),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FD),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: const Color(0xFFC9D7F7),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.download_rounded,
                    color: _blue,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Receipt',
                    style: GoogleFonts.dmSans(
                      color: _blue,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReceipt(String receiptNo) async {
    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';

    try {
      final profile =
          await apiService.fetchProfile(username, password);
      final appNo =
          profile['application_number']?.toString() ?? username;

      final receiptHtml =
          await apiService.downloadPaymentReceipt(
        username: username,
        password: password,
        receiptNo: receiptNo,
        applicationNumber: appNo,
      );

      if (!mounted) return;

      await DownloadHelper.saveFile(
        context: context,
        fileName: 'VITAP_Payment_Receipt_$receiptNo.html',
        content: receiptHtml,
        mimeType: 'text/html',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          content: Text(
            'Download failed: $e',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildOverview({
    required String eyebrow,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFFAEBBD0),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFC1CAD7),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title, String count) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: _ink,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            count,
            style: GoogleFonts.spaceGrotesk(
              color: _navy,
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: .45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * .65,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _blue,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: GoogleFonts.dmSans(
                    color: _muted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(
    String title,
    Object error,
    Future<void> Function() retry,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * .65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCEDEA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: _red,
                      size: 31,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: _muted,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 17),
                  FilledButton.icon(
                    onPressed: retry,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 17,
                    ),
                    label: Text(
                      'Try Again',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoDues() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * .65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F4EF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: _green,
                      size: 35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Pending Dues!',
                    style: GoogleFonts.dmSans(
                      color: _ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All university tuition and hostel fees are cleared.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: _muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoReceipts() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * .65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF0FD),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: _blue,
                      size: 31,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Payment Receipts',
                    style: GoogleFonts.dmSans(
                      color: _ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your completed payment records will appear here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: _muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
