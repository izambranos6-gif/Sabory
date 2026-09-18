part of '../main.dart';

// ============================================================
// DIÁLOGO CLIENTE
// ============================================================

class CustomerAccountDialog
    extends StatefulWidget {
  final ReceivableAccount account;

  const CustomerAccountDialog({
    super.key,
    required this.account,
  });

  @override
  State<CustomerAccountDialog>
      createState() =>
          _CustomerAccountDialogState();
}

class _CustomerAccountDialogState
    extends State<CustomerAccountDialog> {
  final amountController =
      TextEditingController();

  final noteController =
      TextEditingController();

  String paymentMethod =
      'Efectivo';

  DateTime date =
      DateTime.now();

  bool paying = false;

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();

    super.dispose();
  }

  Future<void> registerPayment() async {
    if (paying) {
      return;
    }

    final amount =
        double.tryParse(
      amountController.text
          .replaceAll(',', '.'),
    );

    if (amount == null) {
      showMessage(
        context,
        'Ingresa un valor válido.',
      );

      return;
    }

    final current =
        appStore.findReceivable(
      widget.account.person,
    );

    if (current == null) {
      return;
    }

    setState(() {
      paying = true;
    });

    final error = await appStore
        .registerCustomerPayment(
      account: current,
      amount: amount,
      paymentMethod:
          paymentMethod,
      date: date,
      note:
          noteController.text,
    );

    if (!mounted) {
      return;
    }

    if (error != null) {
      setState(() {
        paying = false;
      });

      showMessage(
        context,
        error,
      );

      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final current =
        appStore.findReceivable(
              widget.account.person,
            ) ??
            widget.account;

    return AlertDialog(
      title: Text(
        '👤 ${current.person}',
      ),
      content: SizedBox(
        width: 500,
        child:
            SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Total consumido: ${money(current.charged)}',
              ),
              Text(
                'Pagado: ${money(current.paid)}',
              ),
              Text(
                'Por cobrar: ${money(current.balance > 0 ? current.balance : 0)}',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const Divider(),

              ...current.movements.map(
                (movement) =>
                    ListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  leading: Text(
                    movement.type ==
                            'Pago'
                        ? '💵'
                        : '🧾',
                  ),
                  title: Text(
                    movement.description,
                  ),
                  subtitle: Text(
                    '${formatDate(movement.date)}'
                    '\n${movement.paymentMethod}',
                  ),
                  trailing: Text(
                    '${movement.type == 'Pago' ? '-' : ''}${money(movement.amount)}',
                  ),
                ),
              ),

              if (current.balance >
                  0) ...[
                const Divider(),

                const Text(
                  'Registrar pago',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                TextField(
                  controller:
                      amountController,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Valor pagado',
                    prefixText:
                        '\$ ',
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                DropdownButtonFormField<
                    String>(
                  value:
                      paymentMethod,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Forma de pago',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value:
                          'Efectivo',
                      child: Text(
                        '💵 Efectivo',
                      ),
                    ),
                    DropdownMenuItem(
                      value:
                          'Transferencia',
                      child: Text(
                        '🏦 Transferencia',
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value !=
                        null) {
                      setState(() {
                        paymentMethod =
                            value;
                      });
                    }
                  },
                ),

                const SizedBox(
                  height: 10,
                ),

                DateSelector(
                  title:
                      'Fecha del pago',
                  date: date,
                  onTap: () async {
                    final value =
                        await chooseDate(
                      context,
                      date,
                    );

                    if (value !=
                        null) {
                      setState(() {
                        date = value;
                      });
                    }
                  },
                ),

                const SizedBox(
                  height: 10,
                ),

                TextField(
                  controller:
                      noteController,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Observación (opcional)',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(
            context,
          ),
          child:
              const Text(
            'Cerrar',
          ),
        ),
        if (current.balance > 0)
          FilledButton.icon(
            onPressed:
                paying ? null : registerPayment,
            icon:
                const Icon(
              Icons.payments,
            ),
            label:
                Text(
                  paying ? 'Registrando...' : 'Registrar pago',
                ),
          ),
      ],
    );
  }
}

