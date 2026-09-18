part of '../main.dart';

// ============================================================
// VENTAS
// ============================================================

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});
  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  String viewMode = 'Ventas';
  String statusFilter = 'Todas';
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
      builder: (context, _) {
        final sales = appStore.sales.where((sale) {
          if (statusFilter != 'Todas' && sale.status != statusFilter) return false;
          if (paymentFilter != 'Todas' && sale.paymentMethod != paymentFilter) return false;
          if (startDate != null && sale.date.isBefore(DateTime(startDate!.year, startDate!.month, startDate!.day))) return false;
          if (endDate != null && sale.date.isAfter(DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59))) return false;
          if (search.isEmpty) return true;
          return sale.person.toLowerCase().contains(search) || sale.items.any((i) => i.productName.toLowerCase().contains(search));
        }).toList()..sort((a,b) => b.date.compareTo(a.date));

        final accounts = appStore.receivables.where((a) {
          if (accountFilter == 'Pendientes' && a.balance <= 0) return false;
          if (accountFilter == 'Pagados' && a.balance > 0) return false;
          if (search.isNotEmpty && !a.person.toLowerCase().contains(search)) return false;

          final creditSales = appStore.sales.where((sale) {
            if (sale.paymentMethod != 'Fiado') return false;
            if (sale.person.trim().toLowerCase() != a.person.trim().toLowerCase()) return false;
            if (startDate != null && sale.date.isBefore(DateTime(startDate!.year, startDate!.month, startDate!.day))) return false;
            if (endDate != null && sale.date.isAfter(DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59))) return false;
            return true;
          }).toList();

          if ((startDate != null || endDate != null) && creditSales.isEmpty) return false;
          return true;
        }).toList()..sort((a,b) => (b.lastMovementDate ?? DateTime(2000)).compareTo(a.lastMovementDate ?? DateTime(2000)));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16,16,16,80),
          children: [
            FilledButton.icon(
              onPressed: () {
                if (!appStore.products.any((p) => p.available)) {
                  showMessage(context, 'Primero registra productos disponibles.');
                  return;
                }
                showDialog(context: context, barrierDismissible: false, builder: (_) => const SaleDialog());
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Crear nueva venta'),
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value:'Ventas', icon:Icon(Icons.receipt_long), label:Text('Ventas')),
                ButtonSegment(value:'Cuentas', icon:Icon(Icons.people), label:Text('Cuentas por cobrar')),
              ],
              selected: {viewMode},
              onSelectionChanged: (v) => setState(() { viewMode = v.first; search = ''; }),
            ),
            const SizedBox(height: 14),
            if (viewMode == 'Ventas') ...[
              Row(children:[
                Expanded(child: OutlinedButton.icon(onPressed: pickStart, icon: const Icon(Icons.calendar_today), label: Text(startDate == null ? 'Desde' : formatDate(startDate!)))),
                const SizedBox(width:8),
                Expanded(child: OutlinedButton.icon(onPressed: pickEnd, icon: const Icon(Icons.event_available), label: Text(endDate == null ? 'Hasta' : formatDate(endDate!)))),
              ]),
              if (startDate != null || endDate != null) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: ()=>setState(() {startDate=null; endDate=null;}), icon: const Icon(Icons.clear), label: const Text('Limpiar fechas'))),
              DropdownButtonFormField<String>(
                initialValue: paymentFilter,
                decoration: const InputDecoration(labelText:'Forma de pago', prefixIcon:Icon(Icons.payments)),
                items: const [
                  DropdownMenuItem(value:'Todas', child:Text('Todas')),
                  DropdownMenuItem(value:'Efectivo', child:Text('💵 Efectivo')),
                  DropdownMenuItem(value:'Transferencia', child:Text('🏦 Transferencia')),
                  DropdownMenuItem(value:'Fiado', child:Text('📝 Fiado')),
                ],
                onChanged:(v){ if(v!=null) setState(()=>paymentFilter=v); },
              ),
              const SizedBox(height:12),
              TextField(decoration: const InputDecoration(labelText:'Buscar venta', hintText:'Cliente o producto...', prefixIcon:Icon(Icons.search)), onChanged:(v)=>setState(()=>search=v.trim().toLowerCase())),
              const SizedBox(height:12),
              Wrap(spacing:8, children:[
                ChoiceChip(selected:statusFilter=='Todas', label:const Text('Todas'), onSelected:(_)=>setState(()=>statusFilter='Todas')),
                ChoiceChip(selected:statusFilter=='Abierta', label:const Text('🟠 Abiertas'), onSelected:(_)=>setState(()=>statusFilter='Abierta')),
                ChoiceChip(selected:statusFilter=='Cerrada', label:const Text('✅ Cerradas'), onSelected:(_)=>setState(()=>statusFilter='Cerrada')),
              ]),
              const SizedBox(height:14),
              if (sales.isEmpty) const EmptyState(icon:Icons.search_off, title:'No se encontraron ventas', subtitle:'Registra una venta o cambia los filtros.'),
              ...sales.map((sale)=>SaleOrderCard(sale:sale)),
            ] else ...[
              Row(children:[
                Expanded(child: OutlinedButton.icon(onPressed: pickStart, icon: const Icon(Icons.calendar_today), label: Text(startDate == null ? 'Desde' : formatDate(startDate!)))),
                const SizedBox(width:8),
                Expanded(child: OutlinedButton.icon(onPressed: pickEnd, icon: const Icon(Icons.event_available), label: Text(endDate == null ? 'Hasta' : formatDate(endDate!)))),
              ]),
              if (startDate != null || endDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: ()=>setState(() {startDate=null; endDate=null;}),
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpiar fechas'),
                  ),
                ),
              Wrap(spacing:8, children:[
                ChoiceChip(selected:accountFilter=='Todos', label:const Text('Todos'), onSelected:(_)=>setState(()=>accountFilter='Todos')),
                ChoiceChip(selected:accountFilter=='Pendientes', label:const Text('🔴 Por cobrar'), onSelected:(_)=>setState(()=>accountFilter='Pendientes')),
                ChoiceChip(selected:accountFilter=='Pagados', label:const Text('✅ Pagados'), onSelected:(_)=>setState(()=>accountFilter='Pagados')),
              ]),
              const SizedBox(height:12),
              TextField(decoration: const InputDecoration(labelText:'Buscar cliente', hintText:'Nombre del cliente...', prefixIcon:Icon(Icons.search)), onChanged:(v)=>setState(()=>search=v.trim().toLowerCase())),
              const SizedBox(height:14),
              if (accounts.isEmpty) const EmptyState(icon:Icons.people_outline, title:'No hay cuentas', subtitle:'No hay ventas fiadas que coincidan con los filtros.'),
              ...accounts.map((a) {
                final creditSales = appStore.sales.where((sale) {
                  if (sale.paymentMethod != 'Fiado') return false;
                  if (sale.person.trim().toLowerCase() != a.person.trim().toLowerCase()) return false;
                  if (startDate != null && sale.date.isBefore(DateTime(startDate!.year, startDate!.month, startDate!.day))) return false;
                  if (endDate != null && sale.date.isAfter(DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59))) return false;
                  return true;
                }).toList()..sort((x,y)=>y.date.compareTo(x.date));
                return SalesReceivableAccountCard(account:a, creditSales:creditSales);
              }),
            ],
          ],
        );
      },
    );
  }
}


