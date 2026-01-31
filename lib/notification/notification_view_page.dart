import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationViewPage extends StatefulWidget {
  const NotificationViewPage({super.key});

  @override
  State<NotificationViewPage> createState() => _NotificationViewPageState();
}

class _NotificationViewPageState extends State<NotificationViewPage> {
  // =====================================================
  // STATE VARIABLES
  // =====================================================
  String? userId;
  String? userClassId;
  String? userDeptId;
  bool isLoading = true;

  // Local Hiding Logic
  List<String> _hiddenAnnouncementIds = [];
  bool _isSelectMode = false;
  final Set<String> _selectedIds = {};

  // ✅ FIX: Dynamic key based on User ID
  String get _prefsKey => 'hidden_announcements_${userId ?? "guest"}';

  // ✅ FIX: Explicit timers for snackbar and undo
  Timer? _snackbarTimer;
  Timer? _undoTimer;

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Initialize in strict order
    _initPageData();
  }

  @override
  void dispose() {
    // ✅ FIX: Cancel all timers on dispose
    _snackbarTimer?.cancel();
    _undoTimer?.cancel();
    super.dispose();
  }

  // =====================================================
  // 1. INITIALIZATION
  // =====================================================
  Future<void> _initPageData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      setState(() => userId = user.uid);

      // 1. Load hidden IDs for THIS specific user
      await _loadHiddenIds();

      // 2. Load profile for filtering
      await _fetchUserProfile();
    } else {
      // Handle guest/logged out state
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ✅ FIX: Added try-catch
  Future<void> _loadHiddenIds() async {
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _hiddenAnnouncementIds = prefs.getStringList(_prefsKey) ?? [];
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading hidden IDs: $e');
    }
  }

  // ✅ FIX: Added try-catch
  Future<void> _fetchUserProfile() async {
    if (userId == null) return;
    try {
      final query = await FirebaseFirestore.instance
          .collection('student')
          .where('authUid', isEqualTo: userId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        if (mounted) {
          setState(() {
            userClassId = data['classId'];
            userDeptId = data['departmentId'];
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error fetching profile: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  // =====================================================
  // 2. HIDE LOGIC (PERSISTENT & USER SPECIFIC)
  // =====================================================
  Future<void> _hideAnnouncements(List<String> idsToHide) async {
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ FIX: Store original list for proper undo
      final originalHidden = List<String>.from(_hiddenAnnouncementIds);

      setState(() {
        _hiddenAnnouncementIds.addAll(idsToHide);
        _hiddenAnnouncementIds = _hiddenAnnouncementIds.toSet().toList();
      });

      // Save to device storage
      await prefs.setStringList(_prefsKey, _hiddenAnnouncementIds);

      if (_isSelectMode) {
        setState(() {
          _isSelectMode = false;
          _selectedIds.clear();
        });
      }

      if (mounted) {
        // ✅ FIX: Cancel any existing timers
        _snackbarTimer?.cancel();
        _undoTimer?.cancel();

        // ✅ FIX: Clear previous snackbars
        ScaffoldMessenger.of(context).clearSnackBars();

        debugPrint('📢 Dismissing ${idsToHide.length} announcement(s)');

        // ✅ FIX: Show snackbar with explicit timer
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              idsToHide.length == 1
                  ? 'Notification dismissed'
                  : '${idsToHide.length} notifications dismissed',
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                // ✅ FIX: Cancel undo timer
                _undoTimer?.cancel();

                debugPrint(
                  '↩️ Undo pressed - restoring ${idsToHide.length} announcement(s)',
                );

                try {
                  setState(() {
                    _hiddenAnnouncementIds = originalHidden;
                  });
                  await prefs.setStringList(_prefsKey, _hiddenAnnouncementIds);

                  if (mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification restored'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.all(16),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('❌ Undo error: $e');
                }
              },
            ),
          ),
        );

        // ✅ FIX: Timer to AUTO-HIDE snackbar after 4 seconds
        _snackbarTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            debugPrint('⏱️ Snackbar timer expired - hiding snackbar');
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        });

        // ✅ FIX: Timer for undo window (3 seconds)
        _undoTimer = Timer(const Duration(seconds: 3), () {
          debugPrint('⏱️ Undo window closed');
        });
      }
    } catch (e) {
      debugPrint('❌ Error hiding announcements: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );

        // ✅ FIX: Timer to hide error snackbar
        _snackbarTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        });
      }
    }
  }

  // =====================================================
  // UI BUILDER
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isSelectMode) {
          setState(() {
            _isSelectMode = false;
            _selectedIds.clear();
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black87),
          leading: _isSelectMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isSelectMode = false;
                      _selectedIds.clear();
                    });
                  },
                )
              : const BackButton(),
          title: Text(
            _isSelectMode ? '${_selectedIds.length} Selected' : 'Notices',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          actions: [
            if (_isSelectMode && _selectedIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _hideAnnouncements(_selectedIds.toList()),
              ),
          ],
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2196F3)),
              )
            : _buildAnnouncementsList(),
      ),
    );
  }

  // =====================================================
  // 3. ANNOUNCEMENTS LIST
  // =====================================================
  Widget _buildAnnouncementsList() {
    final DateTime thirtyDaysAgo = DateTime.now().subtract(
      const Duration(days: 30),
    );

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorState();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2196F3)),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // FILTERING LOGIC
        final relevantDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // 1. Check if hidden locally (User Specific)
          if (_hiddenAnnouncementIds.contains(doc.id)) return false;

          // 2. Check 30-day cutoff
          final Timestamp? timestamp = data['timestamp'];
          if (timestamp != null && timestamp.toDate().isBefore(thirtyDaysAgo)) {
            return false;
          }

          // 3. Target Filter
          final target = data['target'] ?? 'all';
          final targetValue = data['targetValue'];

          if (target == 'all') return true;
          if (target == 'class' && targetValue == userClassId) return true;
          if (target == 'dept' && targetValue == userDeptId) return true;

          return false;
        }).toList();

        if (relevantDocs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: relevantDocs.length,
          itemBuilder: (context, index) {
            final doc = relevantDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildDismissibleCard(doc.id, data);
          },
        );
      },
    );
  }

  // =====================================================
  // 4. DISMISSIBLE CARD
  // =====================================================
  Widget _buildDismissibleCard(String docId, Map<String, dynamic> data) {
    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) {
        _hideAnnouncements([docId]);
      },
      child: GestureDetector(
        onLongPress: () {
          setState(() {
            _isSelectMode = true;
            _selectedIds.add(docId);
          });
        },
        onTap: () {
          if (_isSelectMode) {
            setState(() {
              if (_selectedIds.contains(docId)) {
                _selectedIds.remove(docId);
                if (_selectedIds.isEmpty) _isSelectMode = false;
              } else {
                _selectedIds.add(docId);
              }
            });
          }
        },
        child: _buildAnnouncementCard(docId, data),
      ),
    );
  }

  // =====================================================
  // 5. CARD UI
  // =====================================================
  Widget _buildAnnouncementCard(String docId, Map<String, dynamic> data) {
    final String sender = (data['sender'] ?? 'Teacher').toString();
    final bool isAdmin = sender.toLowerCase() == 'admin';

    final String title = data['title'] ?? 'Notice';
    final String body = data['body'] ?? '';
    final Timestamp? timestamp = data['timestamp'];

    final bool isSelected = _selectedIds.contains(docId);

    final Color themeColor = isAdmin
        ? Colors.redAccent
        : const Color(0xFF2196F3);
    final Color bgColor = isAdmin ? Colors.red.shade50 : Colors.blue.shade50;
    final IconData roleIcon = isAdmin ? Icons.security : Icons.school;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: Colors.blue, width: 2)
            : Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          if (!isSelected)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.withOpacity(0.1) : bgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                if (_isSelectMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.blue : Colors.grey,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: themeColor.withOpacity(0.3)),
                  ),
                  child: Icon(roleIcon, size: 16, color: themeColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sender,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTimeAgo(timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // HELPERS
  // =====================================================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 50,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "No Notices",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "You're all caught up!",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 50, color: Colors.red),
          const SizedBox(height: 16),
          const Text("Could not fetch notices."),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
            child: const Text("Try Again"),
          ),
        ],
      ),
    );
  }

  // ✅ FIX: Added try-catch for timestamp formatting
  String _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = timestamp.toDate();
      final diff = DateTime.now().difference(dt);

      if (diff.inDays > 7) {
        return DateFormat('dd MMM').format(dt);
      } else if (diff.inDays >= 1) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours >= 1) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes >= 1) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      debugPrint('❌ Error formatting timestamp: $e');
      return '';
    }
  }
}
