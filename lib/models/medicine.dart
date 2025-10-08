class Medicine {
  int? id;
  int userId;
  String name;
  String description;
  DateTime scheduleDateTime;
  String dose;          // যেমন: 1 Tablet, 5 ml
  String frequency;     // যেমন: Morning, Afternoon, Night
  String type;          // Tablet / Syrup / Injection
  DateTime createdAt;
  DateTime updatedAt;

  Medicine({
    this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.scheduleDateTime,
    this.dose = "1 Tablet",
    this.frequency = "Morning",
    this.type = "Tablet",
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert Medicine to Map (for SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'scheduleDateTime': scheduleDateTime.toIso8601String(),
      'dose': dose,
      'frequency': frequency,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create Medicine object from Map (from SQLite)
  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      userId: map['userId'],
      name: map['name'],
      description: map['description'],
      scheduleDateTime: DateTime.parse(map['scheduleDateTime']),
      dose: map['dose'] ?? "1 Tablet",
      frequency: map['frequency'] ?? "Morning",
      type: map['type'] ?? "Tablet",
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}