class SalesReceivableAccountCard extends StatefulWidget {
  final ReceivableAccount account;
  final List<Sale> creditSales;

  const SalesReceivableAccountCard({
    super.key,
    required this.account,
    this.creditSales = const [],
  });

  @override
  State<SalesReceivableAccountCard> createState() =>
      _SalesReceivableAccountCardState();
}

class _SalesReceivableAccountCardState
    extends State<SalesReceivableAccountCard> {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.person,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Consumido: ${money(account.charged)}'),
                      Text('Pagado: ${money(account.paid)}'),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      pending ? 'Por cobrar' : 'Pagado',
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
            if (widget.creditSales.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => showDetails = !showDetails),
                icon: Icon(
                  showDetails ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(
                  showDetails
                      ? 'Ocultar detalle de ventas'
                      : 'Ver detalle de ventas',
                ),
              ),
              if (showDetails) ...[
                const Divider(),
                ...widget.creditSales.map(
                  (sale) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🧾 Pedido #${sale.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text('📅 ${formatDate(sale.date)}'),
                        const SizedBox(height: 7),
                        ...sale.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(
                              left: 8,
                              bottom: 4,
                            ),
                            child: Text(
                              '${item.quantity} × ${item.productName} = ${money(item.total)}',
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
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) =>
                          CustomerAccountDialog(account: account),
                    ),
                    icon: const Icon(Icons.payments),
                    label: const Text('Registrar pago'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SaleOrderCard
    extends StatelessWidget {
  final Sale sale;

  const SaleOrderCard({
    super.key,
    required this.sale,
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
                    '🧾 Pedido #${sale.id}',
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  money(sale.total),
                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Text(
              '📅 ${formatDate(sale.date)}',
            ),

            if (sale.person.isNotEmpty)
              Text(
                '👤 ${sale.person}',
              ),

            Text(
              '${paymentIcon(sale.paymentMethod)} ${sale.paymentMethod}',
            ),

            const Divider(),

            ...sale.items.map(
              (item) => Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 4,
                ),
                child: Text(
                  '${item.quantity} × ${item.productName} '
                  '= ${money(item.total)}',
                ),
              ),
            ),

            const SizedBox(height: 7),

            Row(
              children: [
                StatusBadge(
                  text: sale.status,
                  positive:
                      sale.status ==
                          'Cerrada',
                ),
                const Spacer(),
                PopupMenuButton<
                    String>(
                  onSelected:
                      (value) async {
                    if (value ==
                        'editar') {
                      showDialog(
                        context: context,
                        barrierDismissible:
                            false,
                        builder: (_) =>
                            SaleDialog(
                          sale: sale,
                        ),
                      );
                    }

                    if (value ==
                        'estado') {
                      final newStatus =
                          sale.status ==
                                  'Abierta'
                              ? 'Cerrada'
                              : 'Abierta';

                      await appStore
                          .changeSaleStatus(
                        sale,
                        newStatus,
                      );
                    }

                    if (value ==
                        'eliminar') {
                      final confirm =
                          await askConfirmation(
                        context,
                        title:
                            'Eliminar venta',
                        message:
                            '¿Eliminar la venta #${sale.id}?',
                      );

                      if (!confirm) {
                        return;
                      }

                      final error =
                          await appStore
                              .deleteSale(
                        sale,
                      );

                      if (error != null &&
                          context
                              .mounted) {
                        showMessage(
                          context,
                          error,
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'editar',
                      child: Text(
                        '✏️ Editar',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'estado',
                      child: Text(
                        sale.status ==
                                'Abierta'
                            ? '✅ Cerrar pedido'
                            : '🟠 Reabrir pedido',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: Text(
                        '🗑️ Eliminar',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SaleDialog
    extends StatefulWidget {
  final Sale? sale;

  const SaleDialog({
    super.key,
    this.sale,
  });

  @override
  State<SaleDialog> createState() =>
      _SaleDialogState();
}

class _SaleDialogState
    extends State<SaleDialog> {
  final List<SaleItem> orderItems =
      [];

  FoodProduct? selectedProduct;

  int addQuantity = 1;

  late final TextEditingController
      personController;

  late final TextEditingController
      noteController;

  String paymentMethod =
      'Efectivo';

  String status = 'Abierta';

  late DateTime selectedDate;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    selectedDate =
        widget.sale?.date ??
            DateTime.now();

    personController =
        TextEditingController(
      text: widget.sale?.person ?? '',
    );

    noteController =
        TextEditingController(
      text: widget.sale?.note ?? '',
    );

    if (widget.sale != null) {
      orderItems.addAll(
        widget.sale!.items.map(
          (item) => item.copy(),
        ),
      );

      paymentMethod =
          widget.sale!.paymentMethod;

      status = widget.sale!.status;
    }

    final available =
        appStore.products
            .where(
              (product) =>
                  product.available,
            )
            .toList();

    if (available.isNotEmpty) {
      selectedProduct =
          available.first;
    }
  }

  @override
  void dispose() {
    personController.dispose();
    noteController.dispose();

    super.dispose();
  }

  double get orderTotal {
    return orderItems.fold<double>(
      0,
      (sum, item) =>
          sum + item.total,
    );
  }

  void addProduct() {
    final product =
        selectedProduct;

    if (product == null) {
      return;
    }

    for (final item in orderItems) {
      if (item.productId ==
              product.id &&
          item.unitPrice ==
              product.price) {
        setState(() {
          item.quantity +=
              addQuantity;

          addQuantity = 1;
        });

        return;
      }
    }

    setState(() {
      orderItems.add(
        SaleItem(
          productId: product.id,
          productName:
              product.name,
          category:
              product.category,
          unitPrice:
              product.price,
          quantity: addQuantity,
          soup: product.soup,
          mainDish:
              product.mainDish,
          drink:
              product.drink,
        ),
      );

      addQuantity = 1;
    });
  }

  Future<void> saveSale() async {
    if (saving) {
      return;
    }

    if (orderItems.isEmpty) {
      showMessage(
        context,
        'Agrega productos al pedido.',
      );

      return;
    }

    if (orderItems.any((item) =>
        item.quantity <= 0 ||
        item.unitPrice <= 0)) {
      showMessage(
        context,
        'Todos los productos deben tener cantidad y precio mayores a cero.',
      );
      return;
    }

    if (paymentMethod == 'Fiado' &&
        personController.text.trim().isEmpty) {
      showMessage(
        context,
        'Si la venta es fiada debes ingresar el nombre del cliente.',
      );
      return;
    }

    setState(() {
      saving = true;
    });

    String? error;

    if (widget.sale == null) {
      error =
          await appStore.addSale(
        items: orderItems,
        paymentMethod:
            paymentMethod,
        person:
            personController.text,
        date: selectedDate,
        status: status,
        note:
            noteController.text,
      );
    } else {
      error =
          await appStore.updateSale(
        sale: widget.sale!,
        items: orderItems,
        paymentMethod:
            paymentMethod,
        person:
            personController.text,
        date: selectedDate,
        status: status,
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
    final available =
        appStore.products
            .where(
              (product) =>
                  product.available,
            )
            .toList();

    return AlertDialog(
      title: Text(
        widget.sale == null
            ? '🧾 Nuevo pedido'
            : '✏️ Editar venta #${widget.sale!.id}',
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
                    'Fecha de venta',
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

              DropdownButtonFormField<
                  FoodProduct>(
                value: selectedProduct,
                isExpanded: true,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Producto',
                ),
                items: available
                    .map(
                      (product) =>
                          DropdownMenuItem(
                        value: product,
                        child: Text(
                          '${categoryEmoji(product.category)} '
                          '${product.name} - ${money(product.price)}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedProduct =
                        value;
                  });
                },
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  IconButton(
                    onPressed:
                        addQuantity > 1
                            ? () {
                                setState(
                                  () {
                                    addQuantity--;
                                  },
                                );
                              }
                            : null,
                    icon: const Icon(
                      Icons.remove_circle_outline,
                    ),
                  ),
                  Text(
                    '$addQuantity',
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        addQuantity++;
                      });
                    },
                    icon: const Icon(
                      Icons.add_circle_outline,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed:
                        selectedProduct ==
                                null
                            ? null
                            : addProduct,
                    icon:
                        const Icon(
                      Icons.add,
                    ),
                    label:
                        const Text(
                      'Agregar',
                    ),
                  ),
                ],
              ),

              const Divider(),

              if (orderItems.isEmpty)
                const Padding(
                  padding:
                      EdgeInsets.all(
                    16,
                  ),
                  child: Text(
                    'Todavía no has agregado productos.',
                  ),
                ),

              ...orderItems
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
                        item.productName,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${item.quantity} × ${money(item.unitPrice)}'
                        '\nSubtotal: ${money(item.total)}',
                      ),
                      trailing: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (item
                                        .quantity >
                                    1) {
                                  item.quantity--;
                                } else {
                                  orderItems
                                      .removeAt(
                                    index,
                                  );
                                }
                              });
                            },
                            icon:
                                const Icon(
                              Icons.remove,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                item.quantity++;
                              });
                            },
                            icon:
                                const Icon(
                              Icons.add,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                orderItems
                                    .removeAt(
                                  index,
                                );
                              });
                            },
                            icon:
                                const Icon(
                              Icons.delete_outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              TotalBox(
                title:
                    'TOTAL DEL PEDIDO',
                value: orderTotal,
                subtitle:
                    '${orderItems.fold<int>(0, (sum, item) => sum + item.quantity)} productos',
              ),

              const SizedBox(height: 12),

              TextField(
                controller:
                    personController,
                decoration:
                    InputDecoration(
                  labelText:
                      'Cliente / Referencia',
                  hintText:
                      paymentMethod ==
                              'Fiado'
                          ? 'Obligatorio si es fiado'
                          : 'Opcional',
                  prefixIcon:
                      const Icon(
                    Icons.person,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<
                  String>(
                value:
                    paymentMethod,
                isExpanded: true,
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

              DropdownButtonFormField<
                  String>(
                value: status,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Estado',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Abierta',
                    child: Text(
                      '🟠 Abierta',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Cerrada',
                    child: Text(
                      '✅ Cerrada',
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      status = value;
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
                      '⚠️ Esta venta quedará por cobrar: ${money(orderTotal)}',
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
                  : saveSale,
          icon:
              const Icon(
            Icons.save,
          ),
          label: Text(
            saving
                ? 'Guardando...'
                : 'Guardar venta',
          ),
        ),
      ],
    );
  }
}
