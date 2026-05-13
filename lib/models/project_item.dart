class ProjectItem {
  const ProjectItem({
    required this.id,
    required this.title,
    required this.typeLabel,
    this.subject,
    required this.completedTasks,
    required this.totalTasks,
    required this.teamCount,
    this.inviteCode,
    this.memberLabels = const <String>[],
  });

  final String id;
  final String title;
  final String typeLabel;
  final String? subject;
  final int completedTasks;
  final int totalTasks;
  final int teamCount;
  final String? inviteCode;
  final List<String> memberLabels;

  double get progress => totalTasks == 0 ? 0 : completedTasks / totalTasks;

  ProjectItem copyWith({
    String? id,
    String? title,
    String? typeLabel,
    String? subject,
    int? completedTasks,
    int? totalTasks,
    int? teamCount,
    String? inviteCode,
    List<String>? memberLabels,
  }) {
    return ProjectItem(
      id: id ?? this.id,
      title: title ?? this.title,
      typeLabel: typeLabel ?? this.typeLabel,
      subject: subject ?? this.subject,
      completedTasks: completedTasks ?? this.completedTasks,
      totalTasks: totalTasks ?? this.totalTasks,
      teamCount: teamCount ?? this.teamCount,
      inviteCode: inviteCode ?? this.inviteCode,
      memberLabels: memberLabels ?? this.memberLabels,
    );
  }

  factory ProjectItem.fromFirestore(String id, Map<String, dynamic> json) {
    final labels = (json['memberLabels'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .toList();
    return ProjectItem(
      id: id,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Untitled Project',
      typeLabel: (json['typeLabel'] as String?)?.trim().isNotEmpty == true
          ? (json['typeLabel'] as String).trim()
          : 'Project',
        subject: (json['subject'] as String?)?.trim().isNotEmpty == true
          ? (json['subject'] as String).trim()
          : null,
      completedTasks: 0,
      totalTasks: 0,
      teamCount: labels.isEmpty ? 1 : labels.length,
      inviteCode: json['inviteCode'] as String?,
      memberLabels: labels,
    );
  }
}