// ============================================================
// DIÁLOGO PROVEEDOR
// ============================================================

class ProviderAccountDialog
    extends StatefulWidget {
  final PayableAccount account;

  const ProviderAccountDialog({
    super.key,
    required this.account,
  });

  @override
  State<ProviderAccountDialog>
      createState() =>
          _ProviderAccountDialogState();
}

class _ProviderAccountDialogState
    extends State<ProviderAccountDialog> {
  final amountController =
      TextEditingController();

  final noteController =
      TextEditingController();

  String paymentMethod =
      'Efectivo';

  DateTime date =
      DateTime.now();

  bool paying = false;

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();

    super.dispose();
  }

  Future<void> registerPayment() async {
    if (paying) {
      return;
    }

    final amount =
        double.tryParse(
      amountController.text
          .replaceAll(',', '.'),
    );

    if (amount == null) {
      showMessage(
        context,
        'Ingresa un valor válido.',
      );

      return;
    }

    final current =
        appStore.findPayable(
      widget.account.provider,
    );

    if (current == null) {
      return;
    }

    setState(() {
      paying = true;
    });

    final error = await appStore
        .registerProviderPayment(
      account: current,
      amount: amount,
      paymentMethod:
          paymentMethod,
      date: date,
      note:
          noteController.text,
    );

    if (!mounted) {
      return;
    }

    if (error != null) {
      setState(() {
        paying = false;
      });

      showMessage(
        context,
        error,
      );

      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final current =
        appStore.findPayable(
              widget.account.provider,
            ) ??
            widget.account;

    return AlertDialog(
      title: Text(
        '🏪 ${current.provider}',
      ),
      content: SizedBox(
        width: 500,
        child:
            SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Total comprado: ${money(current.purchased)}',
              ),
              Text(
                'Pagado: ${money(current.paid)}',
              ),
              Text(
                'Por pagar: ${money(current.balance > 0 ? current.balance : 0)}',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const Divider(),

              ...current.movements.map(
                (movement) =>
                    ListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  leading: Text(
                    movement.type ==
                            'Pago'
                        ? '💸'
                        : '🛒',
                  ),
                  title: Text(
                    movement.description,
                  ),
                  subtitle: Text(
                    '${formatDate(movement.date)}'
                    '\n${movement.paymentMethod}',
                  ),
                  trailing: Text(
                    '${movement.type == 'Pago' ? '-' : ''}${money(movement.amount)}',
                  ),
                ),
              ),

              if (current.balance >
                  0) ...[
                const Divider(),

                const Text(
                  'Registrar abono',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                TextField(
                  controller:
                      amountController,
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Valor del abono',
                    prefixText:
                        '\$ ',
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                DropdownButtonFormField<
                    String>(
                  value:
                      paymentMethod,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Forma de pago',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value:
                          'Efectivo',
                      child: Text(
                        '💵 Efectivo',
                      ),
                    ),
                    DropdownMenuItem(
                      value:
                          'Transferencia',
                      child: Text(
                        '🏦 Transferencia',
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value !=
                        null) {
                      setState(() {
                        paymentMethod =
                            value;
                      });
                    }
                  },
                ),

                const SizedBox(
                  height: 10,
                ),

                DateSelector(
                  title:
                      'Fecha del abono',
                  date: date,
                  onTap: () async {
                    final value =
                        await chooseDate(
                      context,
                      date,
                    );

                    if (value !=
                        null) {
                      setState(() {
                        date = value;
                      });
                    }
                  },
                ),

                const SizedBox(
                  height: 10,
                ),

                TextField(
                  controller:
                      noteController,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Observación (opcional)',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(
            context,
          ),
          child:
              const Text(
            'Cerrar',
          ),
        ),
        if (current.balance > 0)
          FilledButton.icon(
            onPressed: paying ? null : registerPayment,
            icon: const Icon(Icons.payments),
            label: Text(
              paying ? 'Registrando...' : 'Registrar abono',
            ),
          ),
      ],
    );
  }
}
