import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
import '../widgets/shadcn/shadcn_ui.dart';
import '../widgets/motion/nexus_motion.dart';

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

  AppPalette get _palette => AppPalette.of(context);
  Color get _background => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _navy => _palette.navy;
  Color get _orange => _palette.orange;
  Color get _green => _palette.green;
  Color get _red => _palette.red;
  Color get _soft => _palette.soft;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPayments();
  }

  void _loadPayments({bool forceRefresh = false}) {
    _pendingPaymentsFuture = _getPendingPayments(forceRefresh: forceRefresh);
    _receiptsFuture = _getReceipts(forceRefresh: forceRefresh);
  }

  Future<List<dynamic>> _getPendingPayments({bool forceRefresh = false}) async {
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
      debugPrint('PaymentsScreen: Pending payments fetch failed ($e). Checking cache...');
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

  Future<List<dynamic>> _getReceipts({bool forceRefresh = false}) async {
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
      debugPrint('PaymentsScreen: Receipts fetch failed ($e). Checking cache...');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 72,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FINANCIALS',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _orange,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Payments & Dues',
              style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: IconButton(
              tooltip: 'Refresh Payments',
              icon: Icon(Icons.refresh_rounded, color: _navy, size: 20),
              onPressed: () {
                setState(() => _loadPayments(forceRefresh: true));
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _palette.isDark ? 0.3 : 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: _navy,
              unselectedLabelColor: _muted,
              labelStyle: GoogleFonts.spaceGrotesk(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
              unselectedLabelStyle: GoogleFonts.spaceGrotesk(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              tabs: const [
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pending_actions_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Pending Dues'),
                    ],
                  ),
                ),
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Receipts'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildReceiptsTab(),
        ],
      ),
    );
  }

  Widget _buildSkeletonPayments() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 90,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
      ),
    );
  }

  Widget _buildPendingTab() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loadPayments(forceRefresh: true));
        await _pendingPaymentsFuture;
      },
      color: _navy,
      backgroundColor: _surface,
      child: FutureBuilder<List<dynamic>>(
        future: _pendingPaymentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonPayments();
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 44, color: _red),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load pending dues',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ErrorFormatter.format(snapshot.error),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          final payments = snapshot.data ?? [];
          if (payments.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: 38,
                              color: _green,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Pending Dues! 🎉',
                            style: GoogleFonts.dmSans(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'All university tuition, hostel, and academic fees are completely cleared.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: _muted,
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

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final p = payments[index];
              final feeDesc = (p['fee_description'] ?? p['fee_desc'] ?? 'Fee Description').toString();
              final dueDate = (p['due_date'] ?? 'Immediate').toString();
              final amount = (p['amount'] ?? '0').toString();
              return AnimeStaggerItem(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NexusCard(
                    variant: NexusCardVariant.standard,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.pending_actions_rounded, color: _red, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feeDesc,
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _soft,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _line),
                              ),
                              child: Text(
                                'Due: $dueDate',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '₹$amount',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          );
        },
      ),
    );
  }

  Widget _buildReceiptsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loadPayments(forceRefresh: true));
        await _receiptsFuture;
      },
      color: _navy,
      backgroundColor: _surface,
      child: FutureBuilder<List<dynamic>>(
        future: _receiptsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonPayments();
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 44, color: _red),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load payment receipts',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ErrorFormatter.format(snapshot.error),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          final receipts = snapshot.data ?? [];
          if (receipts.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: _soft,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              size: 34,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Payment Receipts',
                            style: GoogleFonts.dmSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your completed payment receipts will show up here.',
                            style: GoogleFonts.dmSans(fontSize: 12.5, color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            itemCount: receipts.length,
            itemBuilder: (context, index) {
              final r = receipts[index];
              final receiptNo = (r['receipt_number'] ?? r['receipt_no'] ?? 'Receipt').toString();
              final date = (r['transaction_date'] ?? r['receipt_date'] ?? '').toString();
              final amount = (r['amount'] ?? '0').toString();

              return AnimeStaggerItem(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NexusCard(
                    variant: NexusCardVariant.standard,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.receipt_rounded, color: _green, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                receiptNo,
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              if (date.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  date,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: _muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹$amount',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _green,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'PAID',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: _green,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
