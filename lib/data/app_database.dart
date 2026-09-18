part of '../main.dart';

// ============================================================
// BASE DE DATOS SQLITE
// Archivo separado para mantener SQLite organizado.
// ============================================================

class AppDatabase {
  Database? _db;

  // Almacenamiento temporal para las pruebas en Flutter Web.
  // Está separado de SQLite y no se utiliza en la APK Android.
  final WebMemoryService webMemory = WebMemoryService();

  Database get db {
    if (_db == null) {
      throw Exception('La base de datos no está inicializada.');
    }

    return _db!;
  }

  static const int _databaseVersion = 2;

  Future<void> init() async {
    final databasePath = await getDatabasesPath();
    final path = p.join(databasePath, 'control_comedor.db');

    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _migrateDatabase(db, oldVersion, newVersion);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        price REAL NOT NULL,
        available INTEGER NOT NULL,
        soup TEXT NOT NULL DEFAULT '',
        main_dish TEXT NOT NULL DEFAULT '',
        drink TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_method TEXT NOT NULL,
        person TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        category TEXT NOT NULL,
        unit_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        soup TEXT NOT NULL DEFAULT '',
        main_dish TEXT NOT NULL DEFAULT '',
        drink TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(sale_id) REFERENCES sales(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider TEXT NOT NULL DEFAULT '',
        payment_method TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE expense_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_id INTEGER NOT NULL,
        description TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        unit_price REAL NOT NULL,
        FOREIGN KEY(expense_id) REFERENCES expenses(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE receivable_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        sale_id INTEGER,
        payment_method TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE payable_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        expense_id INTEGER,
        payment_method TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_catalog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        unit TEXT NOT NULL,
        last_price REAL NOT NULL
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expense_items_expense_id ON expense_items(expense_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_receivable_person_date ON receivable_movements(person, date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_receivable_sale_id ON receivable_movements(sale_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_payable_provider_date ON payable_movements(provider, date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_payable_expense_id ON payable_movements(expense_id)');
  }

  Future<void> _migrateDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Cada cambio futuro de estructura se agrega aquí, en orden.
    // No se borran las tablas ni los datos existentes.
    if (oldVersion < 2) {
      // v1 -> v2: solo añadimos índices para mejorar las consultas.
      await _createIndexes(db);
    }

    // Ejemplo futuro:
    // if (oldVersion < 3) {
    //   await db.execute(
    //     "ALTER TABLE sales ADD COLUMN nuevo_campo TEXT NOT NULL DEFAULT ''",
    //   );
    // }
  }

  // ==========================================================
  // PRODUCTOS
  // ==========================================================

  Future<List<FoodProduct>> loadProducts() async {
    if (kIsWeb) {
      final items = List<FoodProduct>.from(webMemory.products);
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    }
    final rows = await db.query(
      'products',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map(
          (row) => FoodProduct.fromMap(row),
        )
        .toList();
  }

  Future<int> insertProduct(
    FoodProduct product,
  ) async {
    if (kIsWeb) {
      product.id = ++webMemory.productId;
      webMemory.products.add(product);
      return product.id;
    }
    return db.insert(
      'products',
      product.toMapWithoutId(),
    );
  }

  Future<void> updateProduct(
    FoodProduct product,
  ) async {
    if (kIsWeb) {
      final i = webMemory.products.indexWhere((e) => e.id == product.id);
      if (i >= 0) webMemory.products[i] = product;
      return;
    }
    await db.update(
      'products',
      product.toMapWithoutId(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(
    int id,
  ) async {
    if (kIsWeb) {
      webMemory.products.removeWhere((e) => e.id == id);
      return;
    }
    await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================================
  // VENTAS
  // ==========================================================

  Future<List<Sale>> loadSales() async {
    if (kIsWeb) {
      final items = List<Sale>.from(webMemory.sales);
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    }
    final saleRows = await db.query(
      'sales',
      orderBy: 'date DESC, id DESC',
    );

    final result = <Sale>[];

    for (final row in saleRows) {
      final id = row['id'] as int;

      final itemRows = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [id],
      );

      result.add(
        Sale.fromMap(
          row,
          itemRows
              .map(
                (item) =>
                    SaleItem.fromMap(item),
              )
              .toList(),
        ),
      );
    }

    return result;
  }

  Future<int> insertSale(
    Sale sale,
  ) async {
    if (kIsWeb) {
      sale.id = ++webMemory.saleId;
      webMemory.sales.add(sale);
      if (sale.paymentMethod == 'Fiado') {
        webMemory.receivables.add(ReceivableMovement(
          id: ++webMemory.receivableId, person: sale.person, type: 'Venta',
          description: 'Venta #${sale.id}', amount: sale.total, date: sale.date,
          saleId: sale.id, paymentMethod: 'Fiado', note: sale.note,
        ));
      }
      return sale.id;
    }
    return db.transaction(
      (txn) async {
        final saleId = await txn.insert(
          'sales',
          sale.toMapWithoutId(),
        );

        for (final item in sale.items) {
          await txn.insert(
            'sale_items',
            item.toMap(
              saleId: saleId,
            ),
          );
        }

        if (sale.paymentMethod ==
            'Fiado') {
          await txn.insert(
            'receivable_movements',
            {
              'person': sale.person,
              'type': 'Venta',
              'description':
                  'Venta #$saleId',
              'amount': sale.total,
              'date':
                  sale.date.toIso8601String(),
              'sale_id': saleId,
              'payment_method':
                  'Fiado',
              'note': sale.note,
            },
          );
        }

        return saleId;
      },
    );
  }

  Future<void> updateSale(
    Sale sale,
  ) async {
    if (kIsWeb) {
      final i = webMemory.sales.indexWhere((e) => e.id == sale.id);
      if (i >= 0) webMemory.sales[i] = sale;
      webMemory.receivables.removeWhere((m) => m.saleId == sale.id && m.type == 'Venta');
      if (sale.paymentMethod == 'Fiado') {
        webMemory.receivables.add(ReceivableMovement(
          id: ++webMemory.receivableId, person: sale.person, type: 'Venta',
          description: 'Venta #${sale.id}', amount: sale.total, date: sale.date,
          saleId: sale.id, paymentMethod: 'Fiado', note: sale.note,
        ));
      }
      return;
    }
    await db.transaction(
      (txn) async {
        await txn.update(
          'sales',
          sale.toMapWithoutId(),
          where: 'id = ?',
          whereArgs: [sale.id],
        );

        await txn.delete(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [sale.id],
        );

        for (final item in sale.items) {
          await txn.insert(
            'sale_items',
            item.toMap(
              saleId: sale.id,
            ),
          );
        }

        await txn.delete(
          'receivable_movements',
          where:
              'sale_id = ? AND type = ?',
          whereArgs: [
            sale.id,
            'Venta',
          ],
        );

        if (sale.paymentMethod ==
            'Fiado') {
          await txn.insert(
            'receivable_movements',
            {
              'person': sale.person,
              'type': 'Venta',
              'description':
                  'Venta #${sale.id}',
              'amount': sale.total,
              'date':
                  sale.date.toIso8601String(),
              'sale_id': sale.id,
              'payment_method':
                  'Fiado',
              'note': sale.note,
            },
          );
        }
      },
    );
  }

  Future<void> deleteSale(
    int saleId,
  ) async {
    if (kIsWeb) {
      webMemory.sales.removeWhere((e) => e.id == saleId);
      webMemory.receivables.removeWhere((m) => m.saleId == saleId && m.type == 'Venta');
      return;
    }
    await db.transaction(
      (txn) async {
        await txn.delete(
          'receivable_movements',
          where:
              'sale_id = ? AND type = ?',
          whereArgs: [
            saleId,
            'Venta',
          ],
        );

        await txn.delete(
          'sales',
          where: 'id = ?',
          whereArgs: [saleId],
        );
      },
    );
  }

  // ==========================================================
  // GASTOS
  // ==========================================================

  Future<List<Expense>> loadExpenses() async {
    if (kIsWeb) {
      final items = List<Expense>.from(webMemory.expenses);
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    }
    final expenseRows =
        await db.query(
      'expenses',
      orderBy: 'date DESC, id DESC',
    );

    final result = <Expense>[];

    for (final row in expenseRows) {
      final id = row['id'] as int;

      final items = await db.query(
        'expense_items',
        where: 'expense_id = ?',
        whereArgs: [id],
      );

      result.add(
        Expense.fromMap(
          row,
          items
              .map(
                (item) =>
                    PurchaseItem.fromMap(
                  item,
                ),
              )
              .toList(),
        ),
      );
    }

    return result;
  }

  Future<int> insertExpense(
    Expense expense,
  ) async {
    if (kIsWeb) {
      expense.id = ++webMemory.expenseId;
      webMemory.expenses.add(expense);
      for (final item in expense.items) {
        final i = webMemory.catalog.indexWhere((e) => e.name.toLowerCase() == item.description.toLowerCase());
        final template = PurchaseTemplate(id: i >= 0 ? webMemory.catalog[i].id : ++webMemory.catalogId, name: item.description, unit: item.unit, lastPrice: item.unitPrice);
        if (i >= 0) { webMemory.catalog[i] = template; } else { webMemory.catalog.add(template); }
      }
      if (expense.paymentMethod == 'Fiado') {
        webMemory.payables.add(PayableMovement(
          id: ++webMemory.payableId, provider: expense.provider, type: 'Compra',
          description: 'Compra #${expense.id}', amount: expense.total, date: expense.date,
          expenseId: expense.id, paymentMethod: 'Fiado', note: expense.note,
        ));
      }
      return expense.id;
    }
    return db.transaction(
      (txn) async {
        final expenseId =
            await txn.insert(
          'expenses',
          expense.toMapWithoutId(),
        );

        for (final item
            in expense.items) {
          await txn.insert(
            'expense_items',
            item.toMap(
              expenseId: expenseId,
            ),
          );

          await txn.rawInsert(
            '''
            INSERT INTO purchase_catalog
            (name, unit, last_price)
            VALUES (?, ?, ?)
            ON CONFLICT(name)
            DO UPDATE SET
              unit = excluded.unit,
              last_price = excluded.last_price
            ''',
            [
              item.description,
              item.unit,
              item.unitPrice,
            ],
          );
        }

        if (expense.paymentMethod ==
            'Fiado') {
          await txn.insert(
            'payable_movements',
            {
              'provider':
                  expense.provider,
              'type': 'Compra',
              'description':
                  'Compra #$expenseId',
              'amount': expense.total,
              'date': expense.date
                  .toIso8601String(),
              'expense_id': expenseId,
              'payment_method':
                  'Fiado',
              'note': expense.note,
            },
          );
        }

        return expenseId;
      },
    );
  }

  Future<void> updateExpense(
    Expense expense,
  ) async {
    if (kIsWeb) {
      final i = webMemory.expenses.indexWhere((e) => e.id == expense.id);
      if (i >= 0) webMemory.expenses[i] = expense;
      for (final item in expense.items) {
        final c = webMemory.catalog.indexWhere((e) => e.name.toLowerCase() == item.description.toLowerCase());
        final template = PurchaseTemplate(id: c >= 0 ? webMemory.catalog[c].id : ++webMemory.catalogId, name: item.description, unit: item.unit, lastPrice: item.unitPrice);
        if (c >= 0) { webMemory.catalog[c] = template; } else { webMemory.catalog.add(template); }
      }
      webMemory.payables.removeWhere((m) => m.expenseId == expense.id && m.type == 'Compra');
      if (expense.paymentMethod == 'Fiado') {
        webMemory.payables.add(PayableMovement(
          id: ++webMemory.payableId, provider: expense.provider, type: 'Compra',
          description: 'Compra #${expense.id}', amount: expense.total, date: expense.date,
          expenseId: expense.id, paymentMethod: 'Fiado', note: expense.note,
        ));
      }
      return;
    }
    await db.transaction(
      (txn) async {
        await txn.update(
          'expenses',
          expense.toMapWithoutId(),
          where: 'id = ?',
          whereArgs: [expense.id],
        );

        await txn.delete(
          'expense_items',
          where: 'expense_id = ?',
          whereArgs: [expense.id],
        );

        for (final item
            in expense.items) {
          await txn.insert(
            'expense_items',
            item.toMap(
              expenseId: expense.id,
            ),
          );

          await txn.rawInsert(
            '''
            INSERT INTO purchase_catalog
            (name, unit, last_price)
            VALUES (?, ?, ?)
            ON CONFLICT(name)
            DO UPDATE SET
              unit = excluded.unit,
              last_price = excluded.last_price
            ''',
            [
              item.description,
              item.unit,
              item.unitPrice,
            ],
          );
        }

        await txn.delete(
          'payable_movements',
          where:
              'expense_id = ? AND type = ?',
          whereArgs: [
            expense.id,
            'Compra',
          ],
        );

        if (expense.paymentMethod ==
            'Fiado') {
          await txn.insert(
            'payable_movements',
            {
              'provider':
                  expense.provider,
              'type': 'Compra',
              'description':
                  'Compra #${expense.id}',
              'amount': expense.total,
              'date': expense.date
                  .toIso8601String(),
              'expense_id':
                  expense.id,
              'payment_method':
                  'Fiado',
              'note': expense.note,
            },
          );
        }
      },
    );
  }

  Future<void> deleteExpense(
    int expenseId,
  ) async {
    if (kIsWeb) {
      webMemory.expenses.removeWhere((e) => e.id == expenseId);
      webMemory.payables.removeWhere((m) => m.expenseId == expenseId && m.type == 'Compra');
      return;
    }
    await db.transaction(
      (txn) async {
        await txn.delete(
          'payable_movements',
          where:
              'expense_id = ? AND type = ?',
          whereArgs: [
            expenseId,
            'Compra',
          ],
        );

        await txn.delete(
          'expenses',
          where: 'id = ?',
          whereArgs: [expenseId],
        );
      },
    );
  }

  // ==========================================================
  // POR COBRAR
  // ==========================================================

  Future<List<ReceivableMovement>>
      loadReceivableMovements() async {
    if (kIsWeb) {
      final items = List<ReceivableMovement>.from(webMemory.receivables);
      items.sort((a, b) => a.date.compareTo(b.date));
      return items;
    }
    final rows = await db.query(
      'receivable_movements',
      orderBy: 'date ASC, id ASC',
    );

    return rows
        .map(
          (row) =>
              ReceivableMovement.fromMap(
            row,
          ),
        )
        .toList();
  }

  Future<void> insertCustomerPayment({
    required String person,
    required double amount,
    required String paymentMethod,
    required DateTime date,
    required String note,
  }) async {
    if (kIsWeb) {
      webMemory.receivables.add(ReceivableMovement(
        id: ++webMemory.receivableId,
        person: person,
        type: 'Pago',
        description: 'Pago recibido',
        amount: amount,
        date: date,
        saleId: null,
        paymentMethod: paymentMethod,
        note: note,
      ));
      return;
    }
    await db.insert('receivable_movements', {
      'person': person, 'type': 'Pago', 'description': 'Pago recibido',
      'amount': amount, 'date': date.toIso8601String(), 'sale_id': null,
      'payment_method': paymentMethod, 'note': note,
    });
  }

  // ==========================================================
  // POR PAGAR
  // ==========================================================

  Future<List<PayableMovement>>
      loadPayableMovements() async {
    if (kIsWeb) {
      final items = List<PayableMovement>.from(webMemory.payables);
      items.sort((a, b) => a.date.compareTo(b.date));
      return items;
    }
    final rows = await db.query(
      'payable_movements',
      orderBy: 'date ASC, id ASC',
    );

    return rows
        .map(
          (row) =>
              PayableMovement.fromMap(
            row,
          ),
        )
        .toList();
  }

  Future<void> insertProviderPayment({
    required String provider,
    required double amount,
    required String paymentMethod,
    required DateTime date,
    required String note,
  }) async {
    if (kIsWeb) {
      webMemory.payables.add(PayableMovement(
        id: ++webMemory.payableId,
        provider: provider,
        type: 'Pago',
        description: 'Abono al proveedor',
        amount: amount,
        date: date,
        expenseId: null,
        paymentMethod: paymentMethod,
        note: note,
      ));
      return;
    }
    await db.insert('payable_movements', {
      'provider': provider, 'type': 'Pago', 'description': 'Abono al proveedor',
      'amount': amount, 'date': date.toIso8601String(), 'expense_id': null,
      'payment_method': paymentMethod, 'note': note,
    });
  }

  // ==========================================================
  // CATÁLOGO
  // ==========================================================

  Future<List<PurchaseTemplate>>
      loadPurchaseCatalog() async {
    if (kIsWeb) {
      final items = List<PurchaseTemplate>.from(webMemory.catalog);
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    }
    final rows = await db.query(
      'purchase_catalog',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map(
          (row) =>
              PurchaseTemplate.fromMap(
            row,
          ),
        )
        .toList();
  }
}
