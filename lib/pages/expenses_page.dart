part of '../main.dart';

// ============================================================
// GASTOS
// ============================================================

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});
  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  String viewMode = 'Gastos';
  String paymentFilter = 'Todas';
  String accountFilter = 'Todos';
  String search = '';
  DateTime? startDate;
  DateTime? endDate;

  Future<void> pickStart() async {
    final d = await showDatePicker(context: context, initialDate: startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => startDate = d);
  }
  Future<void> pickEnd() async {
    final d = await showDatePicker(context: context, initialDate: endDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => endDate = d);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appStore,
      builder:(context,_) {
        final expenses = appStore.expenses.where((e) {
          if (paymentFilter != 'Todas' && e.paymentMethod != paymentFilter) return false;
          if (startDate != null && e.date.isBefore(DateTime(startDate!.year,startDate!.month,startDate!.day))) return false;
          if (endDate != null && e.date.isAfter(DateTime(endDate!.year,endDate!.month,endDate!.day,23,59,59))) return false;
          if (search.isEmpty) return true;
          return e.provider.toLowerCase().contains(search) || e.items.any((i)=>i.description.toLowerCase().contains(search));
        }).toList()..sort((a,b)=>b.date.compareTo(a.date));

        final accounts = appStore.payables.where((a) {
          if (accountFilter == 'Pendientes' && a.balance <= 0) return false;
          if (accountFilter == 'Pagados' && a.balance > 0) return false;
          return search.isEmpty || a.provider.toLowerCase().contains(search);
        }).toList()..sort((a,b)=>(b.lastMovementDate ?? DateTime(2000)).compareTo(a.lastMovementDate ?? DateTime(2000)));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16,16,16,80),
          children:[
            FilledButton.icon(
              onPressed:()=>showDialog(context:context, barrierDismissible:false, builder:(_)=>const ExpenseDialog()),
              icon:const Icon(Icons.add_shopping_cart),
              label:const Text('Registrar nueva compra'),
            ),
            const SizedBox(height:14),
            SegmentedButton<String>(
              segments:const[
                ButtonSegment(value:'Gastos', icon:Icon(Icons.shopping_cart), label:Text('Gastos')),
                ButtonSegment(value:'Cuentas', icon:Icon(Icons.store), label:Text('Cuentas por pagar')),
              ],
              selected:{viewMode},
              onSelectionChanged:(v)=>setState(() {viewMode=v.first; search='';}),
            ),
            const SizedBox(height:14),
            if(viewMode=='Gastos') ...[
              Row(children:[
                Expanded(child:OutlinedButton.icon(onPressed:pickStart, icon:const Icon(Icons.calendar_today), label:Text(startDate==null?'Desde':formatDate(startDate!)))),
                const SizedBox(width:8),
                Expanded(child:OutlinedButton.icon(onPressed:pickEnd, icon:const Icon(Icons.event_available), label:Text(endDate==null?'Hasta':formatDate(endDate!)))),
              ]),
              if(startDate!=null || endDate!=null) Align(alignment:Alignment.centerRight, child:TextButton.icon(onPressed:()=>setState(() {startDate=null;endDate=null;}), icon:const Icon(Icons.clear), label:const Text('Limpiar fechas'))),
              DropdownButtonFormField<String>(
                initialValue:paymentFilter,
                decoration:const InputDecoration(labelText:'Forma de pago', prefixIcon:Icon(Icons.payments)),
                items:const[
                  DropdownMenuItem(value:'Todas', child:Text('Todas')),
                  DropdownMenuItem(value:'Efectivo', child:Text('💵 Efectivo')),
                  DropdownMenuItem(value:'Transferencia', child:Text('🏦 Transferencia')),
                  DropdownMenuItem(value:'Fiado', child:Text('📝 Fiado')),
                ],
                onChanged:(v){if(v!=null)setState(()=>paymentFilter=v);},
              ),
              const SizedBox(height:12),
              TextField(decoration:const InputDecoration(labelText:'Buscar gasto', hintText:'Proveedor o insumo...', prefixIcon:Icon(Icons.search)), onChanged:(v)=>setState(()=>search=v.trim().toLowerCase())),
              const SizedBox(height:14),
              if(expenses.isEmpty) const EmptyState(icon:Icons.search_off, title:'No se encontraron gastos', subtitle:'Registra una compra o cambia los filtros.'),
              ...expenses.map((e)=>ExpenseCard(expense:e)),
            ] else ...[
              Wrap(spacing:8, children:[
                ChoiceChip(selected:accountFilter=='Todos', label:const Text('Todos'), onSelected:(_)=>setState(()=>accountFilter='Todos')),
                ChoiceChip(selected:accountFilter=='Pendientes', label:const Text('🔴 Por pagar'), onSelected:(_)=>setState(()=>accountFilter='Pendientes')),
                ChoiceChip(selected:accountFilter=='Pagados', label:const Text('✅ Pagados'), onSelected:(_)=>setState(()=>accountFilter='Pagados')),
              ]),
              const SizedBox(height:12),
              TextField(decoration:const InputDecoration(labelText:'Buscar proveedor', prefixIcon:Icon(Icons.search)), onChanged:(v)=>setState(()=>search=v.trim().toLowerCase())),
              const SizedBox(height:14),
              if(accounts.isEmpty) const EmptyState(icon:Icons.store_outlined, title:'No hay cuentas', subtitle:'Las compras fiadas aparecerán aquí.'),
              ...accounts.map((a) {
                final creditExpenses = appStore.expenses.where((expense) {
                  if (expense.paymentMethod != 'Fiado') return false;
                  if (expense.provider.trim().toLowerCase() !=
                      a.provider.trim().toLowerCase()) {
                    return false;
                  }
                  return true;
                }).toList()
                  ..sort((x, y) => y.date.compareTo(x.date));

                return ExpensesPayableAccountCard(
                  account: a,
                  creditExpenses: creditExpenses,
                );
              }),
            ],
          ],
        );
      },
    );
  }
}


