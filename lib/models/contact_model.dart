class Contact {
  final String id;
  final String name;
  final String mobile;
  final String email;
  final String type; // 'borrower' or 'lender'

  const Contact({
    required this.id,
    required this.name,
    required this.mobile,
    this.email = '',
    required this.type,
  });

  String get typeLabel => type == 'lender' ? 'Lender' : 'Borrower';

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.first;
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'mobile': mobile,
    'email': email,
    'type': type,
  };

  factory Contact.fromMap(Map<String, dynamic> m) => Contact(
    id: m['id'] as String,
    name: m['name'] as String,
    mobile: m['mobile'] as String,
    email: (m['email'] as String?) ?? '',
    type: m['type'] as String,
  );
}
