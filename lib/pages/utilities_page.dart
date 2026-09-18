part of '../main.dart';

// ============================================================
// UTILIDAD
// ============================================================

class UtilitiesPage extends StatefulWidget {
  const UtilitiesPage({
    super.key,
  });

  @override
  State<UtilitiesPage> createState() =>
      _UtilitiesPageState();
}

class _UtilitiesPageState
    extends State<UtilitiesPage> {
  String period = 'Hoy';

  DateTime customStart = DateTime.now();
  DateTime customEnd = DateTime.now();

  // Fecha independiente para consultar el cierre diario.
  DateTime dailyCloseDate = dateOnly(DateTime.now());

  DateTimeRange get range {
    final now = dateOnly(DateTime.now());

    if (period == 'Semana') {
      final start = now.subtract(
        Duration(days: now.weekday - 1),
      );

      return DateTimeRange(
        start: start,
        end: now,
      );
    }

    if (period == 'Mes') {
      return DateTimeRange(
        start: DateTime(
          now.year,
          now.month,
          1,
        ),
        end: now,
      );
    }

    if (period == 'Personalizado') {
      return DateTimeRange(
        start: dateOnly(customStart),
        end: dateOnly(customEnd),
      );
    }

    return DateTimeRange(
      start: now,
      end: now,
    );
  }

  Future<void> selectDailyCloseDate() async {
    final selected = await chooseDate(
      context,
      dailyCloseDate,
    );

    if (selected != null) {
      setState(() {
        dailyCloseDate = dateOnly(selected);
      });
    }
  }

  void previousDailyClose() {
    setState(() {
      dailyCloseDate = dailyCloseDate.subtract(
        const Duration(days: 1),
      );
    });
  }

  void nextDailyClose() {
    final tomorrow = dailyCloseDate.add(
      const Duration(days: 1),
    );

    final today = dateOnly(DateTime.now());

    // No permite consultar una fecha futura.
    if (!tomorrow.isAfter(today)) {
      setState(() {
        dailyCloseDate = tomorrow;
      });
    }
  }

  Future<void> openReportDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return const SaboryReportDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final selectedRange = range;

        final sales =
            appStore.salesTotalBetween(
          selectedRange.start,
          selectedRange.end,
        );

        final expenses =
            appStore.expenseTotalBetween(
          selectedRange.start,
          selectedRange.end,
        );

        final utility = sales - expenses;

        final received =
            appStore.realMoneyReceivedBetween(
          selectedRange.start,
          selectedRange.end,
        );

        final paid =
            appStore.realMoneyPaidBetween(
          selectedRange.start,
          selectedRange.end,
        );

        final cashFlow = received - paid;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '📈 Utilidad',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            Wrap(
              spacing: 7,
              children: [
                for (final item in const [
                  'Hoy',
                  'Semana',
                  'Mes',
                  'Personalizado',
                ])
                  ChoiceChip(
                    selected: period == item,
                    label: Text(item),
                    onSelected: (_) {
                      setState(() {
                        period = item;
                      });
                    },
                  ),
              ],
            ),

            if (period == 'Personalizado') ...[
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: FilterDateButton(
                      label: 'Desde',
                      date: customStart,
                      onPressed: () async {
                        final value =
                            await chooseDate(
                          context,
                          customStart,
                        );

                        if (value != null) {
                          setState(() {
                            customStart = value;

                            if (customEnd
                                .isBefore(value)) {
                              customEnd = value;
                            }
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
                        final value =
                            await chooseDate(
                          context,
                          customEnd,
                        );

                        if (value != null) {
                          setState(() {
                            customEnd = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Ventas',
                    value: money(sales),
                    icon: Icons.attach_money,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: SummaryCard(
                    title: 'Gastos',
                    value: money(expenses),
                    icon: Icons.shopping_cart,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            TotalBox(
              title: utility >= 0
                  ? 'UTILIDAD CONTABLE'
                  : 'PÉRDIDA CONTABLE',
              value: utility,
              subtitle: 'Ventas - Gastos',
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Dinero recibido',
                    value: money(received),
                    icon: Icons.south_west,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: SummaryCard(
                    title: 'Dinero pagado',
                    value: money(paid),
                    icon: Icons.north_east,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            TotalBox(
              title: 'FLUJO REAL',
              value: cashFlow,
              subtitle:
                  'Dinero recibido - dinero pagado',
            ),

            // =================================================
            // CIERRE DIARIO
            // =================================================

            const SizedBox(height: 22),

            const SectionTitle(
              icon: Icons.point_of_sale,
              title: 'Cierre diario',
            ),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Día anterior',
                      onPressed:
                          previousDailyClose,
                      icon: const Icon(
                        Icons.chevron_left,
                      ),
                    ),

                    Expanded(
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                        onTap:
                            selectDailyCloseDate,
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 10,
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Consultar cierre del día',
                                style: TextStyle(
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                '📅 ${formatDate(dailyCloseDate)}',
                                style:
                                    const TextStyle(
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    IconButton(
                      tooltip: 'Día siguiente',
                      onPressed:
                          dailyCloseDate.isBefore(
                        dateOnly(DateTime.now()),
                      )
                              ? nextDailyClose
                              : null,
                      icon: const Icon(
                        Icons.chevron_right,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            DailyCashCloseCard(
              date: dailyCloseDate,
            ),

            // =================================================
            // REPORTES
            // =================================================

            const SizedBox(height: 24),

            const SectionTitle(
              icon: Icons.description_outlined,
              title: 'Reportes',
            ),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          '📊',
                          style:
                              TextStyle(fontSize: 28),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Generar reporte',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Consulta y exporta la información de Sabory '
                      'por día, semana, mes, año o un período personalizado.',
                      style: TextStyle(
                        color:
                            Colors.grey.shade700,
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            openReportDialog,
                        icon: const Icon(
                          Icons.file_download_outlined,
                        ),
                        label: const Text(
                          'Generar reporte',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        );
      },
    );
  }
}


// La configuración y exportación de reportes está separada en reports/excel_report_service.dart.

class DailyCashCloseCard
    extends StatelessWidget {
  final DateTime date;

  const DailyCashCloseCard({
    super.key,
    required this.date,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final saleCash =
        appStore.salesByMethodBetween(
      'Efectivo',
      date,
      date,
    );

    final saleTransfer =
        appStore.salesByMethodBetween(
      'Transferencia',
      date,
      date,
    );

    final creditSales =
        appStore.salesByMethodBetween(
      'Fiado',
      date,
      date,
    );

    final customerCash =
        appStore
            .customerPaymentsByMethodBetween(
      'Efectivo',
      date,
      date,
    );

    final customerTransfer =
        appStore
            .customerPaymentsByMethodBetween(
      'Transferencia',
      date,
      date,
    );

    final expenseCash =
        appStore.expensesByMethodBetween(
      'Efectivo',
      date,
      date,
    );

    final expenseTransfer =
        appStore.expensesByMethodBetween(
      'Transferencia',
      date,
      date,
    );

    final creditExpenses =
        appStore.expensesByMethodBetween(
      'Fiado',
      date,
      date,
    );

    final providerCash =
        appStore
            .providerPaymentsByMethodBetween(
      'Efectivo',
      date,
      date,
    );

    final providerTransfer =
        appStore
            .providerPaymentsByMethodBetween(
      'Transferencia',
      date,
      date,
    );

    final cashIn =
        saleCash + customerCash;

    final transferIn =
        saleTransfer +
            customerTransfer;

    final cashOut =
        expenseCash +
            providerCash;

    final transferOut =
        expenseTransfer +
            providerTransfer;

    final net =
        cashIn +
        transferIn -
        cashOut -
        transferOut;

    final totalSales =
        appStore.salesTotalBetween(
      date,
      date,
    );

    final totalExpenses =
        appStore.expenseTotalBetween(
      date,
      date,
    );

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          children: [
            Text(
              '📅 ${formatDate(date)}',
              style:
                  const TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            CashCloseRow(
              label:
                  '🧾 Ventas totales del día',
              value: totalSales,
              strong: true,
            ),

            CashCloseRow(
              label:
                  '🛒 Gastos totales del día',
              value:
                  -totalExpenses,
              strong: true,
            ),

            const Divider(),

            CashCloseRow(
              label:
                  '💵 Efectivo recibido',
              value: cashIn,
            ),

            CashCloseRow(
              label:
                  '🏦 Transferencias recibidas',
              value: transferIn,
            ),

            CashCloseRow(
              label:
                  '👤 Por cobrar generado',
              value: creditSales,
            ),

            const Divider(),

            CashCloseRow(
              label:
                  '💸 Efectivo pagado',
              value: -cashOut,
            ),

            CashCloseRow(
              label:
                  '🏦 Transferencias pagadas',
              value:
                  -transferOut,
            ),

            CashCloseRow(
              label:
                  '🏪 Por pagar generado',
              value:
                  -creditExpenses,
            ),

            const Divider(),

            CashCloseRow(
              label:
                  '💰 Saldo efectivo',
              value:
                  cashIn - cashOut,
              strong: true,
            ),

            CashCloseRow(
              label:
                  '🏦 Saldo transferencias',
              value:
                  transferIn -
                      transferOut,
              strong: true,
            ),

            const Divider(),

            CashCloseRow(
              label:
                  '📊 Movimiento neto real',
              value: net,
              strong: true,
            ),
          ],
        ),
      ),
    );
  }
}
