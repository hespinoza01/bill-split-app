import '../../data/db/app_database.dart';

enum BillPaymentStatus { pending, partial, paid }

/// Estado de pago de una factura, derivado de BillPeople.isPaid — no se
/// persiste aparte, se calcula cada vez a partir de quién ya pagó.
class PaymentStatus {
  final int paidCount;
  final int totalCount;
  final BillPaymentStatus status;

  PaymentStatus({required this.paidCount, required this.totalCount, required this.status});

  factory PaymentStatus.fromBillPeople(List<BillPeopleData> billPeople) {
    final total = billPeople.length;
    final paid = billPeople.where((bp) => bp.isPaid).length;
    final status = paid == 0
        ? BillPaymentStatus.pending
        : (paid == total ? BillPaymentStatus.paid : BillPaymentStatus.partial);
    return PaymentStatus(paidCount: paid, totalCount: total, status: status);
  }

  String get label => switch (status) {
        BillPaymentStatus.pending => 'Pendiente',
        BillPaymentStatus.partial => 'Parcial',
        BillPaymentStatus.paid => 'Pagada',
      };
}
