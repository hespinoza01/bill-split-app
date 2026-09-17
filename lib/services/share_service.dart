import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../features/assignment/reviewed_bill_data.dart';
import '../features/summary/split_calculator.dart';

/// Arma el texto de cobro para una persona y abre el share sheet nativo del
/// sistema operativo (WhatsApp, SMS, lo que sea) — nunca un deep link
/// directo a una app en particular.
class ShareService {
  final _currency = NumberFormat.simpleCurrency();

  Future<void> sharePersonTotal(PersonTotal personTotal, ReviewedBillData bill) async {
    final buffer = StringBuffer();
    final restaurant = bill.restaurantName?.trim();
    buffer.writeln(
      restaurant != null && restaurant.isNotEmpty
          ? 'Hola ${personTotal.person.name}, esto es lo que consumiste en $restaurant:'
          : 'Hola ${personTotal.person.name}, esto es lo que consumiste:',
    );
    buffer.writeln();
    for (final item in personTotal.items) {
      final sharedNote = item.sharedWithCount > 1 ? ' (compartido entre ${item.sharedWithCount})' : '';
      buffer.writeln('- ${item.itemName}$sharedNote: ${_currency.format(item.shareAmount)}');
    }
    buffer.writeln();
    buffer.writeln('Subtotal: ${_currency.format(personTotal.subtotalShare)}');
    if (personTotal.taxShare > 0) buffer.writeln('Impuesto: ${_currency.format(personTotal.taxShare)}');
    if (personTotal.tipShare > 0) buffer.writeln('Propina: ${_currency.format(personTotal.tipShare)}');
    buffer.writeln('Total a reembolsar: ${_currency.format(personTotal.total)}');

    await SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }
}
