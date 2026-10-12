part of '../main.dart';



// ============================================================

// VENTANA PARA CONFIGURAR EL REPORTE

// ============================================================



class SaboryReportDialog extends StatefulWidget {

  const SaboryReportDialog({super.key});



  @override

  State<SaboryReportDialog> createState() => _SaboryReportDialogState();

}



class _SaboryReportDialogState extends State<SaboryReportDialog> {

  static const months = [

    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',

    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',

  ];



  String period = 'Mes';

  DateTime reportDate = DateTime.now();

  DateTime customStart = DateTime.now();

  DateTime customEnd = DateTime.now();



  bool includeSummary = true;

  bool includeSales = true;

  bool includeExpenses = true;

  bool includeReceivables = true;

  bool includePayables = true;

  bool includePayments = true;

  bool exporting = false;



  DateTime get weekStart => dateOnly(reportDate).subtract(Duration(days: reportDate.weekday - 1));

  DateTime get weekEnd => weekStart.add(const Duration(days: 6));



  DateTimeRange get selectedRange {

    switch (period) {

      case 'Día':

        return DateTimeRange(start: dateOnly(reportDate), end: dateOnly(reportDate));

      case 'Semana':

        return DateTimeRange(start: weekStart, end: weekEnd);

      case 'Mes':

        return DateTimeRange(

          start: DateTime(reportDate.year, reportDate.month, 1),

          end: DateTime(reportDate.year, reportDate.month + 1, 0),

        );

      case 'Año':

        return DateTimeRange(

          start: DateTime(reportDate.year, 1, 1),

          end: DateTime(reportDate.year, 12, 31),

        );

      default:

        return DateTimeRange(start: dateOnly(customStart), end: dateOnly(customEnd));

    }

  }



  String get periodLabel {

    switch (period) {

      case 'Día':

        return '📅 ${formatDate(reportDate)}';

      case 'Semana':

        return '📅 ${formatDate(weekStart)} - ${formatDate(weekEnd)}';

      case 'Mes':

        return '📅 ${months[reportDate.month - 1]} ${reportDate.year}';

      case 'Año':

        return '📅 ${reportDate.year}';

      default:

        return '📅 ${formatDate(customStart)} - ${formatDate(customEnd)}';

    }

  }



  Future<void> selectReportDate() async {

    final value = await chooseDate(context, reportDate);

    if (value != null) setState(() => reportDate = value);

  }



  bool inRange(DateTime date, DateTimeRange range) =>

      !dateOnly(date).isBefore(dateOnly(range.start)) &&

      !dateOnly(date).isAfter(dateOnly(range.end));



  String paymentLabel(String method) {

    switch (method) {

      case 'Efectivo': return '💵 Efectivo';

      case 'Transferencia': return '🏦 Transferencia';

      case 'Fiado': return '📝 Fiado';

      default: return method;

    }

  }



  xls.CellStyle get titleStyle => xls.CellStyle(

        bold: true,

        fontSize: 16,

        fontColorHex: xls.ExcelColor.white,

        backgroundColorHex: xls.ExcelColor.fromHexString('#16324F'),

        horizontalAlign: xls.HorizontalAlign.Center,

        verticalAlign: xls.VerticalAlign.Center,

      );



  xls.CellStyle get headerStyle => xls.CellStyle(

        bold: true,

        fontColorHex: xls.ExcelColor.white,

        backgroundColorHex: xls.ExcelColor.fromHexString('#1F7A8C'),

        horizontalAlign: xls.HorizontalAlign.Center,

        verticalAlign: xls.VerticalAlign.Center,

      );



  xls.CellStyle get moneyStyle => xls.CellStyle(

        numberFormat: xls.CustomNumericNumFormat(formatCode: r'$#,##0.00'),

      );



