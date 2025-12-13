import 'package:flutter/material.dart';

class StudentInternalMarksPage extends StatelessWidget {
  const StudentInternalMarksPage({super.key});

  // --------------------------------------------------
  // TEMP MOCK DATA (Replace with Firestore)
  // --------------------------------------------------
  final List<Map<String, dynamic>> internals = const [
    {
      "subject": "Operating Systems",
      "internal1": 18,
      "internal2": 20,
      "assignment": 9,
      "total": 47,
    },
    {
      "subject": "Computer Networks",
      "internal1": 15,
      "internal2": 17,
      "assignment": 8,
      "total": 40,
    },
    {
      "subject": "Software Engineering",
      "internal1": 19,
      "internal2": 18,
      "assignment": 10,
      "total": 47,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text("My Internal Marks"),
        ),
        backgroundColor: Colors.blue.shade800,
      ),
      body: internals.isEmpty
          ? const Center(
              child: Text(
                "Internal marks not published yet",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: internals.length,
              itemBuilder: (context, index) {
                final item = internals[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ================= SUBJECT =================
                        Text(
                          item["subject"],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ================= MARKS ROW =================
                        _markRow("Internal 1", item["internal1"]),
                        _markRow("Internal 2", item["internal2"]),
                        _markRow("Assignment", item["assignment"]),

                        const Divider(height: 20),

                        // ================= TOTAL =================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Total",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              item["total"].toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // --------------------------------------------------
  // REUSABLE MARK ROW
  // --------------------------------------------------
  Widget _markRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
