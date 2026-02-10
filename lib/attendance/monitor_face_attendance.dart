import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LiveFaceAttendanceMonitor extends StatefulWidget {
  final String classId;
  final String date;
  final String sessionType;

  const LiveFaceAttendanceMonitor({
    super.key,
    required this.classId,
    required this.date,
    required this.sessionType,
  });

  @override
  State<LiveFaceAttendanceMonitor> createState() =>
      _LiveFaceAttendanceMonitorState();
}

class _LiveFaceAttendanceMonitorState extends State<LiveFaceAttendanceMonitor> {
  // We keep the stream here so it doesn't reconnect every second
  late Stream<QuerySnapshot> _attendanceStream;
  final Color primaryBlue = const Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    // 1. Initialize stream ONCE.
    final String sessionId =
        "${widget.classId}_${widget.date}_${widget.sessionType}";

    _attendanceStream = FirebaseFirestore.instance
        .collection('attendance')
        .doc(sessionId)
        .collection('student')
        // Removed orderBy to prevent "Missing Index" or "Missing Field" errors
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final String sessionId =
        "${widget.classId}_${widget.date}_${widget.sessionType}";

    return StreamBuilder<QuerySnapshot>(
      stream: _attendanceStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        var docs = snapshot.data!.docs;

        // 2. Local Sort (Newest first) - Handles missing timestamps safely
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          Timestamp? tA = dataA['timestamp'] as Timestamp?;
          Timestamp? tB = dataB['timestamp'] as Timestamp?;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });

        int count = docs.length;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: Colors.blue.withOpacity(0.1)),
          ),
          child: ExpansionTile(
            shape: const Border(),
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            title: const Text(
              "Live Face Scans",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              "Real-time verification",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            children: [
              if (count == 0)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.face_retouching_off,
                        size: 40,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "No students verified yet.",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: docs.length,
                    separatorBuilder: (ctx, i) => Divider(
                      height: 1,
                      color: Colors.grey.withOpacity(0.1),
                      indent: 70,
                    ),
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;

                      // ✅ Use the new Stateful Widget here
                      return _StudentListTile(
                        docId: docs[index].id,
                        data: data,
                        sessionId: sessionId,
                        onRemove: _removeStudent,
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

  void _removeStudent(
    String sessionId,
    String docId,
    String name,
    BuildContext context,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Unmark Student?"),
        content: Text("Remove $name from this session?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('attendance')
                  .doc(sessionId)
                  .collection('student')
                  .doc(docId)
                  .delete();
            },
            child: const Text("Remove", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ✅ FIXED: Converted to StatefulWidget to fetch name only ONCE
// This prevents infinite reloading when the parent timer ticks.
class _StudentListTile extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String sessionId;
  final Function(String, String, String, BuildContext) onRemove;

  const _StudentListTile({
    required this.docId,
    required this.data,
    required this.sessionId,
    required this.onRemove,
  });

  @override
  State<_StudentListTile> createState() => _StudentListTileState();
}

class _StudentListTileState extends State<_StudentListTile> {
  String _displayName = "Loading...";
  bool _isLoadingName = true;

  @override
  void initState() {
    super.initState();
    _resolveName();
  }

  // ✅ Only fetch the name once when the row is created
  Future<void> _resolveName() async {
    // 1. Check if name is already in the attendance doc
    String? cachedName = widget.data['name'];
    if (cachedName != null && cachedName != 'Unknown') {
      if (mounted) {
        setState(() {
          _displayName = cachedName;
          _isLoadingName = false;
        });
      }
      return;
    }

    // 2. Fetch from student collection
    String admissionNo = widget.data['admissionNo'] ?? widget.docId;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('student')
          .where('admissionNo', isEqualTo: admissionNo)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final studentData = snap.docs.first.data();
        if (mounted) {
          setState(() {
            _displayName = studentData['name'] ?? "Unknown ($admissionNo)";
            _isLoadingName = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _displayName = "Unknown ($admissionNo)";
            _isLoadingName = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _displayName = "Error ($admissionNo)";
          _isLoadingName = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String admissionNo = widget.data['admissionNo'] ?? widget.docId;

    // Format timestamp
    String timeStr = "--:--";
    if (widget.data['timestamp'] != null &&
        widget.data['timestamp'] is Timestamp) {
      DateTime dt = (widget.data['timestamp'] as Timestamp).toDate();
      timeStr =
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Colors.grey[100],
        child: const Icon(Icons.person, color: Colors.blueGrey, size: 20),
      ),
      title: _isLoadingName
          ? const SizedBox(
              height: 14,
              width: 100,
              child: LinearProgressIndicator(minHeight: 2),
            ) // Show mini loader while fetching name
          : Text(
              _displayName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
      subtitle: Text(
        "$admissionNo • $timeStr",
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
        tooltip: "Unmark Student",
        onPressed: () => widget.onRemove(
          widget.sessionId,
          widget.docId,
          _displayName,
          context,
        ),
      ),
    );
  }
}