  void addTitle(xls.Sheet sheet, String title, int columns) {

    sheet.merge(

      xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),

      xls.CellIndex.indexByColumnRow(columnIndex: columns - 1, rowIndex: 0),

      customValue: xls.TextCellValue(title),

    );

    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet.setRowHeight(0, 28);

  }



  void addHeaders(xls.Sheet sheet, List<String> headers, {int row = 2}) {

    sheet.insertRowIterables(headers.map(xls.TextCellValue.new).toList(), row);

    for (var c = 0; c < headers.length; c++) {

      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row)).cellStyle = headerStyle;

    }

  }



  void setWidths(xls.Sheet sheet, List<double> widths) {

    for (var i = 0; i < widths.length; i++) sheet.setColumnWidth(i, widths[i]);

  }



  void styleMoney(xls.Sheet sheet, int row, Iterable<int> columns) {

    for (final c in columns) {

      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row)).cellStyle = moneyStyle;

    }

  }



  void buildSummary(xls.Excel book, DateTimeRange range) {

    final sheet = book['Resumen'];

    addTitle(sheet, 'SABORY • RESUMEN GENERAL', 4);

    sheet.appendRow([xls.TextCellValue('Período'), xls.TextCellValue('${formatDate(range.start)} - ${formatDate(range.end)}')]);

    sheet.appendRow([xls.TextCellValue('Indicador'), xls.TextCellValue('Valor')]);

    sheet.cell(xls.CellIndex.indexByString('A3')).cellStyle = headerStyle;

    sheet.cell(xls.CellIndex.indexByString('B3')).cellStyle = headerStyle;



    final sales = appStore.salesBetween(range.start, range.end);

    final expenses = appStore.expensesBetween(range.start, range.end);

    final salesTotal = sales.fold<double>(0, (s, e) => s + e.total);

    final expenseTotal = expenses.fold<double>(0, (s, e) => s + e.total);

    final received = sales.where((s) => s.paymentMethod != 'Fiado').fold<double>(0, (a, s) => a + s.total) +

        appStore.receivableMovements.where((m) => m.type == 'Pago' && inRange(m.date, range)).fold<double>(0, (a, m) => a + m.amount);

    final paid = expenses.where((e) => e.paymentMethod != 'Fiado').fold<double>(0, (a, e) => a + e.total) +

        appStore.payableMovements.where((m) => m.type == 'Pago' && inRange(m.date, range)).fold<double>(0, (a, m) => a + m.amount);

    final receivableGenerated = sales.where((s) => s.paymentMethod == 'Fiado').fold<double>(0, (a, s) => a + s.total);

    final payableGenerated = expenses.where((e) => e.paymentMethod == 'Fiado').fold<double>(0, (a, e) => a + e.total);



    final rows = <(String, double)>[

      ('Ventas', salesTotal), ('Gastos', expenseTotal), ('Utilidad contable', salesTotal - expenseTotal),

      ('Dinero recibido', received), ('Dinero pagado', paid), ('Flujo real', received - paid),

      ('Por cobrar generado', receivableGenerated), ('Por pagar generado', payableGenerated),

    ];

    for (final item in rows) {

      sheet.appendRow([xls.TextCellValue(item.$1), xls.DoubleCellValue(item.$2)]);

      styleMoney(sheet, sheet.maxRows - 1, [1]);

    }

    setWidths(sheet, [30, 20, 18, 18]);

  }



  void buildSales(xls.Excel book, DateTimeRange range) {

    final sheet = book['Ventas'];

    addTitle(sheet, 'SABORY • VENTAS', 9);

    addHeaders(sheet, ['Fecha', 'Pedido', 'Cliente', 'Producto', 'Cant.', 'P. Unitario', 'Subtotal', 'Pago', 'Nota']);

    for (final sale in appStore.salesBetween(range.start, range.end)) {

      for (final item in sale.items) {

        sheet.appendRow([

          xls.TextCellValue(formatDate(sale.date)), xls.TextCellValue('#${sale.id}'),

          xls.TextCellValue(sale.person.isEmpty ? 'Consumidor final' : sale.person), xls.TextCellValue(item.productName),

          xls.IntCellValue(item.quantity), xls.DoubleCellValue(item.unitPrice), xls.DoubleCellValue(item.total),

          xls.TextCellValue(paymentLabel(sale.paymentMethod)), xls.TextCellValue(sale.note),

        ]);

        styleMoney(sheet, sheet.maxRows - 1, [5, 6]);

      }

    }

    setWidths(sheet, [14, 11, 22, 28, 9, 14, 14, 20, 28]);

  }



  void buildExpenses(xls.Excel book, DateTimeRange range) {
    final sheet = book['Gastos'];

    addTitle(sheet, 'SABORY • GASTOS', 13);

    addHeaders(sheet, [
      'Fecha',
      'Compra',
      'Proveedor',
      'Insumo',
      'Cantidad',
      'Unidad',
      'P. Unitario',
      'Subtotal',
      'Pago',
      'Comprobante',
      'N.º de factura',
      'RUC / Identificación',
      'Observación',
    ]);

    for (final expense in appStore.expensesBetween(range.start, range.end)) {
      for (final item in expense.items) {
        final comprobante = expense.invoiceType.trim().isEmpty
            ? 'Sin especificar'
            : expense.invoiceType;

        final showInvoiceData = expense.invoiceType == 'Con factura';

        sheet.appendRow([
          xls.TextCellValue(formatDate(expense.date)),
          xls.TextCellValue('#${expense.id}'),
          xls.TextCellValue(
            expense.provider.isEmpty ? 'Sin proveedor' : expense.provider,
          ),
          xls.TextCellValue(item.description),
          xls.DoubleCellValue(item.quantity),
          xls.TextCellValue(item.unit),
          xls.DoubleCellValue(item.unitPrice),
          xls.DoubleCellValue(item.total),
          xls.TextCellValue(paymentLabel(expense.paymentMethod)),
          xls.TextCellValue(comprobante),
          xls.TextCellValue(showInvoiceData ? expense.invoiceNumber : ''),
          xls.TextCellValue(showInvoiceData ? expense.invoiceTaxId : ''),
          xls.TextCellValue(expense.note),
        ]);

        styleMoney(sheet, sheet.maxRows - 1, [6, 7]);
      }
    }

    setWidths(
      sheet,
      [14, 11, 22, 28, 12, 12, 14, 14, 20, 18, 18, 22, 34],
    );
  }


  void buildReceivables(xls.Excel book, DateTimeRange range) {

    final sheet = book['Por cobrar'];

    addTitle(sheet, 'SABORY • CUENTAS POR COBRAR', 6);

    addHeaders(sheet, ['Cliente', 'Fiado en período', 'Pagado en período', 'Saldo del período', 'Saldo actual', 'Último movimiento']);

    for (final account in appStore.receivables) {

      final ms = account.movements.where((m) => inRange(m.date, range)).toList();

      if (ms.isEmpty) continue;

      final charged = ms.where((m) => m.type == 'Venta').fold<double>(0, (a, m) => a + m.amount);

      final paid = ms.where((m) => m.type == 'Pago').fold<double>(0, (a, m) => a + m.amount);

      sheet.appendRow([

        xls.TextCellValue(account.person), xls.DoubleCellValue(charged), xls.DoubleCellValue(paid),

        xls.DoubleCellValue(charged - paid), xls.DoubleCellValue(account.balance),

        xls.TextCellValue(account.lastMovementDate == null ? '' : formatDate(account.lastMovementDate!)),

      ]);

      styleMoney(sheet, sheet.maxRows - 1, [1, 2, 3, 4]);

    }

    setWidths(sheet, [24, 18, 18, 18, 18, 20]);

  }



  void buildPayables(xls.Excel book, DateTimeRange range) {

    final sheet = book['Por pagar'];

    addTitle(sheet, 'SABORY • CUENTAS POR PAGAR', 6);

    addHeaders(sheet, ['Proveedor', 'Comprado fiado', 'Pagado en período', 'Saldo del período', 'Saldo actual', 'Último movimiento']);

    for (final account in appStore.payables) {

      final ms = account.movements.where((m) => inRange(m.date, range)).toList();

      if (ms.isEmpty) continue;

      final charged = ms.where((m) => m.type == 'Compra').fold<double>(0, (a, m) => a + m.amount);

      final paid = ms.where((m) => m.type == 'Pago').fold<double>(0, (a, m) => a + m.amount);

      sheet.appendRow([

        xls.TextCellValue(account.provider), xls.DoubleCellValue(charged), xls.DoubleCellValue(paid),

        xls.DoubleCellValue(charged - paid), xls.DoubleCellValue(account.balance),

        xls.TextCellValue(account.lastMovementDate == null ? '' : formatDate(account.lastMovementDate!)),

      ]);

      styleMoney(sheet, sheet.maxRows - 1, [1, 2, 3, 4]);

    }

    setWidths(sheet, [24, 18, 18, 18, 18, 20]);

  }



  void buildPayments(xls.Excel book, DateTimeRange range) {

    final sheet = book['Pagos'];

    addTitle(sheet, 'SABORY • HISTORIAL DE PAGOS', 7);

    addHeaders(sheet, ['Fecha', 'Tipo', 'Cliente / Proveedor', 'Descripción', 'Monto', 'Método', 'Nota']);

    final rows = <({DateTime date, String type, String name, String description, double amount, String method, String note})>[];

    for (final m in appStore.receivableMovements.where((m) => m.type == 'Pago' && inRange(m.date, range))) {

      rows.add((date: m.date, type: 'Pago recibido', name: m.person, description: m.description, amount: m.amount, method: m.paymentMethod, note: m.note));

    }

    for (final m in appStore.payableMovements.where((m) => m.type == 'Pago' && inRange(m.date, range))) {

      rows.add((date: m.date, type: 'Pago a proveedor', name: m.provider, description: m.description, amount: m.amount, method: m.paymentMethod, note: m.note));

    }

    rows.sort((a, b) => a.date.compareTo(b.date));

    for (final r in rows) {

      sheet.appendRow([

        xls.TextCellValue(formatDate(r.date)), xls.TextCellValue(r.type), xls.TextCellValue(r.name),

        xls.TextCellValue(r.description), xls.DoubleCellValue(r.amount), xls.TextCellValue(paymentLabel(r.method)), xls.TextCellValue(r.note),

      ]);

      styleMoney(sheet, sheet.maxRows - 1, [4]);

    }

    setWidths(sheet, [14, 20, 24, 28, 14, 20, 28]);

  }



 Future<void> exportExcel() async {
  final hasSelection =
      includeSummary ||
      includeSales ||
      includeExpenses ||
      includeReceivables ||
      includePayables ||
      includePayments;

  if (!hasSelection) {
    showMessage(
      context,
      'Selecciona al menos una opción para el reporte.',
    );
    return;
  }

  setState(() => exporting = true);

  try {
    final range = selectedRange;
    final book = xls.Excel.createExcel();

    if (includeSummary) buildSummary(book, range);
    if (includeSales) buildSales(book, range);
    if (includeExpenses) buildExpenses(book, range);
    if (includeReceivables) buildReceivables(book, range);
    if (includePayables) buildPayables(book, range);
    if (includePayments) buildPayments(book, range);

    if (book.tables.containsKey('Sheet1') && book.tables.length > 1) {
      book.delete('Sheet1');
    }

    final bytes = book.encode();

    if (bytes == null) {
      throw Exception('No se pudo crear el archivo Excel.');
    }

    final stamp =
        '${range.start.year}'
        '${range.start.month.toString().padLeft(2, '0')}'
        '${range.start.day.toString().padLeft(2, '0')}_'
        '${range.end.year}'
        '${range.end.month.toString().padLeft(2, '0')}'
        '${range.end.day.toString().padLeft(2, '0')}';

    final fileName = 'Sabory_Reporte_$stamp.xlsx';
    final excelBytes = Uint8List.fromList(bytes);

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: 'Sabory_Reporte_$stamp',
        bytes: excelBytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 10),
              Expanded(child: Text('Reporte generado')),
            ],
          ),
          content: Text(
            'Excel generado correctamente:\n\n$fileName',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } else {
      await FileSaver.instance.saveToDownloads(
        name: 'Sabory_Reporte_$stamp',
        bytes: excelBytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
        subfolder: 'Sabory/Reportes',
      );

      if (!mounted) return;

      final shareFile = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 10),
              Expanded(child: Text('Reporte guardado')),
            ],
          ),
          content: Text(
            'El reporte se guardó correctamente en:\n\n'
            '📁 Descargas/Sabory/Reportes\n\n'
            '📄 $fileName\n\n'
            'Puedes cerrar esta ventana o compartir el reporte ahora.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Compartir'),
            ),
          ],
        ),
      );

      if (shareFile == true) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(p.join(tempDir.path, fileName));
        await tempFile.writeAsBytes(excelBytes, flush: true);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(tempFile.path)],
            subject: 'Reporte Sabory',
            text: 'Reporte generado desde Sabory.',
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      showMessage(
        context,
        'No se pudo generar el Excel: $e',
      );
    }
  } finally {
    if (mounted) {
      setState(() => exporting = false);
    }
  }
}


  @override

  Widget build(BuildContext context) {

    return AlertDialog(

      title: const Row(children: [Text('📊'), SizedBox(width: 8), Text('Generar reporte')]),

      content: SizedBox(

        width: 520,

        child: SingleChildScrollView(

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            mainAxisSize: MainAxisSize.min,

            children: [

              const Text('Período del reporte', style: TextStyle(fontWeight: FontWeight.bold)),

              const SizedBox(height: 10),

              Wrap(

                spacing: 7,

                runSpacing: 7,

                children: [

                  for (final item in const ['Día', 'Semana', 'Mes', 'Año', 'Personalizado'])

                    ChoiceChip(

                      selected: period == item,

                      label: Text(item),

                      onSelected: (_) => setState(() => period = item),

                    ),

                ],

              ),

              const SizedBox(height: 14),

              if (period != 'Personalizado')

                SizedBox(

                  width: double.infinity,

                  child: OutlinedButton.icon(

                    onPressed: selectReportDate,

                    icon: const Icon(Icons.calendar_month),

                    label: Text(periodLabel),

                  ),

                ),

              if (period == 'Personalizado')

                Row(

                  children: [

                    Expanded(

                      child: FilterDateButton(

                        label: 'Desde',

                        date: customStart,

                        onPressed: () async {

                          final value = await chooseDate(context, customStart);

                          if (value != null) {

                            setState(() {

                              customStart = value;

                              if (customEnd.isBefore(value)) customEnd = value;

                            });

                          }

                        },

                      ),

                    ),

                    const SizedBox(width: 8),

                    Expanded(

                      child: FilterDateButton(

                        label: 'Hasta',

                        date: customEnd,

                        onPressed: () async {

                          final value = await chooseDate(context, customEnd);

                          if (value != null) setState(() => customEnd = value);

                        },

                      ),

                    ),

                  ],

                ),

              const SizedBox(height: 20),

              const Divider(),

              const SizedBox(height: 8),

              const Text('¿Qué deseas incluir?', style: TextStyle(fontWeight: FontWeight.bold)),

              const SizedBox(height: 6),

              CheckboxListTile(contentPadding: EdgeInsets.zero, value: includeSummary, title: const Text('📊 Resumen general'), onChanged: (v) => setState(() => includeSummary = v ?? false)),

              CheckboxListTile(contentPadding: EdgeInsets.zero, value: includeSales, title: const Text('💰 Ventas'), onChanged: (v) => setState(() => includeSales = v ?? false)),

              CheckboxListTile(contentPadding: EdgeInsets.zero, value: includeExpenses, title: const Text('🛒 Gastos'), onChanged: (v) => setState(() => includeExpenses = v ?? false)),

              CheckboxListTile(contentPadding: EdgeInsets.zero, value: includeReceivables, title: const Text('👥 Cuentas por cobrar'), onChanged: (v) => setState(() => includeReceivables = v ?? false)),

              CheckboxListTile(contentPadding: EdgeInsets.zero, value: includePayables, title: const Text('🏪 Cuentas por pagar'), onChanged: (v) => setState(() => includePayables = v ?? false)),

              CheckboxListTile(contentPadding: EdgeInsets.zero, value: includePayments, title: const Text('💵 Historial de pagos'), onChanged: (v) => setState(() => includePayments = v ?? false)),

            ],

          ),

        ),

      ),

      actions: [

        TextButton(onPressed: exporting ? null : () => Navigator.pop(context), child: const Text('Cancelar')),

        FilledButton.icon(

          onPressed: exporting ? null : exportExcel,

          icon: exporting

              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))

              : const Icon(Icons.file_download_outlined),

          label: Text(exporting ? 'Generando...' : 'Exportar a Excel'),

        ),

      ],

    );

  }

}