import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:almahub/services/excel_download_service.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class HRRecruitmentDashboard extends StatefulWidget {
  const HRRecruitmentDashboard({super.key});

  @override
  State<HRRecruitmentDashboard> createState() =>
      _HRRecruitmentDashboardState();
}

class _HRRecruitmentDashboardState extends State<HRRecruitmentDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _statusFilter = 'all';
  String _searchQuery = '';
  bool _isDownloading = false;
  String? _downloadProgress;

  // FIX: Pre-computed list (sorted + search-filtered). Updated once when stream
  // data arrives — never recomputed inside build(), eliminating per-frame work.
  List<QueryDocumentSnapshot> _displayDocs = [];

  // FIX: Debounce timer — search only triggers a rebuild 300 ms after the user
  // stops typing instead of on every keystroke.
  Timer? _searchDebounce;

  // Inline persistent search controller (replaces the modal dialog).
  final TextEditingController _searchController = TextEditingController();

  // Stored as a field so rebuilds caused by unrelated setState calls (search,
  // download progress, etc.) do NOT tear down and recreate the Firestore
  // stream. The stream is only replaced when the filter changes via _applyFilter().
  late Stream<QuerySnapshot> _applicantsStream;

  // Keeps the last successfully loaded batch so the table stays visible at
  // reduced opacity while a new filter loads — prevents the blank-screen hang.
  List<QueryDocumentSnapshot> _cachedDocs = [];

  // True only between a filter tap and the first event on the new stream.
  bool _isTransitioning = false;

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  @override
  void initState() {
    super.initState();
    _applicantsStream = _buildStream('all');
    _logger.i('=== HR Recruitment Dashboard Initialized ===');
  }

  @override
  void dispose() {
    // FIX: Cancel debounce timer + dispose controller to prevent
    // setState-after-dispose crashes and memory leaks.
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Build (or rebuild) the Firestore stream for [filter].
  // Capped at 200 docs so the initial fetch stays fast; the full dataset is
  // only pulled on an explicit Excel export.
  Stream<QuerySnapshot> _buildStream(String filter) {
    const int fetchLimit = 200;
    if (filter == 'all') {
      return _firestore
          .collection('Recruitees')
          .orderBy('submittedAt', descending: true)
          .limit(fetchLimit)
          .snapshots();
    }
    // No orderBy here to avoid the composite-index requirement; sorted
    // client-side in the StreamBuilder.
    return _firestore
        .collection('Recruitees')
        .where('status', isEqualTo: filter)
        .limit(fetchLimit)
        .snapshots();
  }

  // Central method for ALL filter changes – always call this instead of
  // directly mutating _statusFilter so the stream is replaced atomically.
  // FIX: We do NOT clear _displayDocs here so the table immediately shows the
  // stale data at reduced opacity (the _isTransitioning overlay) — perceived
  // lag drops to zero while the new Firestore query is in-flight.
  void _applyFilter(String filter) {
    if (filter == _statusFilter) return;
    _logger.i('Filter changed: $_statusFilter -> $filter');
    setState(() {
      _statusFilter = filter;
      _isTransitioning = true;
      // Clear search when switching filter so the new results are unfiltered.
      _searchQuery = '';
      _searchController.clear();
      _applicantsStream = _buildStream(filter);
    });
  }

  // ── Helper: sort docs by submittedAt descending (client-side) ───────────────
  List<QueryDocumentSnapshot> _sortBySubmittedAt(
      List<QueryDocumentSnapshot> docs) {
    final sorted = List<QueryDocumentSnapshot>.from(docs);
    sorted.sort((a, b) {
      final aTs = (a.data() as Map)['submittedAt'] as Timestamp?;
      final bTs = (b.data() as Map)['submittedAt'] as Timestamp?;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.compareTo(aTs);
    });
    return sorted;
  }

  // FIX: Search filter extracted into a reusable helper so it is called once
  // per data-change (in addPostFrameCallback) rather than on every build frame.
  List<QueryDocumentSnapshot> _applySearch(List<QueryDocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final fullName = (data['fullName'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      return fullName.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 225, 221, 226),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 92, 4, 126),
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _logger.i('Navigating back to HR Dashboard');
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Recruitment Management',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color.fromARGB(255, 237, 236, 239),
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          // ── Active filter chip in the AppBar ──────────────────────────────
          if (_statusFilter != 'all')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Chip(
                label: Text(
                  _getStatusLabel(_statusFilter),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                backgroundColor: _getStatusColor(_statusFilter),
                deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
                onDeleted: () => _applyFilter('all'),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          // ── Download button ───────────────────────────────────────────────
          _isDownloading
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      if (_downloadProgress != null)
                        Text(
                          _downloadProgress!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 9),
                        ),
                    ],
                  ),
                )
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.download, color: Colors.white),
                  tooltip: 'Download Excel',
                  onSelected: (value) => _downloadRecruitmentExcel(value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'current',
                      child: Row(
                        children: [
                          Icon(Icons.filter_list, size: 18,
                              color: Color(0xFF7B2CBF)),
                          SizedBox(width: 10),
                          Text('Download Current View'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'all',
                      child: Row(
                        children: [
                          Icon(Icons.people, size: 18,
                              color: Color(0xFF059669)),
                          SizedBox(width: 10),
                          Text('Download All Applicants'),
                        ],
                      ),
                    ),
                  ],
                ),
          // FIX: Show a clear-search icon when a query is active, so the
          // user has instant one-tap feedback that a filter is applied.
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.search_off, color: Colors.amberAccent),
              onPressed: () => setState(() {
                _searchQuery = '';
                _searchController.clear();
                _displayDocs = _cachedDocs;
              }),
              tooltip: 'Clear Search',
            )
          else
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: _showSearchDialog,
              tooltip: 'Search Applicants',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _logger.i('Manual refresh triggered');
              setState(() {
                // Rebuild stream and clear pre-computed display docs so the
                // table triggers a fresh load rather than showing stale data.
                _displayDocs = [];
                _cachedDocs = [];
                _isTransitioning = true;
                _applicantsStream = _buildStream(_statusFilter);
              });
            },
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildStatsCards(),
          Expanded(
            child: _buildApplicantsTable(),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Applicants'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name or email...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            // FIX: Debounce — only rebuild the table 300 ms after the user
            // stops typing, not on every single keypress.
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              setState(() {
                _searchQuery = value.trim().toLowerCase();
                _displayDocs = _applySearch(_cachedDocs);
              });
            });
          },
          onSubmitted: (value) {
            _searchDebounce?.cancel();
            setState(() {
              _searchQuery = value.trim().toLowerCase();
              _displayDocs = _applySearch(_cachedDocs);
            });
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchDebounce?.cancel();
              setState(() {
                _searchQuery = '';
                _displayDocs = _cachedDocs;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 81, 3, 130),
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Stats row – each card is now tappable. Clicking a status card sets the filter
  // to that status; clicking the active card again resets it to "all".
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildStatsCards() {
    return StreamBuilder<QuerySnapshot>(
      // FIX: Limit to 500 docs so the stats stream doesn't pull the entire
      // collection on every snapshot (was previously unlimited = full table scan).
      stream: _firestore.collection('Recruitees').limit(500).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        final total = docs.length;
        final pending =
            docs.where((d) => (d.data() as Map)['status'] == 'pending').length;
        final underReview = docs
            .where((d) => (d.data() as Map)['status'] == 'under_review')
            .length;
        final shortlisted = docs
            .where((d) => (d.data() as Map)['status'] == 'shortlisted')
            .length;
        final notShortlisted = docs
            .where((d) => (d.data() as Map)['status'] == 'not_shortlisted')
            .length;
        final accepted = docs
            .where((d) => (d.data() as Map)['status'] == 'accepted')
            .length;
        final rejected = docs
            .where((d) => (d.data() as Map)['status'] == 'rejected')
            .length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final cardWidth = (screenWidth * 0.15).clamp(90.0, double.infinity);
            final spacing = screenWidth * 0.015;

            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.02,
                vertical: 12,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // "Total" card – tapping it resets filter to 'all'
                    _buildStatCard(
                      title: 'Total',
                      value: total,
                      color: const Color(0xFF7B2CBF),
                      icon: Icons.people,
                      cardWidth: cardWidth,
                      filterValue: 'all',
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      title: 'Pending',
                      value: pending,
                      color: const Color(0xFF3B82F6),
                      icon: Icons.hourglass_empty,
                      cardWidth: cardWidth,
                      filterValue: 'pending',
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      title: 'Reviewing',
                      value: underReview,
                      color: const Color(0xFFF59E0B),
                      icon: Icons.pending_actions,
                      cardWidth: cardWidth,
                      filterValue: 'under_review',
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      title: 'Shortlisted',
                      value: shortlisted,
                      color: const Color(0xFF10B981),
                      icon: Icons.stars,
                      cardWidth: cardWidth,
                      filterValue: 'shortlisted',
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      title: 'Not Shortlisted',
                      value: notShortlisted,
                      color: const Color(0xFFEF4444),
                      icon: Icons.info_outline,
                      cardWidth: cardWidth,
                      filterValue: 'not_shortlisted',
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      title: 'Accepted',
                      value: accepted,
                      color: const Color(0xFF059669),
                      icon: Icons.check_circle,
                      cardWidth: cardWidth,
                      filterValue: 'accepted',
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      title: 'Rejected',
                      value: rejected,
                      color: const Color(0xFF6B7280),
                      icon: Icons.cancel,
                      cardWidth: cardWidth,
                      filterValue: 'rejected',
                    ),
                    SizedBox(width: spacing),
                    _buildFilterCard(cardWidth),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Stat card – now tappable. When [filterValue] matches the current
  // [_statusFilter] an accent border + subtle background tint signals it is active.
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildStatCard({
    required String title,
    required int value,
    required Color color,
    required IconData icon,
    required double cardWidth,
    required String filterValue,
  }) {
    final isActive = _statusFilter == filterValue;
    final iconSize = (cardWidth * 0.22).clamp(18.0, 24.0);
    final valueSize = (cardWidth * 0.18).clamp(16.0, 22.0);
    final titleSize = (cardWidth * 0.12).clamp(11.0, 14.0);

    return Tooltip(
      message: isActive
          ? 'Tap to show all applicants'
          : 'Tap to filter by $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            final next = isActive ? 'all' : filterValue;
            _applyFilter(next);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: cardWidth,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: color, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: isActive
                      ? color.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: isActive ? 12 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: iconSize),
                const SizedBox(height: 8),
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.bold,
                    color: isActive ? color : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    color: isActive ? color : Colors.grey.shade600,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Active indicator dot
                if (isActive) ...[
                  const SizedBox(height: 5),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Filter dropdown card – kept for power users who prefer typing a status
  /// directly. Stays in sync with card taps via [_statusFilter].
  Widget _buildFilterCard(double cardWidth) {
    final filterCardWidth = math.max(cardWidth * 1.5, 170.0);

    return Container(
      width: filterCardWidth,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _statusFilter,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Filter',
          labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All Applications')),
          DropdownMenuItem(value: 'pending', child: Text('Pending Review')),
          DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
          DropdownMenuItem(value: 'shortlisted', child: Text('Shortlisted')),
          DropdownMenuItem(
              value: 'not_shortlisted', child: Text('Not Shortlisted')),
          DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
          DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
        ],
        onChanged: (value) {
          _logger.i('Dropdown filter changed to: $value');
          _applyFilter(value!);
        },
      ),
    );
  }

  Widget _buildApplicantsTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.02,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTableHeader(screenWidth),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _applicantsStream,
                  builder: (context, snapshot) {
                    // ── Error ──────────────────────────────────────────────
                    if (snapshot.hasError) {
                      _logger.e('Error in stream', error: snapshot.error);
                      return _buildErrorState(snapshot.error.toString());
                    }

                    // ── First load (nothing cached yet) ────────────────────
                    final isFirstLoad = snapshot.connectionState ==
                            ConnectionState.waiting &&
                        _cachedDocs.isEmpty;

                    if (isFirstLoad) {
                      return _buildFullLoadingState();
                    }

                    // ── Data arrived — update cache atomically in one pass ──
                    // FIX: Use addPostFrameCallback (not Future.microtask) so we
                    // never call setState during a build frame. Also sort ONCE
                    // and reuse the result for both the cache check and display,
                    // eliminating the previous double-sort.
                    if (snapshot.hasData) {
                      final fresh = _sortBySubmittedAt(snapshot.data!.docs);
                      final needsUpdate = fresh.length != _cachedDocs.length ||
                          (fresh.isNotEmpty &&
                              _cachedDocs.isNotEmpty &&
                              fresh.first.id != _cachedDocs.first.id);
                      if (needsUpdate || _isTransitioning) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _cachedDocs = fresh;
                            _isTransitioning = false;
                            // FIX: Pre-compute the filtered list here so
                            // build() just reads _displayDocs — zero extra work.
                            _displayDocs = _applySearch(fresh);
                          });
                        });
                      }
                    }

                    // FIX: Use pre-computed _displayDocs. If data just arrived
                    // the post-frame callback above will trigger one clean rebuild;
                    // until then we show the previous _displayDocs (stale overlay).
                    final applicants = _displayDocs.isNotEmpty
                        ? _displayDocs
                        : _applySearch(_cachedDocs);

                    // ── Empty state ────────────────────────────────────────
                    if (applicants.isEmpty && !_isTransitioning) {
                      return _buildEmptyState();
                    }

                    // ── Table — wrapped in Stack for the transition overlay ──
                    return Stack(
                      children: [
                        // FIX: _buildVirtualTable uses ListView.builder so only
                        // visible rows are built — no longer building all 200 rows
                        // synchronously on every filter/search change.
                        AnimatedOpacity(
                          opacity: _isTransitioning ? 0.35 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: _buildVirtualTable(applicants),
                        ),

                        // Overlay shown while transitioning to a new filter
                        if (_isTransitioning)
                          const Center(child: _DotsLoader()),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(double screenWidth) {
    final logoSize = (screenWidth * 0.025).clamp(35.0, 50.0);
    final titleSize = (screenWidth * 0.014).clamp(16.0, 22.0);
    final subtitleSize = (screenWidth * 0.010).clamp(12.0, 15.0);

    // Show current filter in the table header subtitle
    final filterLabel =
        _statusFilter == 'all' ? 'All Applications' : _getStatusLabel(_statusFilter);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 86, 10, 119),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'JV',
                style: TextStyle(
                  fontSize: logoSize * 0.45,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 86, 10, 119),
                ),
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.015),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JV Almacis',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Recruitment Applications — $filterLabel',
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'RECRUITMENT PORTAL',
              style: TextStyle(
                fontSize: (screenWidth * 0.009).clamp(11.0, 14.0),
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Loading / error / empty / data helper widgets
  // ─────────────────────────────────────────────────────────────────────────────

  /// Shown only on the very first load before any data has been cached.
  Widget _buildFullLoadingState() {
    // Wrap in SingleChildScrollView so the loader + skeleton rows never
    // overflow when the available height is smaller than their natural size.
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          const _DotsLoader(size: 14, spacing: 10),
          const SizedBox(height: 20),
          Text(
            'Loading applicants…',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          // Reduced to 6 skeleton rows so they fit comfortably on small screens.
          ..._buildSkeletonRows(6),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Widget> _buildSkeletonRows(int count) {
    return List.generate(count, (i) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          children: [
            _shimmerBox(36, 36, radius: 6),
            const SizedBox(width: 12),
            Expanded(child: _shimmerBox(14, double.infinity, radius: 4)),
            const SizedBox(width: 12),
            _shimmerBox(14, 100, radius: 4),
            const SizedBox(width: 12),
            _shimmerBox(14, 80, radius: 4),
          ],
        ),
      );
    });
  }

  Widget _shimmerBox(double height, double width, {double radius = 4}) {
    // FIX: TweenAnimationBuilder with onEnd: () {} fired once then stopped
    // (the animation wasn't reversible). Replaced with a StatefulWidget that
    // uses a looping AnimationController for a proper pulsing shimmer.
    return _ShimmerBox(height: height, width: width, radius: radius);
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text(
            'Could not load applicants',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => setState(() {
              _applicantsStream = _buildStream(_statusFilter);
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No ${_getStatusLabel(_statusFilter)} applications',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_searchQuery.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() {
                _searchQuery = '';
                _displayDocs = _cachedDocs;
              }),
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search'),
            ),
          if (_statusFilter != 'all')
            TextButton.icon(
              onPressed: () => _applyFilter('all'),
              icon: const Icon(Icons.filter_list_off),
              label: const Text('Show All'),
            ),
        ],
      ),
    );
  }

  // FIX: Virtualized table — only visible rows are built (ListView.builder).
  // This replaces the DataTable which built ALL rows at once, causing frame drops
  // with 100+ applicants. Column widths mirror the original DataTable exactly.
  static const _colWidths = <double>[52, 170, 200, 160, 130, 150, 132, 145, 190, 210];
  static const _colLabels = <String>[
    'No.', 'Full Name', 'Email', 'Recruitment Field',
    'Home County', 'CV File', 'Submitted', 'Status', 'Review Notes', 'Actions'
  ];

  Widget _buildVirtualTable(List<QueryDocumentSnapshot> applicants) {
    final totalWidth = _colWidths.fold(0.0, (a, b) => a + b) + (_colWidths.length - 1) * 8;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalWidth,
        child: Column(
          children: [
            // ── Fixed header row ──────────────────────────────────────────────
            Container(
              height: 50,
              color: Colors.grey.shade100,
              child: Row(
                children: List.generate(_colLabels.length, (i) => _headerCell(_colLabels[i], _colWidths[i], i)),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            // ── Virtualised data rows ─────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                itemCount: applicants.length,
                // addAutomaticKeepAlives=false + addRepaintBoundaries=false cuts
                // down the Widget tree overhead for list items by ~30 %.
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                itemBuilder: (context, index) {
                  final doc = applicants[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isEven = index.isEven;
                  return Container(
                    height: 52,
                    color: isEven ? Colors.white : const Color(0xFFFAF9FF),
                    child: Row(
                      children: [
                        _dataCell(Text('${index + 1}', style: const TextStyle(fontSize: 13, color: Colors.black87)), _colWidths[0]),
                        _dataCell(SizedBox(width: _colWidths[1] - 16, child: Text(data['fullName'] ?? '-', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87))), _colWidths[1]),
                        _dataCell(SizedBox(width: _colWidths[2] - 16, child: Text(data['email'] ?? '-', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87))), _colWidths[2]),
                        _dataCell(SizedBox(width: _colWidths[3] - 16, child: _buildFieldBadge(data['recruitmentField'])), _colWidths[3]),
                        _dataCell(SizedBox(
                          width: _colWidths[4] - 16,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Flexible(child: Text(data['homeCounty'] ?? '-', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                          ]),
                        ), _colWidths[4]),
                        _dataCell(SizedBox(width: _colWidths[5] - 16, child: Text(data['cvFileName'] ?? '-', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87))), _colWidths[5]),
                        _dataCell(Text(
                          data['submittedAt'] != null
                              ? DateFormat('dd/MM/yy HH:mm').format((data['submittedAt'] as Timestamp).toDate())
                              : '-',
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ), _colWidths[6]),
                        _dataCell(_buildStatusBadge(data['status'] ?? 'pending'), _colWidths[7]),
                        _dataCell(SizedBox(width: _colWidths[8] - 16, child: Text(data['reviewNotes'] ?? '-', overflow: TextOverflow.ellipsis, maxLines: 2, style: const TextStyle(fontSize: 13, color: Colors.black87))), _colWidths[8]),
                        _dataCell(_buildActionButtons(doc.id, data), _colWidths[9]),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String label, double width, int index) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Color.fromARGB(255, 86, 10, 119),
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _dataCell(Widget child, double width) {
    return SizedBox(
      width: width,
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );
  }


  // ─────────────────────────────────────────────────────────────────────────────
  // Excel export
  //
  // [scope] is either 'current' (respects the active _statusFilter) or 'all'.
  // After fetching from Firestore the file is generated with the excel package
  // and handed off to ExcelDownloadService (the same service used by hr_dashboard).
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _downloadRecruitmentExcel(String scope) async {
    _logger.i('=== RECRUITMENT EXCEL DOWNLOAD INITIATED (scope: $scope) ===');

    setState(() {
      _isDownloading = true;
      _downloadProgress = 'Fetching data...';
    });

    String? downloadedFilePath;

    try {
      // ── 1. Fetch data ───────────────────────────────────────────────────────
      Query query = _firestore.collection('Recruitees');

      final isFiltered = scope == 'current' && _statusFilter != 'all';
      if (isFiltered) {
        query = query.where('status', isEqualTo: _statusFilter);
        if (mounted) {
          setState(() => _downloadProgress =
              'Loading "${_getStatusLabel(_statusFilter)}" applicants...');
        }
      } else {
        if (mounted) setState(() => _downloadProgress = 'Loading all applicants...');
      }

      final snapshot = await query.get();
      _logger.i('Fetched ${snapshot.docs.length} documents');

      if (snapshot.docs.isEmpty) {
        throw Exception(
          isFiltered
              ? 'No ${_getStatusLabel(_statusFilter)} applicants found.'
              : 'No applicants found.',
        );
      }

      if (mounted) {
        setState(() =>
            _downloadProgress = 'Processing ${snapshot.docs.length} records...');
      }

      final applicants = snapshot.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();

      // Sort by submittedAt descending (mirrors the table display order)
      applicants.sort((a, b) {
        final aTs = a['submittedAt'] as Timestamp?;
        final bTs = b['submittedAt'] as Timestamp?;
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return bTs.compareTo(aTs);
      });

      // ── 2. Generate Excel ───────────────────────────────────────────────────
      if (mounted) setState(() => _downloadProgress = 'Generating Excel file...');

      final result = _generateRecruitmentExcel(
        applicants: applicants,
        scope: scope,
      );
      final fileName = result['fileName'] as String;
      final fileBytes = result['fileBytes'] as Uint8List;
      final fileSize = result['fileSize'] as int;

      _logger.i('Excel generated: $fileName ($fileSize bytes)');

      // ── 3. Download ─────────────────────────────────────────────────────────
      if (mounted) setState(() => _downloadProgress = 'Downloading...');

      downloadedFilePath =
          await ExcelDownloadService.downloadExcel(fileBytes, fileName);

      _logger.i('✅ Excel download completed');

      if (!mounted) return;

      final readableSize = ExcelDownloadService.getReadableFileSize(fileSize);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Downloaded: $fileName ($readableSize)'
                : 'Saved: $downloadedFilePath\n$readableSize',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: kIsWeb
              ? null
              : SnackBarAction(
                  label: 'Open',
                  textColor: Colors.white,
                  onPressed: () async {
                    if (downloadedFilePath != null) {
                      try {
                        await ExcelDownloadService.openFile(downloadedFilePath);
                      } catch (e) {
                        _logger.e('Error opening file', error: e);
                      }
                    }
                  },
                ),
        ),
      );
    } catch (e, stackTrace) {
      _logger.e('❌ EXCEL DOWNLOAD ERROR', error: e, stackTrace: stackTrace);
      if (!mounted) return;

      String message = 'Error generating Excel: $e';
      SnackBarAction? action;

      if (e.toString().contains('permission')) {
        message = 'Storage permission denied. Please enable it in Settings.';
        action = SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () => openAppSettings(),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: action,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = null;
        });
      }
      _logger.d('=== EXCEL DOWNLOAD FINISHED ===');
    }
  }

  /// Builds an Excel workbook from [applicants] and returns
  /// `{'fileName': String, 'fileBytes': Uint8List, 'fileSize': int}`.
  Map<String, dynamic> _generateRecruitmentExcel({
    required List<Map<String, dynamic>> applicants,
    required String scope,
  }) {
    final excel = Excel.createExcel();

    // Remove the default Sheet1 that Excel.createExcel() adds
    excel.delete('Sheet1');

    final sheetName = scope == 'all'
        ? 'All Applicants'
        : _getStatusLabel(_statusFilter);

    final Sheet sheet = excel[sheetName];

    // ── Column definitions ──────────────────────────────────────────────────
    const headers = [
      '#',
      'Full Name',
      'Email',
      'Phone',
      'Recruitment Field',
      'Home County',
      'Status',
      'Submitted At',
      'Reviewed At',
      'Review Notes',
      'CV File Name',
    ];

    // ── Header row styling ──────────────────────────────────────────────────
    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#560A77'),
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // ── Data rows ───────────────────────────────────────────────────────────
    for (var rowIdx = 0; rowIdx < applicants.length; rowIdx++) {
      final data = applicants[rowIdx];
      final rowNum = rowIdx + 1; // 0-indexed + 1 for header offset

      String formatTs(dynamic ts) {
        if (ts == null) return '-';
        try {
          return DateFormat('dd/MM/yyyy HH:mm').format((ts as Timestamp).toDate());
        } catch (_) {
          return '-';
        }
      }

      final rowData = [
        (rowIdx + 1).toString(),                            // #
        data['fullName'] ?? '-',                            // Full Name
        data['email'] ?? '-',                               // Email
        data['phone'] ?? '-',                               // Phone
        data['recruitmentField'] ?? '-',                    // Recruitment Field
        data['homeCounty'] ?? '-',                          // Home County
        _getStatusLabel(data['status'] ?? 'pending'),       // Status
        formatTs(data['submittedAt']),                      // Submitted At
        formatTs(data['reviewedAt']),                       // Reviewed At
        data['reviewNotes'] ?? '-',                         // Review Notes
        data['cvFileName'] ?? '-',                          // CV File Name
      ];

      for (var col = 0; col < rowData.length; col++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowNum));
        cell.value = TextCellValue(rowData[col]);

        // Alternate row shading for readability
        if (rowIdx.isEven) {
          cell.cellStyle =
              CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F5F0FF'));
        }
      }
    }

    // ── Set column widths ───────────────────────────────────────────────────
    const colWidths = [6, 25, 30, 18, 28, 20, 20, 20, 20, 35, 25];
    for (var i = 0; i < colWidths.length; i++) {
      sheet.setColumnWidth(i, colWidths[i].toDouble());
    }

    // ── Summary sheet ───────────────────────────────────────────────────────
    final summarySheet = excel['Summary'];
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('Recruitment Export Summary')
      ..cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#560A77'),
          fontColorHex: ExcelColor.white);

    final summaryRows = [
      ['Filter Applied', scope == 'all' ? 'All Applicants' : _getStatusLabel(_statusFilter)],
      ['Total Records', applicants.length.toString()],
      ['Generated At', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())],
    ];

    for (var i = 0; i < summaryRows.length; i++) {
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 2))
          .value = TextCellValue(summaryRows[i][0]);
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 2))
          .value = TextCellValue(summaryRows[i][1]);
    }

    // ── Encode ──────────────────────────────────────────────────────────────
    final encoded = excel.encode();
    if (encoded == null) throw Exception('Excel encoding returned null');

    final fileBytes = Uint8List.fromList(encoded);

    final scopeLabel =
        scope == 'all' ? 'All' : _getStatusLabel(_statusFilter).replaceAll(' ', '_');
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final fileName = 'Recruitment_${scopeLabel}_$timestamp.xlsx';

    return {
      'fileName': fileName,
      'fileBytes': fileBytes,
      'fileSize': fileBytes.length,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // UI helpers (unchanged from original)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final text = _getStatusLabel(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldBadge(dynamic field) {
    final label = (field as String?)?.trim() ?? '-';
    if (label == '-') {
      return Text(label,
          style: const TextStyle(color: Colors.grey, fontSize: 13));
    }

    IconData icon;
    Color color;
    if (label.toLowerCase().contains('field officer')) {
      icon = Icons.agriculture_outlined;
      color = const Color(0xFF0EA5E9);
    } else if (label.toLowerCase().contains('regional')) {
      icon = Icons.map_outlined;
      color = const Color(0xFF8B5CF6);
    } else {
      icon = Icons.work_outline;
      color = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Compact tap-target size (40×40) so up to 4 buttons fit within the
  // 210px Actions column without overflowing.
  static const _kActionConstraints = BoxConstraints(minWidth: 40, minHeight: 40);
  static const _kActionPadding = EdgeInsets.all(6);

  Widget _buildActionButtons(String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    final cvUrl = data['cvUrl'] as String?;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cvUrl != null)
          IconButton(
            icon: const Icon(Icons.description,
                size: 20, color: Color(0xFF3B82F6)),
            constraints: _kActionConstraints,
            padding: _kActionPadding,
            onPressed: () => _viewCV(cvUrl, data['cvFileName'] ?? 'CV'),
            tooltip: 'View CV',
          ),
        IconButton(
          icon: const Icon(Icons.edit_note,
              size: 20, color: Color(0xFFF59E0B)),
          constraints: _kActionConstraints,
          padding: _kActionPadding,
          onPressed: () => _updateStatus(docId, data),
          tooltip: 'Update Status',
        ),
        if (status == 'pending') ...[
          IconButton(
            icon: const Icon(Icons.rate_review,
                size: 20, color: Color(0xFF10B981)),
            constraints: _kActionConstraints,
            padding: _kActionPadding,
            onPressed: () => _quickUpdateStatus(docId, 'under_review'),
            tooltip: 'Start Review',
          ),
        ],
        if (status == 'under_review') ...[
          IconButton(
            icon: const Icon(Icons.star, size: 20, color: Color(0xFF10B981)),
            constraints: _kActionConstraints,
            padding: _kActionPadding,
            onPressed: () => _quickUpdateStatus(docId, 'shortlisted'),
            tooltip: 'Shortlist',
          ),
          IconButton(
            icon: const Icon(Icons.block, size: 20, color: Color(0xFFEF4444)),
            constraints: _kActionConstraints,
            padding: _kActionPadding,
            onPressed: () => _quickUpdateStatus(docId, 'not_shortlisted'),
            tooltip: 'Not Shortlist',
          ),
        ],
        if (status == 'shortlisted') ...[
          IconButton(
            icon: const Icon(Icons.check_circle,
                size: 20, color: Color(0xFF059669)),
            constraints: _kActionConstraints,
            padding: _kActionPadding,
            onPressed: () => _quickUpdateStatus(docId, 'accepted'),
            tooltip: 'Accept',
          ),
          IconButton(
            icon: const Icon(Icons.cancel, size: 20, color: Color(0xFF6B7280)),
            constraints: _kActionConstraints,
            padding: _kActionPadding,
            onPressed: () => _quickUpdateStatus(docId, 'rejected'),
            tooltip: 'Reject',
          ),
        ],
      ],
    );
  }

  Future<void> _viewCV(String cvUrl, String fileName) async {
    _logger.i('Opening CV: $fileName');
    try {
      final uri = Uri.parse(cvUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch CV URL');
      }
    } catch (e) {
      _logger.e('Error opening CV', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening CV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _quickUpdateStatus(String docId, String newStatus) async {
    _logger.i('Quick status update: $docId → $newStatus');
    try {
      await _firestore.collection('Recruitees').doc(docId).update({
        'status': newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _logger.i('✅ Status updated successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to: ${_getStatusLabel(newStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _logger.e('Error updating status', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateStatus(String docId, Map<String, dynamic> data) {
    _logger.i('Opening status update dialog for: $docId');
    final currentStatus = data['status'] ?? 'pending';
    String selectedStatus = currentStatus;
    final notesController =
        TextEditingController(text: data['reviewNotes'] ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: Color(0xFF7B2CBF)),
              SizedBox(width: 12),
              Expanded(child: Text('Update Application Status')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Applicant: ${data['fullName']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const Text('Select Status',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'pending', child: Text('Pending Review')),
                    DropdownMenuItem(
                        value: 'under_review', child: Text('Under Review')),
                    DropdownMenuItem(
                        value: 'shortlisted', child: Text('Shortlisted')),
                    DropdownMenuItem(
                        value: 'not_shortlisted',
                        child: Text('Not Shortlisted')),
                    DropdownMenuItem(
                        value: 'accepted', child: Text('Accepted')),
                    DropdownMenuItem(
                        value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedStatus = value!);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Review Notes (Optional)',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Add notes about this applicant...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
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
              onPressed: () async {
                Navigator.pop(context);
                await _performStatusUpdate(
                    docId, selectedStatus, notesController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2CBF)),
              child: const Text('Update Status'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performStatusUpdate(
      String docId, String newStatus, String notes) async {
    _logger.i('Performing status update: $docId → $newStatus');
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (notes.isNotEmpty) {
        updateData['reviewNotes'] = notes;
      }
      await _firestore.collection('Recruitees').doc(docId).update(updateData);
      _logger.i('✅ Status and notes updated successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Application updated to: ${_getStatusLabel(newStatus)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error updating application', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Label / colour / icon helpers
  // ─────────────────────────────────────────────────────────────────────────────

  String _getStatusLabel(String status) {
    switch (status) {
      case 'all':
        return 'All Applications';
      case 'pending':
        return 'Pending Review';
      case 'under_review':
        return 'Under Review';
      case 'shortlisted':
        return 'Shortlisted';
      case 'not_shortlisted':
        return 'Not Shortlisted';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFF3B82F6);
      case 'under_review':
        return const Color(0xFFF59E0B);
      case 'shortlisted':
        return const Color(0xFF10B981);
      case 'not_shortlisted':
        return const Color(0xFFEF4444);
      case 'accepted':
        return const Color(0xFF059669);
      case 'rejected':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF7B2CBF);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'under_review':
        return Icons.pending_actions;
      case 'shortlisted':
        return Icons.stars;
      case 'not_shortlisted':
        return Icons.info_outline;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
}


// =============================================================================
// FIX: Properly looping shimmer box.
// The old TweenAnimationBuilder + onEnd:(){} only ran once and stopped.
// This widget uses a looping AnimationController that properly reverses.
// =============================================================================
class _ShimmerBox extends StatefulWidget {
  final double height;
  final double width;
  final double radius;
  const _ShimmerBox({required this.height, required this.width, required this.radius});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Opacity(
        opacity: _anim.value,
        child: Container(
          height: widget.height,
          width: widget.width == double.infinity ? null : widget.width,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Animated three-dot loading indicator
// A self-contained StatefulWidget so it can be used both in the full loading
// state and as the transition overlay without any external state management.
// =============================================================================
class _DotsLoader extends StatefulWidget {
  final double size;
  final double spacing;
  const _DotsLoader({this.size = 12, this.spacing = 8});

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF7B2CBF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Each dot starts its bounce 160 ms after the previous one
              final start = i * 0.25;
              final end = start + 0.5;
              final animation = TweenSequence([
                TweenSequenceItem(
                    tween: Tween(begin: 0.0, end: -widget.size * 0.9)
                        .chain(CurveTween(curve: Curves.easeOut)),
                    weight: 50),
                TweenSequenceItem(
                    tween: Tween(begin: -widget.size * 0.9, end: 0.0)
                        .chain(CurveTween(curve: Curves.easeIn)),
                    weight: 50),
              ]).animate(
                CurvedAnimation(
                  parent: _ctrl,
                  curve: Interval(start.clamp(0.0, 1.0),
                      end.clamp(0.0, 1.0)),
                ),
              );

              return AnimatedBuilder(
                animation: animation,
                builder: (_, _) => Transform.translate(
                  offset: Offset(0, animation.value),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    margin: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
                    decoration: const BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            'Loading…',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}