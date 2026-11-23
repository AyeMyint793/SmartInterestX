class Payment {
  final String id;
  final String loanId;
  final DateTime date;
  final double amount;
  final String mode; // UPI, Bank transfer, Cash, Other
  final String? proofName;
  final String? proofPath;
  final String? proofData; // compressed photo, base64, saved in Firestore

  Payment({
    required this.id,
    required this.loanId,
    required this.date,
    required this.amount,
    required this.mode,
    this.proofName,
    this.proofPath,
    this.proofData,
  });

  bool get hasProof =>
      (proofName != null && proofName!.isNotEmpty) ||
      (proofData != null && proofData!.isNotEmpty);

  Map<String, dynamic> toMap() => {
        'id': id,
        'loanId': loanId,
        'date': date.toIso8601String(),
        'amount': amount,
        'mode': mode,
        'proofName': proofName,
        'proofPath': proofPath,
        'proofData': proofData,
      };

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
        id: m['id'] as String,
        loanId: m['loanId'] as String,
        date: DateTime.parse(m['date'] as String),
        amount: (m['amount'] as num).toDouble(),
        mode: m['mode'] as String,
        proofName: m['proofName'] as String?,
        proofPath: m['proofPath'] as String?,
        proofData: m['proofData'] as String?,
      );
}
