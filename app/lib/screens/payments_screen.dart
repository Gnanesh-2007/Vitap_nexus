import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mesh_ambient_background.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<dynamic>> _pendingPaymentsFuture;
  late Future<List<dynamic>> _receiptsFuture;

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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Payments & Dues', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF14B8A6),
          labelColor: const Color(0xFF14B8A6),
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions_rounded, size: 18), text: 'Pending Dues'),
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Receipts History'),
          ],
        ),
      ),
      body: MeshAmbientBackground(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPendingTab(),
            _buildReceiptsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonPayments() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: 16),
          Text('Loading payments...', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loadPayments(forceRefresh: true));
        await _pendingPaymentsFuture;
      },
      color: const Color(0xFF14B8A6),
      backgroundColor: AppTheme.surface,
      child: FutureBuilder<List<dynamic>>(
        future: _pendingPaymentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonPayments();
          }

          final payments = snapshot.data ?? [];
          if (payments.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 54, color: Color(0xFF10B981)),
                        const SizedBox(height: 12),
                        Text('No Pending Dues! 🎉', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('All university tuition and hostel fees are cleared.', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final p = payments[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['fee_description'] ?? 'Fee Description', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Due Date: ${p['due_date'] ?? 'Immediate'}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Text('₹${p['amount'] ?? '0'}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.error)),
                  ],
                ),
              )
                  .animate(delay: (30 * index).ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.05, end: 0);
            },
          );
        },
      ),
    );
  }

  Future<void> _downloadReceipt(String receiptNo) async {
    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';

    try {
      final profile = await apiService.fetchProfile(username, password);
      final appNo = profile['application_number']?.toString() ?? username;

      final receiptHtml = await apiService.downloadPaymentReceipt(
        username: username,
        password: password,
        receiptNo: receiptNo,
        applicationNumber: appNo,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text('Receipt $receiptNo downloaded successfully (${(receiptHtml.length / 1024).toStringAsFixed(1)} KB)', style: GoogleFonts.inter(color: Colors.white)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.error, content: Text('Download failed: $e')),
      );
    }
  }

  Widget _buildReceiptsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loadPayments(forceRefresh: true));
        await _receiptsFuture;
      },
      color: const Color(0xFF14B8A6),
      backgroundColor: AppTheme.surface,
      child: FutureBuilder<List<dynamic>>(
        future: _receiptsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonPayments();
          }

          final receipts = snapshot.data ?? [];
          if (receipts.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_rounded, size: 54, color: Color(0xFF64748B)),
                        const SizedBox(height: 12),
                        Text('No Payment Receipts', style: GoogleFonts.outfit(fontSize: 16, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            itemCount: receipts.length,
            itemBuilder: (context, index) {
              final r = receipts[index];
              final receiptNo = r['receipt_number']?.toString() ?? r['receipt_no']?.toString() ?? 'Receipt';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(receiptNo, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(r['transaction_date'] ?? r['receipt_date'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                          const SizedBox(height: 4),
                          Text('₹${r['amount'] ?? '0'}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _downloadReceipt(receiptNo),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Receipt', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                        foregroundColor: AppTheme.cyanAccent,
                        elevation: 0,
                        side: const BorderSide(color: AppTheme.cyanAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              )
                  .animate(delay: (30 * index).ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.05, end: 0);
            },
          );
        },
      ),
    );
  }
}

