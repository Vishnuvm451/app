import 'package:darzo/time_table_entry.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentTimetablePage extends StatefulWidget {
  final String classId; // e.g. "BCOM_UG_YEAR3"
  final String currentSemester; // e.g. "Semester 5" (from profile)

  const StudentTimetablePage({
    super.key,
    required this.classId,
    required this.currentSemester,
  });

  @override
  State<StudentTimetablePage> createState() => _StudentTimetablePageState();
}

class _StudentTimetablePageState extends State<StudentTimetablePage> {
  final Color primaryBlue = const Color(0xFF2196F3);
  final List<String> days = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];

  // State
  late String selectedSemester;
  List<String> availableSemesters = [];
  int currentDayIndex = 0;

  Map<String, List<TimetableEntry>> weeklySchedule = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initSemesterLogic();
    _setToday();
    _fetchTimetable();
  }

  // 1. Logic to determine valid semesters based on Class Name/ID
  void _initSemesterLogic() {
    final String id = widget.classId.toUpperCase();

    // Logic: Per Year 2 Semesters
    if (id.contains("YEAR1") || id.contains("YEAR_1")) {
      availableSemesters = ["Semester 1", "Semester 2"];
    } else if (id.contains("YEAR2") || id.contains("YEAR_2")) {
      availableSemesters = ["Semester 3", "Semester 4"];
    } else if (id.contains("YEAR3") || id.contains("YEAR_3")) {
      availableSemesters = ["Semester 5", "Semester 6"];
    } else if (id.contains("YEAR4") || id.contains("YEAR_4")) {
      availableSemesters = ["Semester 7", "Semester 8"];
    } else {
      // Fallback: Show all 8 if pattern not matched
      availableSemesters = List.generate(8, (i) => "Semester ${i + 1}");
    }

    // Smart Default: If profile semester is invalid for this year, pick the first valid one
    if (availableSemesters.contains(widget.currentSemester)) {
      selectedSemester = widget.currentSemester;
    } else {
      selectedSemester = availableSemesters.first;
    }
  }

  void _setToday() {
    int weekday = DateTime.now().weekday;
    if (weekday > 6) {
      currentDayIndex = 0; // Sunday -> Monday
    } else {
      currentDayIndex = weekday - 1;
    }
  }

  // 2. Fetch Data using Composite ID
  Future<void> _fetchTimetable() async {
    setState(() => isLoading = true);

    // Generate ID: CLASS_SEM (e.g. "BCOM_UG_YEAR3_SEMESTER5")
    final String semFormatted = selectedSemester
        .replaceAll(' ', '')
        .toUpperCase();
    final String timetableId = "${widget.classId}_$semFormatted"
        .toUpperCase()
        .replaceAll(' ', '');

    print("Fetching Timetable: $timetableId");

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('timetables')
          .doc(timetableId)
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
            } else {
              weeklySchedule[day] = [];
            }
          }
        });
      } else {
        // Clear data if no document found for this semester
        setState(() {
          for (var day in days) weeklySchedule[day] = [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching timetable: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Navigation Logic
  void _changeDay(int offset) {
    setState(() {
      int newIndex = currentDayIndex + offset;
      if (newIndex >= 0 && newIndex < days.length) {
        currentDayIndex = newIndex;
      }
    });
  }

  // Sorting Logic (AM/PM Aware)
  double _parseStartTime(String timeString) {
    try {
      String startTimeStr = timeString.split('-')[0].trim();
      startTimeStr = startTimeStr.replaceAll(':', '.');
      String numericPart = startTimeStr.replaceAll(RegExp(r'[^\d.]'), '');
      if (numericPart.isEmpty) return 99.0;
      double time = double.parse(numericPart);
      if (time >= 1.0 && time < 7.0) time += 12.0;
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

  @override
  Widget build(BuildContext context) {
    String selectedDay = days[currentDayIndex];
    List<TimetableEntry> todaysEntries = weeklySchedule[selectedDay] ?? [];
    _sortEntries(todaysEntries);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        centerTitle: true,
        // ✅ Semester Dropdown in AppBar
        title: Theme(
          data: Theme.of(context).copyWith(canvasColor: primaryBlue),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedSemester,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
              items: availableSemesters.map((String sem) {
                return DropdownMenuItem<String>(value: sem, child: Text(sem));
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() => selectedSemester = newValue);
                  _fetchTimetable(); // Reload data
                }
              },
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDateHeader(selectedDay),
                Expanded(
                  child: todaysEntries.isEmpty
                      ? _buildEmptyState(selectedDay)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: todaysEntries.length,
                          itemBuilder: (ctx, index) =>
                              _buildClassCard(todaysEntries[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDateHeader(String day) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              size: 20,
              color: currentDayIndex > 0 ? primaryBlue : Colors.grey.shade300,
            ),
            onPressed: currentDayIndex > 0 ? () => _changeDay(-1) : null,
          ),
          Text(
            day,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryBlue,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: currentDayIndex < days.length - 1
                  ? primaryBlue
                  : Colors.grey.shade300,
            ),
            onPressed: currentDayIndex < days.length - 1
                ? () => _changeDay(1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String day) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No classes on $day",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(TimetableEntry entry) {
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
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Icon(Icons.access_time, size: 18, color: Colors.blue),
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
                      const Icon(Icons.schedule, size: 14, color: Colors.grey),
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
          ],
        ),
      ),
    );
  }
}
