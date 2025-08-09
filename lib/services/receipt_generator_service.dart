// lib/services/receipt_generator_service.dart
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:epos/models/order.dart'; // Your Order model
import 'package:intl/intl.dart'; // For date/time formatting

class ReceiptGeneratorService {
  Future<List<int>> generateReceiptBytes(Order order) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile); // Assuming 80mm paper

    List<int> bytes = [];

    // Header
    bytes += generator.text('THE VILLAGE PIZZERIA',
        styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            fontType: PosFontType.fontA),
        linesAfter: 1);

    final now = DateTime.now();
    bytes += generator.text(
        '${DateFormat('dd/MM/yyyy HH:mm:ss').format(now)}',
        styles: const PosStyles(align: PosAlign.center),
        linesAfter: 1);

    // Customer Details
    bytes += generator.text(order.customerName,
        styles: const PosStyles(
            align: PosAlign.left,
            fontType: PosFontType.fontA,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            bold: true),
        linesAfter: 0);

    if (order.streetAddress != null && order.streetAddress!.isNotEmpty) {
      bytes += generator.text(order.streetAddress!,
          styles: const PosStyles(align: PosAlign.left));
    }
    if (order.city != null && order.city!.isNotEmpty) {
      bytes += generator.text(
          '${order.city}, ${order.postalCode ?? ''}',
          styles: const PosStyles(align: PosAlign.left));
    }
    if (order.phoneNumber != null && order.phoneNumber!.isNotEmpty) {
      bytes += generator.text(order.phoneNumber!,
          styles: const PosStyles(align: PosAlign.left), linesAfter: 1);
    }

    bytes += generator.hr(ch: '-'); // Dashed line
    bytes += generator.text('ORDER ID: ${order.orderId}',
        styles: const PosStyles(align: PosAlign.center), linesAfter: 1);
    bytes += generator.hr(ch: '-'); // Dashed line

    // Items Table
    for (var item in order.items) {
      bytes += generator.row([
        PosColumn(
            text: '${item.quantity} x',
            width: 2,
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            text: item.itemName,
            width: 6,
            styles: const PosStyles(align: PosAlign.left)),
        PosColumn(
            text: '£ ${item.totalPrice.toStringAsFixed(2)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);

      if (item.description.isNotEmpty) {
        List<String> descLines = item.description.split('\n');
        for (String line in descLines) {
          String displayLine = line.trim();
          if (displayLine.startsWith('-') || displayLine.startsWith('Size:') || displayLine.startsWith('Crust:')) {
            bytes += generator.text(displayLine,
                styles: const PosStyles(
                    align: PosAlign.left, fontType: PosFontType.fontB));
          } else {
            bytes += generator.text('- ${displayLine}',
                styles: const PosStyles(
                    align: PosAlign.left, fontType: PosFontType.fontB));
          }
        }
      }
      if (item.comment != null && item.comment!.isNotEmpty) {
        bytes += generator.text('Note: ${item.comment}',
            styles: const PosStyles(
                align: PosAlign.left,
                fontType: PosFontType.fontB,
                reverse: true));
      }
      bytes += generator.hr(ch: '-');
    }
    bytes += generator.hr(ch: '-');
    bytes += generator.hr(ch: '-');

    // Totals
    bytes += generator.text('Product count: ${order.items.length}',
        styles: const PosStyles(
            align: PosAlign.left, bold: true, fontType: PosFontType.fontA));
    bytes += generator.text(
        'Sub Total: £ ${order.orderTotalPrice.toStringAsFixed(2)}',
        styles: const PosStyles(
            align: PosAlign.left, bold: true, fontType: PosFontType.fontA),
        linesAfter: 1);

    // Payment and Order Type
    bytes += generator.text(
        '${order.paymentType.toLowerCase() == "cod" ? "UNPAID" : "PAID"}: £ ${order.orderTotalPrice.toStringAsFixed(2)}',
        styles: const PosStyles(
            align: PosAlign.left,
            fontType: PosFontType.fontA,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true));
    bytes += generator.text(
        '${order.orderType.toLowerCase() == "delivery" ? "DELIVERY" : "PICK UP"}',
        styles: const PosStyles(
            align: PosAlign.left,
            fontType: PosFontType.fontA,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true),
        linesAfter: 1);

    bytes += generator.hr(ch: '-');
    bytes += generator.hr(ch: '-');

    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }
}