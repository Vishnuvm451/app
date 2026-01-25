import 'package:darzo/time_table_entry.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditableTimetablePage extends StatefulWidget {
  final String timetableId;
  final String title;
  final bool isAdmin;

  const EditableTimetablePage({
    super.key,
    required this.timetableId,
    required this.title,
    required this.isAdmin,
  });

  @override
  State<EditableTimetablePage> createState() => _EditableTimetablePageState();
}

class _EditableTimetablePageState extends State<EditableTimetablePage>
    with SingleTickerProviderStateMixin {
  final Color primaryBlue = const Color(0xFF2196F3);
  final List<String> days = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];

  late TabController _tabController;
  Map<String, List<TimetableEntry>> weeklySchedule = {};
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: days.length, vsync: this);
    for (var day in days) weeklySchedule[day] = [];
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('timetables')
          .doc(widget.timetableId)
          .get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          for (var day in days) {
            if (data.containsKey(day)) {
              List rawList = data[day];
              weeklySchedule[day] = rawList
                  .map((e) => TimetableEntry.fromMap(e))
                  .toList();
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveTimetable() async {
    setState(() => isSaving = true);
    try {
      Map<String, dynamic> firestoreData = {};
      weeklySchedule.forEach((day, entries) {
        _sortEntries(entries);
        firestoreData[day] = entries.map((e) => e.toMap()).toList();
      });

      firestoreData['lastUpdatedBy'] = widget.isAdmin ? 'Admin' : 'Teacher';
      firestoreData['updatedAt'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance
          .collection('timetables')
          .doc(widget.timetableId)
          .set(firestoreData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Timetable Saved Successfully!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to save"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isSaving = false);
    }
  }

  // Sorting Logic (AM/PM Aware)
  double _parseStartTime(String timeString) {
    try {
      String startTimeStr = timeString.split('-')[0].trim();
      startTimeStr = startTimeStr.replaceAll(':', '.');
      String numericPart = startTimeStr.replaceAll(RegExp(r'[^\d.]'), '');
      if (numericPart.isEmpty) return 99.0;

      double time = double.parse(numericPart);

      // 1.00 to 6.59 -> Assume PM (Add 12)
      if (time >= 1.0 && time < 7.0) {
        time += 12.0;
      }
      return time;
    } catch (e) {
      return 99.99;
    }
  }

  void _sortEntries(List<TimetableEntry> entries) {
    entries.sort(
      (a, b) => _parseStartTime(a.time).compareTo(_parseStartTime(b.time)),
    );
  }

  void _showEntryDialog(String day, {int? index}) {
    final bool isEditing = index != null;
    final entry = isEditing
        ? weeklySchedule[day]![index]
        : TimetableEntry(subject: '', time: '', teacher: '');

    final subjectCtrl = TextEditingController(text: entry.subject);
    final timeCtrl = TextEditingController(text: entry.time);
    final teacherCtrl = TextEditingController(text: entry.teacher);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? "Edit Class" : "Add Class",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildDialogField(subjectCtrl, "Subject", Icons.book),
              const SizedBox(height: 12),
              _buildDialogField(
                timeCtrl,
                "Time (e.g. 1.30 - 2.30)",
                Icons.access_time,
              ),
              const SizedBox(height: 12),
              _buildDialogField(teacherCtrl, "Tutor Name", Icons.person),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          final newEntry = TimetableEntry(
                            subject: subjectCtrl.text,
                            time: timeCtrl.text,
                            teacher: teacherCtrl.text,
                          );
                          if (isEditing) {
                            weeklySchedule[day]![index] = newEntry;
                          } else {
                            weeklySchedule[day]!.add(newEntry);
                          }
                          _sortEntries(weeklySchedule[day]!);
                        });
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isEditing
                                  ? "Class Updated!"
                                  : "Class Added Successfully!",
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      child: const Text("Save"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryBlue, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Timetable Editor",
              style: TextStyle(
                fontSize: 20,
                color: Color.fromARGB(240, 255, 255, 255),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: primaryBlue,
        elevation: 0,
        actions: const [],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: days.map((d) => Tab(text: d.substring(0, 3))).toList(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: days.map((day) => _buildDayView(day)).toList(),
            ),
    );
  }

  Widget _buildDayView(String day) {
    final entries = weeklySchedule[day]!;
    _sortEntries(entries);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(
                    "No classes on $day",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
              itemCount: entries.length,
              itemBuilder: (ctx, i) => _buildClassCard(entries[i], day, i),
            ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20, right: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: "add_$day",
              onPressed: () => _showEntryDialog(day),
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                "Add Class",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 16),

            FloatingActionButton.extended(
              heroTag: "save_$day",
              onPressed: _saveTimetable,
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              icon: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                isSaving ? "Saving..." : "Save Timetable",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassCard(TimetableEntry entry, String day, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEntryDialog(day, index: index),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 18,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.time.split('-')[0].trim(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.subject,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.teacher.isEmpty ? "No Tutor" : entry.teacher,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.time,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ✅ DELETE BUTTON
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () {
                    setState(() => weeklySchedule[day]!.removeAt(index));

                    // ✅ SNACKBAR FOR DELETE
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Class Deleted"),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
