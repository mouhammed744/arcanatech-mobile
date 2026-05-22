class RfidCard {
  final String id;  // UUID
  final String cardNumber;
  final bool isActive;
  final String? lastScannedAt;
  final String? assignedAt;

  const RfidCard({
    required this.id,
    required this.cardNumber,
    required this.isActive,
    this.lastScannedAt,
    this.assignedAt,
  });

  factory RfidCard.fromJson(Map<String, dynamic> json) => RfidCard(
    id: json['id'].toString(),
    cardNumber: json['card_number'] as String? ?? json['cardNumber'] as String? ?? '',
    isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? false,
    lastScannedAt: json['last_scanned_at'] as String? ?? json['lastScannedAt'] as String?,
    assignedAt: json['assigned_at'] as String? ?? json['assignedAt'] as String?,
  );

  String get statusLabel => isActive ? 'Active' : 'Inactive';
}
