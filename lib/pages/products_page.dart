part of '../main.dart';

// ============================================================
// COMIDAS
// ============================================================

class ProductsPage extends StatelessWidget {
  const ProductsPage({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        return Scaffold(
          floatingActionButton:
              FloatingActionButton.extended(
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (_) =>
                    const ProductDialog(),
              );
            },
            icon: const Icon(
              Icons.add,
            ),
            label: const Text(
              'Nuevo producto',
            ),
          ),
          body: appStore.products.isEmpty
              ? const EmptyState(
                  icon: Icons.restaurant,
                  title: 'No hay productos',
                  subtitle:
                      'Registra comidas, bebidas y adicionales.',
                )
              : ListView(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    90,
                  ),
                  children: [
                    ProductSection(
                      title:
                          '☕ DESAYUNOS',
                      category:
                          'Desayuno',
                    ),
                    ProductSection(
                      title:
                          '🍛 ALMUERZOS COMPLETOS',
                      category:
                          'Almuerzo',
                    ),
                    ProductSection(
                      title:
                          '🍽️ PLATOS A LA CARTA',
                      category:
                          'Platos a la carta',
                    ),
                    ProductSection(
                      title:
                          '🥤 BEBIDAS / ADICIONALES',
                      category:
                          'Bebidas / Adicionales',
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class ProductSection
    extends StatelessWidget {
  final String title;
  final String category;

  const ProductSection({
    super.key,
    required this.title,
    required this.category,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final items =
        appStore.products
            .where(
              (product) =>
                  product.category ==
                  category,
            )
            .toList();

    if (items.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        ...items.map(
          (product) => Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  categoryEmoji(
                    product.category,
                  ),
                ),
              ),
              title: Text(
                product.name,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    product.available
                        ? '✅ Disponible'
                        : '⛔ No disponible',
                  ),
                  if (product.category ==
                      'Almuerzo') ...[
                    Text(
                      '🥣 ${product.soup}',
                    ),
                    Text(
                      '🍛 ${product.mainDish}',
                    ),
                    Text(
                      '🥤 ${product.drink}',
                    ),
                  ],
                ],
              ),
              trailing:
                  PopupMenuButton<String>(
                onSelected:
                    (value) async {
                  if (value ==
                      'editar') {
                    showDialog(
                      context: context,
                      builder: (_) =>
                          ProductDialog(
                        product:
                            product,
                      ),
                    );
                  }

                  if (value ==
                      'disponible') {
                    product.available =
                        !product.available;

                    await appStore
                        .updateProduct(
                      product,
                    );
                  }

                  if (value ==
                      'eliminar') {
                    if (!context
                        .mounted) {
                      return;
                    }

                    final result =
                        await askConfirmation(
                      context,
                      title:
                          'Eliminar producto',
                      message:
                          '¿Eliminar "${product.name}"?',
                    );

                    if (result) {
                      await appStore
                          .deleteProduct(
                        product,
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
                    value: 'disponible',
                    child: Text(
                      product.available
                          ? '⛔ Marcar no disponible'
                          : '✅ Marcar disponible',
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
            ),
          ),
        ),

        const SizedBox(height: 18),
      ],
    );
  }
}

class ProductDialog
    extends StatefulWidget {
  final FoodProduct? product;

  const ProductDialog({
    super.key,
    this.product,
  });

  @override
  State<ProductDialog>
      createState() =>
          _ProductDialogState();
}

class _ProductDialogState
    extends State<ProductDialog> {
  late final TextEditingController
      nameController;

  late final TextEditingController
      priceController;

  late final TextEditingController
      soupController;

  late final TextEditingController
      mainController;

  late final TextEditingController
      drinkController;

  String category = 'Almuerzo';

  bool available = true;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    nameController =
        TextEditingController(
      text: widget.product?.name ?? '',
    );

    priceController =
        TextEditingController(
      text: widget.product != null
          ? widget.product!.price
              .toStringAsFixed(2)
          : '',
    );

    soupController =
        TextEditingController(
      text: widget.product?.soup ?? '',
    );

    mainController =
        TextEditingController(
      text:
          widget.product?.mainDish ?? '',
    );

    drinkController =
        TextEditingController(
      text: widget.product?.drink ?? '',
    );

    category =
        widget.product?.category ??
            'Almuerzo';

    available =
        widget.product?.available ??
            true;
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    soupController.dispose();
    mainController.dispose();
    drinkController.dispose();

    super.dispose();
  }

  Future<void> save() async {
    final name =
        nameController.text.trim();

    final price = double.tryParse(
      priceController.text
          .replaceAll(',', '.'),
    );

    if (name.isEmpty ||
        price == null ||
        price <= 0) {
      showMessage(
        context,
        'Completa correctamente nombre y precio.',
      );

      return;
    }

    if (category == 'Almuerzo' &&
        (soupController.text
                .trim()
                .isEmpty ||
            mainController.text
                .trim()
                .isEmpty ||
            drinkController.text
                .trim()
                .isEmpty)) {
      showMessage(
        context,
        'Completa sopa, plato fuerte y bebida.',
      );

      return;
    }

    setState(() {
      saving = true;
    });

    if (widget.product == null) {
      await appStore.addProduct(
        name: name,
        category: category,
        price: price,
        available: available,
        soup: category == 'Almuerzo'
            ? soupController.text.trim()
            : '',
        mainDish:
            category == 'Almuerzo'
                ? mainController.text
                    .trim()
                : '',
        drink:
            category == 'Almuerzo'
                ? drinkController.text
                    .trim()
                : '',
      );
    } else {
      widget.product!
        ..name = name
        ..category = category
        ..price = price
        ..available = available
        ..soup =
            category == 'Almuerzo'
                ? soupController.text
                    .trim()
                : ''
        ..mainDish =
            category == 'Almuerzo'
                ? mainController.text
                    .trim()
                : ''
        ..drink =
            category == 'Almuerzo'
                ? drinkController.text
                    .trim()
                : '';

      await appStore.updateProduct(
        widget.product!,
      );
    }

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final isLunch =
        category == 'Almuerzo';

    return AlertDialog(
      title: Text(
        widget.product == null
            ? '🍽️ Nuevo producto'
            : '✏️ Editar producto',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              DropdownButtonFormField<
                  String>(
                value: category,
                isExpanded: true,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Categoría',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Desayuno',
                    child:
                        Text(
                      '☕ Desayuno',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Almuerzo',
                    child: Text(
                      '🍛 Almuerzo completo',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'Platos a la carta',
                    child: Text(
                      '🍽️ Plato a la carta',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'Bebidas / Adicionales',
                    child: Text(
                      '🥤 Bebidas / Adicionales',
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      category = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              TextField(
                controller:
                    nameController,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Nombre',
                ),
              ),

              if (isLunch) ...[
                const SizedBox(
                  height: 12,
                ),
                TextField(
                  controller:
                      soupController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Sopa',
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                TextField(
                  controller:
                      mainController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Plato fuerte',
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                TextField(
                  controller:
                      drinkController,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Bebida incluida',
                  ),
                ),
              ],

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
                      'Precio de venta',
                  prefixText: '\$ ',
                ),
              ),

              SwitchListTile(
                contentPadding:
                    EdgeInsets.zero,
                title: const Text(
                  'Disponible para venta',
                ),
                value: available,
                onChanged: (value) {
                  setState(() {
                    available = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving
              ? null
              : () =>
                  Navigator.pop(
                    context,
                  ),
          child:
              const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              saving ? null : save,
          child: Text(
            saving
                ? 'Guardando...'
                : 'Guardar',
          ),
        ),
      ],
    );
  }
}
