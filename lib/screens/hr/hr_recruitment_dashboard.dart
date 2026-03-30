import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
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
    _logger.i('=== HR Recruitment Dashboard Initialized ===');
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
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _showSearchDialog,
            tooltip: 'Search Applicants',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _logger.i('Manual refresh triggered');
              setState(() {});
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
            setState(() => _searchQuery = value.trim().toLowerCase());
          },
          onSubmitted: (value) {
            setState(() => _searchQuery = value.trim().toLowerCase());
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _searchQuery = '');
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

  Widget _buildStatsCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('Recruitees').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        final total = docs.length;
        final pending = docs
            .where((d) => (d.data() as Map)['status'] == 'pending')
            .length;
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
            // clamp cardWidth so stat cards are always legible
            final cardWidth =
                (screenWidth * 0.15).clamp(90.0, double.infinity);
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
                    _buildStatCard('Total', total,
                        const Color(0xFF7B2CBF), Icons.people, cardWidth),
                    SizedBox(width: spacing),
                    _buildStatCard('Pending', pending,
                        const Color(0xFF3B82F6), Icons.hourglass_empty, cardWidth),
                    SizedBox(width: spacing),
                    _buildStatCard('Reviewing', underReview,
                        const Color(0xFFF59E0B), Icons.pending_actions, cardWidth),
                    SizedBox(width: spacing),
                    _buildStatCard('Shortlisted', shortlisted,
                        const Color(0xFF10B981), Icons.stars, cardWidth),
                    SizedBox(width: spacing),
                    _buildStatCard('Not Shortlisted', notShortlisted,
                        const Color(0xFFEF4444), Icons.info_outline, cardWidth),
                    SizedBox(width: spacing),
                    _buildStatCard('Accepted', accepted,
                        const Color(0xFF059669), Icons.check_circle, cardWidth),
                    SizedBox(width: spacing),
                    _buildStatCard('Rejected', rejected,
                        const Color(0xFF6B7280), Icons.cancel, cardWidth),
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

  Widget _buildStatCard(String title, int value, Color color, IconData icon,
      double cardWidth) {
    final iconSize = (cardWidth * 0.22).clamp(18.0, 24.0);
    final valueSize = (cardWidth * 0.18).clamp(16.0, 22.0);
    final titleSize = (cardWidth * 0.12).clamp(11.0, 14.0);

    return Container(
      width: cardWidth,
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
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: titleSize,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Filter card — uses isExpanded + a minimum width to prevent the
  /// DropdownButtonFormField from overflowing its container.
  Widget _buildFilterCard(double cardWidth) {
    // Ensure the filter card is always wide enough to show the longest item
    // ("All Applications") plus the dropdown arrow without overflowing.
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
        // ─── FIX: isExpanded lets the selected-value Row use all available
        // horizontal space, preventing the "overflowed by N pixels" error. ──
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Filter',
          labelStyle:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          border: OutlineInputBorder(),
          contentPadding:
              EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All Applications')),
          DropdownMenuItem(
              value: 'pending', child: Text('Pending Review')),
          DropdownMenuItem(
              value: 'under_review', child: Text('Under Review')),
          DropdownMenuItem(
              value: 'shortlisted', child: Text('Shortlisted')),
          DropdownMenuItem(
              value: 'not_shortlisted', child: Text('Not Shortlisted')),
          DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
          DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
        ],
        onChanged: (value) {
          _logger.i('Filter changed to: $value');
          setState(() => _statusFilter = value!);
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
                  stream: _getFilteredStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      _logger.e('Error in stream',
                          error: snapshot.error);
                      return Center(
                          child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final allApplicants = snapshot.data!.docs;
                    _logger.i(
                        'Loaded ${allApplicants.length} applicants');

                    // Apply search filter
                    final applicants = _searchQuery.isEmpty
                        ? allApplicants
                        : allApplicants.where((doc) {
                            final data =
                                doc.data() as Map<String, dynamic>;
                            final fullName = (data['fullName'] ?? '')
                                .toString()
                                .toLowerCase();
                            final email = (data['email'] ?? '')
                                .toString()
                                .toLowerCase();
                            return fullName.contains(_searchQuery) ||
                                email.contains(_searchQuery);
                          }).toList();

                    if (applicants.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.inbox,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No results found for "$_searchQuery"'
                                  : 'No applications found',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey),
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _searchQuery = ''),
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear Search'),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 50,
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 52,
                          headingRowColor: WidgetStateProperty.all(
                              Colors.grey.shade100),
                          columnSpacing: 20,
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color.fromARGB(255, 86, 10, 119),
                          ),
                          dataTextStyle: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          columns: const [
                            DataColumn(label: Text('No.')),
                            DataColumn(label: Text('Full Name')),
                            DataColumn(label: Text('Email')),
                            // ── New columns ──────────────────────────────
                            DataColumn(
                                label: Text('Recruitment Field')),
                            DataColumn(label: Text('Home County')),
                            // ────────────────────────────────────────────
                            DataColumn(label: Text('CV File')),
                            DataColumn(label: Text('Submitted')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Review Notes')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: applicants.asMap().entries.map((entry) {
                            final index = entry.key;
                            final doc = entry.value;
                            final data =
                                doc.data() as Map<String, dynamic>;

                            return DataRow(
                              cells: [
                                DataCell(Text('${index + 1}')),
                                DataCell(
                                  SizedBox(
                                    width: 160,
                                    child: Text(
                                      data['fullName'] ?? '-',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 190,
                                    child: Text(
                                      data['email'] ?? '-',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                // Recruitment Field cell
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: _buildFieldBadge(
                                        data['recruitmentField']),
                                  ),
                                ),
                                // Home County cell
                                DataCell(
                                  SizedBox(
                                    width: 120,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            data['homeCounty'] ?? '-',
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      data['cvFileName'] ?? '-',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    data['submittedAt'] != null
                                        ? DateFormat('dd/MM/yy HH:mm')
                                            .format(
                                            (data['submittedAt']
                                                    as Timestamp)
                                                .toDate(),
                                          )
                                        : '-',
                                  ),
                                ),
                                DataCell(_buildStatusBadge(
                                    data['status'] ?? 'pending')),
                                DataCell(
                                  SizedBox(
                                    width: 180,
                                    child: Text(
                                      data['reviewNotes'] ?? '-',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  _buildActionButtons(doc.id, data),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
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
                  'Recruitment Applications',
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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

  Stream<QuerySnapshot> _getFilteredStream() {
    Query query = _firestore
        .collection('Recruitees')
        .orderBy('submittedAt', descending: true);

    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    return query.snapshots();
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'pending':
        color = const Color(0xFF3B82F6);
        text = 'Pending';
        icon = Icons.hourglass_empty;
        break;
      case 'under_review':
        color = const Color(0xFFF59E0B);
        text = 'Under Review';
        icon = Icons.pending_actions;
        break;
      case 'shortlisted':
        color = const Color(0xFF10B981);
        text = 'Shortlisted';
        icon = Icons.stars;
        break;
      case 'not_shortlisted':
        color = const Color(0xFFEF4444);
        text = 'Not Shortlisted';
        icon = Icons.info_outline;
        break;
      case 'accepted':
        color = const Color(0xFF059669);
        text = 'Accepted';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = const Color(0xFF6B7280);
        text = 'Rejected';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
        icon = Icons.help_outline;
    }

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

  /// Badge for the Recruitment Field column.
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
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    final cvUrl = data['cvUrl'] as String?;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cvUrl != null)
          IconButton(
            icon: const Icon(Icons.description,
                size: 20, color: Color(0xFF3B82F6)),
            onPressed: () =>
                _viewCV(cvUrl, data['cvFileName'] ?? 'CV'),
            tooltip: 'View CV',
          ),
        IconButton(
          icon: const Icon(Icons.edit_note,
              size: 20, color: Color(0xFFF59E0B)),
          onPressed: () => _updateStatus(docId, data),
          tooltip: 'Update Status',
        ),
        if (status == 'pending') ...[
          IconButton(
            icon: const Icon(Icons.rate_review,
                size: 20, color: Color(0xFF10B981)),
            onPressed: () =>
                _quickUpdateStatus(docId, 'under_review'),
            tooltip: 'Start Review',
          ),
        ],
        if (status == 'under_review') ...[
          IconButton(
            icon: const Icon(Icons.star,
                size: 20, color: Color(0xFF10B981)),
            onPressed: () =>
                _quickUpdateStatus(docId, 'shortlisted'),
            tooltip: 'Shortlist',
          ),
          IconButton(
            icon: const Icon(Icons.block,
                size: 20, color: Color(0xFFEF4444)),
            onPressed: () =>
                _quickUpdateStatus(docId, 'not_shortlisted'),
            tooltip: 'Not Shortlist',
          ),
        ],
        if (status == 'shortlisted') ...[
          IconButton(
            icon: const Icon(Icons.check_circle,
                size: 20, color: Color(0xFF059669)),
            onPressed: () => _quickUpdateStatus(docId, 'accepted'),
            tooltip: 'Accept',
          ),
          IconButton(
            icon: const Icon(Icons.cancel,
                size: 20, color: Color(0xFF6B7280)),
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

  Future<void> _quickUpdateStatus(
      String docId, String newStatus) async {
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
            content: Text(
                'Status updated to: ${_getStatusLabel(newStatus)}'),
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
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  // isExpanded prevents overflow in the dialog too
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending Review')),
                    DropdownMenuItem(
                        value: 'under_review',
                        child: Text('Under Review')),
                    DropdownMenuItem(
                        value: 'shortlisted',
                        child: Text('Shortlisted')),
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
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
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
                await _performStatusUpdate(docId, selectedStatus,
                    notesController.text.trim());
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
      await _firestore
          .collection('Recruitees')
          .doc(docId)
          .update(updateData);
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

  String _getStatusLabel(String status) {
    switch (status) {
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
}