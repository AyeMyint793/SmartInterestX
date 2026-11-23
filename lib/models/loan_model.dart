class Loan {
  final int number;
  final String contactId;
  final String type; // 'given' (you lent) or 'taken' (you borrowed)
  final double principal;
  final double rate; // percent
  final bool monthly; // true = rate per month, false = rate per year
  final DateTime start;
  final DateTime? due;
  final String notes;

  Loan({
    required this.number,
    required this.contactId,
    required this.type,
    required this.principal,
    required this.rate,
    required this.monthly,
    required this.start,
    this.due,
    this.notes = '',
  });

  String get id => 'SIX-${number.toString().padLeft(3, '0')}';
  bool get isGiven => type == 'given';
  String get typeLabel => isGiven ? 'Given' : 'Taken';

  Map<String, dynamic> toMap() => {
    'number': number,
    'contactId': contactId,
    'type': type,
    'principal': principal,
    'rate': rate,
    'monthly': monthly,
    'start': start.toIso8601String(),
    'due': due?.toIso8601String(),
    'notes': notes,
  };

  factory Loan.fromMap(Map<String, dynamic> m) => Loan(
    number: m['number'] as int,
    contactId: m['contactId'] as String,
    type: m['type'] as String,
    principal: (m['principal'] as num).toDouble(),
    rate: (m['rate'] as num).toDouble(),
    monthly: m['monthly'] as bool,
    start: DateTime.parse(m['start'] as String),
    due: m['due'] == null ? null : DateTime.parse(m['due'] as String),
    notes: (m['notes'] as String?) ?? '',
  );
}
