class TimetableEntry {
  String subject;
  String time;
  String teacher;
  // Room is removed

  TimetableEntry({
    required this.subject,
    required this.time,
    required this.teacher,
  });

  Map<String, dynamic> toMap() {
    return {'subject': subject, 'time': time, 'teacher': teacher};
  }

  factory TimetableEntry.fromMap(Map<String, dynamic> map) {
    return TimetableEntry(
      subject: map['subject'] ?? '',
      time: map['time'] ?? '',
      teacher: map['teacher'] ?? '',
    );
  }
}