class ExpensesPayableAccountCard extends StatefulWidget {
  final PayableAccount account;
  final List<Expense> creditExpenses;

  const ExpensesPayableAccountCard({
    super.key,
    required this.account,
    this.creditExpenses = const [],
  });

  @override
  State<ExpensesPayableAccountCard> createState() =>
      _ExpensesPayableAccountCardState();
}

class _ExpensesPayableAccountCardState
    extends State<ExpensesPayableAccountCard> {
  bool showDetails = true;

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final pending = account.balance > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '👤',
                  style: TextStyle(fontSize: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    account.provider,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      pending ? 'Por pagar' : 'Pagado',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: pending ? Colors.red : Colors.green,
                      ),
                    ),
                    Text(
                      money(pending ? account.balance : 0),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: pending ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (widget.creditExpenses.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => showDetails = !showDetails),
                icon: Icon(
                  showDetails ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(
                  showDetails
                      ? 'Ocultar detalle de compras'
                      : 'Ver detalle de compras',
                ),
              ),
              if (showDetails) ...[
                const Divider(),
                ...widget.creditExpenses.map(
                  (expense) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🛒 Compra #${expense.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text('📅 ${formatDate(expense.date)}'),
                        const SizedBox(height: 7),
                        ...expense.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(
                              left: 8,
                              bottom: 4,
                            ),
                            child: Text(
                              '${formatQuantity(item.quantity)} ${item.unit} × '
                              '${item.description} = ${money(item.total)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) =>
                      ProviderAccountDialog(account: account),
                ),
                icon: const Icon(Icons.payments),
                label: const Text('Registrar abono'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpenseCard
    extends StatelessWidget {
  final Expense expense;

  const ExpenseCard({
    super.key,
    required this.expense,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '🛒 Compra #${expense.id}',
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  money(expense.total),
                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            Text(
              '📅 ${formatDate(expense.date)}',
            ),

            if (expense
                .provider.isNotEmpty)
              Text(
                '🏪 ${expense.provider}',
              ),

            Text(
              '${paymentIcon(expense.paymentMethod)} ${expense.paymentMethod}',
            ),

            const Divider(),

            ...expense.items.map(
              (item) => Text(
                '${formatQuantity(item.quantity)} ${item.unit} '
                '• ${item.description}\n'
                '${money(item.unitPrice)} c/u = ${money(item.total)}',
              ),
            ),

            Align(
              alignment:
                  Alignment.centerRight,
              child:
                  PopupMenuButton<String>(
                onSelected:
                    (value) async {
                  if (value ==
                      'editar') {
                    showDialog(
                      context: context,
                      barrierDismissible:
                          false,
                      builder: (_) =>
                          ExpenseDialog(
                        expense:
                            expense,
                      ),
                    );
                  }

                  if (value ==
                      'eliminar') {
                    final confirm =
                        await askConfirmation(
                      context,
                      title:
                          'Eliminar compra',
                      message:
                          '¿Eliminar la compra #${expense.id}?',
                    );

                    if (!confirm) {
                      return;
                    }

                    final error =
                        await appStore
                            .deleteExpense(
                      expense,
                    );

                    if (error != null &&
                        context.mounted) {
                      showMessage(
                        context,
                        error,
                      );
                    }
                  }
                },
                itemBuilder: (_) =>
                    const [
                  PopupMenuItem(
                    value: 'editar',
                    child: Text(
                      '✏️ Editar',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'eliminar',
                    child: Text(
                      '🗑️ Eliminar',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpenseDialog
    extends StatefulWidget {
  final Expense? expense;

  const ExpenseDialog({
    super.key,
    this.expense,
  });

  @override
  State<ExpenseDialog>
      createState() =>
          _ExpenseDialogState();
}

class _ExpenseDialogState
    extends State<ExpenseDialog> {
  final List<PurchaseItem>
      purchaseItems = [];

  late final TextEditingController
      providerController;

  late final TextEditingController
      noteController;

  String paymentMethod =
      'Efectivo';

  late DateTime selectedDate;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    providerController =
        TextEditingController(
      text:
          widget.expense?.provider ??
              '',
    );

    noteController =
        TextEditingController(
      text:
          widget.expense?.note ?? '',
    );

    selectedDate =
        widget.expense?.date ??
            DateTime.now();

    if (widget.expense != null) {
      paymentMethod =
          widget.expense!
              .paymentMethod;

      purchaseItems.addAll(
        widget.expense!.items.map(
          (item) => item.copy(),
        ),
      );
    }
  }

  @override
  void dispose() {
    providerController.dispose();
    noteController.dispose();

    super.dispose();
  }

  double get total {
    return purchaseItems.fold<double>(
      0,
      (sum, item) =>
          sum + item.total,
    );
  }

  Future<void> saveExpense() async {
    if (saving) {
      return;
    }

    if (purchaseItems.isEmpty) {
      showMessage(
        context,
        'Agrega productos a la compra.',
      );

      return;
    }

    if (purchaseItems.any((item) =>
        item.quantity <= 0 ||
        item.unitPrice <= 0)) {
      showMessage(
        context,
        'Todos los productos de la compra deben tener cantidad y precio mayores a cero.',
      );
      return;
    }

    if (paymentMethod == 'Fiado' &&
        providerController.text.trim().isEmpty) {
      showMessage(
        context,
        'Si la compra es fiada debes ingresar el proveedor.',
      );
      return;
    }

    setState(() {
      saving = true;
    });

    String? error;

    if (widget.expense == null) {
      error =
          await appStore.addExpense(
        items: purchaseItems,
        provider:
            providerController.text,
        paymentMethod:
            paymentMethod,
        date: selectedDate,
        note:
            noteController.text,
      );
    } else {
      error =
          await appStore.updateExpense(
        expense:
            widget.expense!,
        items: purchaseItems,
        provider:
            providerController.text,
        paymentMethod:
            paymentMethod,
        date: selectedDate,
        note:
            noteController.text,
      );
    }

    if (!mounted) {
      return;
    }

    if (error != null) {
      setState(() {
        saving = false;
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
    return AlertDialog(
      title: Text(
        widget.expense == null
            ? '🛒 Nueva compra'
            : '✏️ Editar compra #${widget.expense!.id}',
      ),
      content: SizedBox(
        width: 600,
        child:
            SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              DateSelector(
                title:
                    'Fecha de la compra',
                date: selectedDate,
                onTap: () async {
                  final value =
                      await chooseDate(
                    context,
                    selectedDate,
                  );

                  if (value != null) {
                    setState(() {
                      selectedDate =
                          value;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              TextField(
                controller:
                    providerController,
                decoration:
                    InputDecoration(
                  labelText:
                      'Proveedor / Persona',
                  hintText:
                      paymentMethod ==
                              'Fiado'
                          ? 'Obligatorio si queda por pagar'
                          : 'Opcional',
                  prefixIcon:
                      const Icon(
                    Icons.store,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width:
                    double.infinity,
                child:
                    FilledButton.tonalIcon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) =>
                          PurchaseItemDialog(
                        onSave:
                            (item) {
                          setState(() {
                            purchaseItems
                                .add(
                              item,
                            );
                          });
                        },
                      ),
                    );
                  },
                  icon:
                      const Icon(
                    Icons.add,
                  ),
                  label:
                      const Text(
                    'Agregar producto comprado',
                  ),
                ),
              ),

              if (appStore
                  .purchaseCatalog
                  .isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 6,
                  ),
                  child: Text(
                    '💡 Se recuerdan ${appStore.purchaseCatalog.length} insumos usados anteriormente.',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Colors.grey.shade600,
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              if (purchaseItems.isEmpty)
                const Padding(
                  padding:
                      EdgeInsets.all(
                    14,
                  ),
                  child: Text(
                    'Todavía no has agregado productos.',
                  ),
                ),

              ...purchaseItems
                  .asMap()
                  .entries
                  .map(
                (entry) {
                  final index =
                      entry.key;

                  final item =
                      entry.value;

                  return Card(
                    child: ListTile(
                      title: Text(
                        item.description,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${formatQuantity(item.quantity)} '
                        '${item.unit} × '
                        '${money(item.unitPrice)}'
                        '\nSubtotal: ${money(item.total)}',
                      ),
                      trailing:
                          IconButton(
                        icon:
                            const Icon(
                          Icons.delete_outline,
                        ),
                        onPressed: () {
                          setState(() {
                            purchaseItems
                                .removeAt(
                              index,
                            );
                          });
                        },
                      ),
                    ),
                  );
                },
              ),

              TotalBox(
                title:
                    'TOTAL DE LA COMPRA',
                value: total,
                subtitle:
                    '${purchaseItems.length} productos diferentes',
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<
                  String>(
                value:
                    paymentMethod,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Forma de pago',
                  prefixIcon:
                      Icon(
                    Icons.payments,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Efectivo',
                    child:
                        Text(
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
                  DropdownMenuItem(
                    value: 'Fiado',
                    child:
                        Text(
                      '📝 Fiado',
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      paymentMethod =
                          value;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              TextField(
                controller:
                    noteController,
                maxLines: 2,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Observación (opcional)',
                  prefixIcon:
                      Icon(Icons.notes),
                ),
              ),

              if (paymentMethod ==
                  'Fiado') ...[
                const SizedBox(
                  height: 10,
                ),
                InfoBox(
                  text:
                      '⚠️ Esta compra quedará por pagar: ${money(total)}',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              saving
                  ? null
                  : () =>
                      Navigator.pop(
                        context,
                      ),
          child:
              const Text(
            'Cancelar',
          ),
        ),
        FilledButton.icon(
          onPressed:
              saving
                  ? null
                  : saveExpense,
          icon:
              const Icon(
            Icons.save,
          ),
          label: Text(
            saving
                ? 'Guardando...'
                : 'Guardar compra',
          ),
        ),
      ],
    );
  }
}

class PurchaseItemDialog
    extends StatefulWidget {
  final void Function(
    PurchaseItem item,
  ) onSave;

  const PurchaseItemDialog({
    super.key,
    required this.onSave,
  });

  @override
  State<PurchaseItemDialog>
      createState() =>
          _PurchaseItemDialogState();
}

class _PurchaseItemDialogState
    extends State<PurchaseItemDialog> {
  final descriptionController =
      TextEditingController();

  final quantityController =
      TextEditingController();

  final priceController =
      TextEditingController();

  String unit = 'Libras';

  final units = const [
    'Libras',
    'Kilogramos',
    'Unidades',
    'Litros',
    'Quintales',
    'Sacos',
    'Cajas',
    'Paquetes',
    'Atados',
    'Docenas',
    'Cubetas',
    'Galones',
    'Otros',
  ];

  @override
  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    priceController.dispose();

    super.dispose();
  }

  void selectTemplate(
    PurchaseTemplate template,
  ) {
    descriptionController.text =
        template.name;

    priceController.text =
        template.lastPrice
            .toStringAsFixed(2);

    setState(() {
      unit = template.unit;
    });
  }

  void save() {
    final description =
        descriptionController.text
            .trim();

    final quantity =
        double.tryParse(
      quantityController.text
          .replaceAll(',', '.'),
    );

    final price =
        double.tryParse(
      priceController.text
          .replaceAll(',', '.'),
    );

    if (description.isEmpty ||
        quantity == null ||
        quantity <= 0 ||
        price == null ||
        price <= 0) {
      showMessage(
        context,
        'Completa correctamente los datos.',
      );

      return;
    }

    widget.onSave(
      PurchaseItem(
        description: description,
        quantity: quantity,
        unit: unit,
        unitPrice: price,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title:
          const Text(
        '📦 Agregar producto',
      ),
      content: SizedBox(
        width: 460,
        child:
            SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              if (appStore
                  .purchaseCatalog
                  .isNotEmpty)
                DropdownButtonFormField<
                    PurchaseTemplate>(
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Usar insumo anterior (opcional)',
                  ),
                  isExpanded: true,
                  items: appStore
                      .purchaseCatalog
                      .map(
                        (template) =>
                            DropdownMenuItem(
                          value:
                              template,
                          child: Text(
                            template.name,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      selectTemplate(
                        value,
                      );
                    }
                  },
                ),

              if (appStore
                  .purchaseCatalog
                  .isNotEmpty)
                const SizedBox(
                  height: 12,
                ),

              TextField(
                controller:
                    descriptionController,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Producto / Insumo',
                  hintText:
                      'Ej: Pollo',
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          quantityController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Cantidad',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child:
                        DropdownButtonFormField<
                            String>(
                      value: unit,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Unidad',
                      ),
                      items: units
                          .map(
                            (value) =>
                                DropdownMenuItem(
                              value:
                                  value,
                              child:
                                  Text(
                                value,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged:
                          (value) {
                        if (value !=
                            null) {
                          setState(() {
                            unit =
                                value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              TextField(
                controller:
                    priceController,
                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal: true,
                ),
                decoration:
                    const InputDecoration(
                  labelText:
                      'Precio por unidad',
                  prefixText:
                      '\$ ',
                  helperText:
                      'Ej: 3 Libras × \$1.00 = \$3.00',
                ),
              ),
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
            'Cancelar',
          ),
        ),
        FilledButton(
          onPressed: save,
          child:
              const Text(
            'Agregar',
          ),
        ),
      ],
    );
  }
}
