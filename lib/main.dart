import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await database.init();
  await appStore.loadData();

  runApp(const ComedorApp());
}

final AppDatabase database = AppDatabase();
final AppStore appStore = AppStore();

// ============================================================
// BASE DE DATOS SQLITE
// ============================================================

class AppDatabase {
  Database? _db;

  Database get db {
    if (_db == null) {
      throw Exception('La base de datos no está inicializada.');
    }

    return _db!;
  }

  Future<void> init() async {
    final databasePath = await getDatabasesPath();

    final path = p.join(
      databasePath,
      'control_comedor.db',
    );

    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute(
          'PRAGMA foreign_keys = ON',
        );
      },
      onCreate: (db, version) async {
        // ====================================================
        // PRODUCTOS
        // ====================================================

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

        // ====================================================
        // VENTAS
        // ====================================================

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
            FOREIGN KEY(sale_id)
              REFERENCES sales(id)
              ON DELETE CASCADE
          )
        ''');

        // ====================================================
        // GASTOS / COMPRAS
        // ====================================================

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
            FOREIGN KEY(expense_id)
              REFERENCES expenses(id)
              ON DELETE CASCADE
          )
        ''');

        // ====================================================
        // MOVIMIENTOS POR COBRAR
        // ====================================================

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

        // ====================================================
        // MOVIMIENTOS POR PAGAR
        // ====================================================

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

        // ====================================================
        // CATÁLOGO DE INSUMOS
        // ====================================================

        await db.execute('''
          CREATE TABLE purchase_catalog (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE,
            unit TEXT NOT NULL,
            last_price REAL NOT NULL
          )
        ''');
      },
    );
  }

  // ==========================================================
  // PRODUCTOS
  // ==========================================================

  Future<List<FoodProduct>> loadProducts() async {
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
    return db.insert(
      'products',
      product.toMapWithoutId(),
    );
  }

  Future<void> updateProduct(
    FoodProduct product,
  ) async {
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
    await db.insert(
      'receivable_movements',
      {
        'person': person,
        'type': 'Pago',
        'description':
            'Pago recibido',
        'amount': amount,
        'date':
            date.toIso8601String(),
        'sale_id': null,
        'payment_method':
            paymentMethod,
        'note': note,
      },
    );
  }

  // ==========================================================
  // POR PAGAR
  // ==========================================================

  Future<List<PayableMovement>>
      loadPayableMovements() async {
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
    await db.insert(
      'payable_movements',
      {
        'provider': provider,
        'type': 'Pago',
        'description':
            'Abono al proveedor',
        'amount': amount,
        'date':
            date.toIso8601String(),
        'expense_id': null,
        'payment_method':
            paymentMethod,
        'note': note,
      },
    );
  }

  // ==========================================================
  // CATÁLOGO
  // ==========================================================

  Future<List<PurchaseTemplate>>
      loadPurchaseCatalog() async {
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

// ============================================================
// MODELOS
// ============================================================

class FoodProduct {
  int id;

  String name;
  String category;

  double price;

  bool available;

  String soup;
  String mainDish;
  String drink;

  FoodProduct({
    this.id = 0,
    required this.name,
    required this.category,
    required this.price,
    required this.available,
    this.soup = '',
    this.mainDish = '',
    this.drink = '',
  });

  Map<String, Object?> toMapWithoutId() {
    return {
      'name': name,
      'category': category,
      'price': price,
      'available': available ? 1 : 0,
      'soup': soup,
      'main_dish': mainDish,
      'drink': drink,
    };
  }

  factory FoodProduct.fromMap(
    Map<String, Object?> map,
  ) {
    return FoodProduct(
      id: map['id'] as int,
      name: map['name'] as String,
      category:
          map['category'] as String,
      price:
          (map['price'] as num)
              .toDouble(),
      available:
          (map['available'] as int) == 1,
      soup:
          map['soup'] as String? ?? '',
      mainDish:
          map['main_dish']
                  as String? ??
              '',
      drink:
          map['drink'] as String? ?? '',
    );
  }
}

class SaleItem {
  int productId;

  String productName;
  String category;

  double unitPrice;

  int quantity;

  String soup;
  String mainDish;
  String drink;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.category,
    required this.unitPrice,
    required this.quantity,
    this.soup = '',
    this.mainDish = '',
    this.drink = '',
  });

  double get total =>
      unitPrice * quantity;

  SaleItem copy() {
    return SaleItem(
      productId: productId,
      productName: productName,
      category: category,
      unitPrice: unitPrice,
      quantity: quantity,
      soup: soup,
      mainDish: mainDish,
      drink: drink,
    );
  }

  Map<String, Object?> toMap({
    required int saleId,
  }) {
    return {
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'category': category,
      'unit_price': unitPrice,
      'quantity': quantity,
      'soup': soup,
      'main_dish': mainDish,
      'drink': drink,
    };
  }

  factory SaleItem.fromMap(
    Map<String, Object?> map,
  ) {
    return SaleItem(
      productId:
          map['product_id'] as int,
      productName:
          map['product_name']
              as String,
      category:
          map['category'] as String,
      unitPrice:
          (map['unit_price'] as num)
              .toDouble(),
      quantity:
          map['quantity'] as int,
      soup:
          map['soup'] as String? ?? '',
      mainDish:
          map['main_dish']
                  as String? ??
              '',
      drink:
          map['drink'] as String? ?? '',
    );
  }
}

class Sale {
  int id;

  List<SaleItem> items;

  String paymentMethod;
  String person;

  DateTime date;

  String status;
  String note;

  Sale({
    this.id = 0,
    required this.items,
    required this.paymentMethod,
    required this.person,
    required this.date,
    required this.status,
    required this.note,
  });

  double get total {
    return items.fold<double>(
      0,
      (sum, item) =>
          sum + item.total,
    );
  }

  int get totalItems {
    return items.fold<int>(
      0,
      (sum, item) =>
          sum + item.quantity,
    );
  }

  Map<String, Object?>
      toMapWithoutId() {
    return {
      'payment_method':
          paymentMethod,
      'person': person,
      'date':
          date.toIso8601String(),
      'status': status,
      'note': note,
    };
  }

  factory Sale.fromMap(
    Map<String, Object?> map,
    List<SaleItem> items,
  ) {
    return Sale(
      id: map['id'] as int,
      items: items,
      paymentMethod:
          map['payment_method']
              as String,
      person:
          map['person'] as String? ??
              '',
      date: DateTime.parse(
        map['date'] as String,
      ),
      status:
          map['status'] as String,
      note:
          map['note'] as String? ?? '',
    );
  }
}

class PurchaseItem {
  String description;

  double quantity;

  String unit;

  double unitPrice;

  PurchaseItem({
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
  });

  double get total =>
      quantity * unitPrice;

  PurchaseItem copy() {
    return PurchaseItem(
      description: description,
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
    );
  }

  Map<String, Object?> toMap({
    required int expenseId,
  }) {
    return {
      'expense_id': expenseId,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
    };
  }

  factory PurchaseItem.fromMap(
    Map<String, Object?> map,
  ) {
    return PurchaseItem(
      description:
          map['description'] as String,
      quantity:
          (map['quantity'] as num)
              .toDouble(),
      unit: map['unit'] as String,
      unitPrice:
          (map['unit_price'] as num)
              .toDouble(),
    );
  }
}

class Expense {
  int id;

  List<PurchaseItem> items;

  String provider;
  String paymentMethod;

  DateTime date;

  String note;

  Expense({
    this.id = 0,
    required this.items,
    required this.provider,
    required this.paymentMethod,
    required this.date,
    required this.note,
  });

  double get total {
    return items.fold<double>(
      0,
      (sum, item) =>
          sum + item.total,
    );
  }

  Map<String, Object?>
      toMapWithoutId() {
    return {
      'provider': provider,
      'payment_method':
          paymentMethod,
      'date':
          date.toIso8601String(),
      'note': note,
    };
  }

  factory Expense.fromMap(
    Map<String, Object?> map,
    List<PurchaseItem> items,
  ) {
    return Expense(
      id: map['id'] as int,
      items: items,
      provider:
          map['provider'] as String? ??
              '',
      paymentMethod:
          map['payment_method']
              as String,
      date: DateTime.parse(
        map['date'] as String,
      ),
      note:
          map['note'] as String? ?? '',
    );
  }
}

class ReceivableMovement {
  int id;

  String person;
  String type;
  String description;

  double amount;

  DateTime date;

  int? saleId;

  String paymentMethod;
  String note;

  ReceivableMovement({
    required this.id,
    required this.person,
    required this.type,
    required this.description,
    required this.amount,
    required this.date,
    required this.saleId,
    required this.paymentMethod,
    required this.note,
  });

  factory ReceivableMovement.fromMap(
    Map<String, Object?> map,
  ) {
    return ReceivableMovement(
      id: map['id'] as int,
      person:
          map['person'] as String,
      type: map['type'] as String,
      description:
          map['description'] as String,
      amount:
          (map['amount'] as num)
              .toDouble(),
      date: DateTime.parse(
        map['date'] as String,
      ),
      saleId:
          map['sale_id'] as int?,
      paymentMethod:
          map['payment_method']
              as String,
      note:
          map['note'] as String? ?? '',
    );
  }
}

class PayableMovement {
  int id;

  String provider;
  String type;
  String description;

  double amount;

  DateTime date;

  int? expenseId;

  String paymentMethod;
  String note;

  PayableMovement({
    required this.id,
    required this.provider,
    required this.type,
    required this.description,
    required this.amount,
    required this.date,
    required this.expenseId,
    required this.paymentMethod,
    required this.note,
  });

  factory PayableMovement.fromMap(
    Map<String, Object?> map,
  ) {
    return PayableMovement(
      id: map['id'] as int,
      provider:
          map['provider'] as String,
      type: map['type'] as String,
      description:
          map['description'] as String,
      amount:
          (map['amount'] as num)
              .toDouble(),
      date: DateTime.parse(
        map['date'] as String,
      ),
      expenseId:
          map['expense_id'] as int?,
      paymentMethod:
          map['payment_method']
              as String,
      note:
          map['note'] as String? ?? '',
    );
  }
}

class PurchaseTemplate {
  int id;

  String name;
  String unit;

  double lastPrice;

  PurchaseTemplate({
    required this.id,
    required this.name,
    required this.unit,
    required this.lastPrice,
  });

  factory PurchaseTemplate.fromMap(
    Map<String, Object?> map,
  ) {
    return PurchaseTemplate(
      id: map['id'] as int,
      name: map['name'] as String,
      unit: map['unit'] as String,
      lastPrice:
          (map['last_price'] as num)
              .toDouble(),
    );
  }
}

// ============================================================
// CUENTAS CALCULADAS
// ============================================================

class ReceivableAccount {
  final String person;

  final List<ReceivableMovement>
      movements;

  ReceivableAccount({
    required this.person,
    required this.movements,
  });

  double get charged {
    return movements
        .where(
          (m) => m.type == 'Venta',
        )
        .fold<double>(
          0,
          (sum, m) =>
              sum + m.amount,
        );
  }

  double get paid {
    return movements
        .where(
          (m) => m.type == 'Pago',
        )
        .fold<double>(
          0,
          (sum, m) =>
              sum + m.amount,
        );
  }

  double get balance =>
      charged - paid;

  DateTime? get lastMovementDate {
    if (movements.isEmpty) {
      return null;
    }

    DateTime latest =
        movements.first.date;

    for (final movement
        in movements) {
      if (movement.date.isAfter(
        latest,
      )) {
        latest = movement.date;
      }
    }

    return latest;
  }
}

class PayableAccount {
  final String provider;

  final List<PayableMovement>
      movements;

  PayableAccount({
    required this.provider,
    required this.movements,
  });

  double get purchased {
    return movements
        .where(
          (m) => m.type == 'Compra',
        )
        .fold<double>(
          0,
          (sum, m) =>
              sum + m.amount,
        );
  }

  double get paid {
    return movements
        .where(
          (m) => m.type == 'Pago',
        )
        .fold<double>(
          0,
          (sum, m) =>
              sum + m.amount,
        );
  }

  double get balance =>
      purchased - paid;

  DateTime? get lastMovementDate {
    if (movements.isEmpty) {
      return null;
    }

    DateTime latest =
        movements.first.date;

    for (final movement
        in movements) {
      if (movement.date.isAfter(
        latest,
      )) {
        latest = movement.date;
      }
    }

    return latest;
  }
}

// ============================================================
// APP STORE
// ============================================================

class AppStore extends ChangeNotifier {
  List<FoodProduct> products = [];
  List<Sale> sales = [];
  List<Expense> expenses = [];

  List<ReceivableMovement>
      receivableMovements = [];

  List<PayableMovement>
      payableMovements = [];

  List<PurchaseTemplate>
      purchaseCatalog = [];

  Future<void> loadData() async {
    products =
        await database.loadProducts();

    sales =
        await database.loadSales();

    expenses =
        await database.loadExpenses();

    receivableMovements =
        await database
            .loadReceivableMovements();

    payableMovements =
        await database
            .loadPayableMovements();

    purchaseCatalog =
        await database
            .loadPurchaseCatalog();

    notifyListeners();
  }

  // ==========================================================
  // PRODUCTOS
  // ==========================================================

  Future<void> addProduct({
    required String name,
    required String category,
    required double price,
    required bool available,
    String soup = '',
    String mainDish = '',
    String drink = '',
  }) async {
    final product = FoodProduct(
      name: name.trim(),
      category: category,
      price: price,
      available: available,
      soup: soup.trim(),
      mainDish: mainDish.trim(),
      drink: drink.trim(),
    );

    product.id =
        await database.insertProduct(
      product,
    );

    products.add(product);

    products.sort(
      (a, b) => a.name
          .toLowerCase()
          .compareTo(
            b.name.toLowerCase(),
          ),
    );

    notifyListeners();
  }

  Future<void> updateProduct(
    FoodProduct product,
  ) async {
    await database.updateProduct(
      product,
    );

    notifyListeners();
  }

  Future<void> deleteProduct(
    FoodProduct product,
  ) async {
    await database.deleteProduct(
      product.id,
    );

    products.removeWhere(
      (p) => p.id == product.id,
    );

    notifyListeners();
  }

  // ==========================================================
  // VENTAS
  // ==========================================================

  Future<String?> addSale({
    required List<SaleItem> items,
    required String paymentMethod,
    required String person,
    required DateTime date,
    required String status,
    required String note,
  }) async {
    final customer = person.trim();

    if (paymentMethod == 'Fiado' &&
        customer.isEmpty) {
      return 'Si la venta es fiada debes ingresar el nombre del cliente.';
    }

    final sale = Sale(
      items:
          items.map((e) => e.copy()).toList(),
      paymentMethod: paymentMethod,
      person: customer,
      date: date,
      status: status,
      note: note.trim(),
    );

    sale.id =
        await database.insertSale(
      sale,
    );

    await loadData();

    return null;
  }

  Future<String?> updateSale({
    required Sale sale,
    required List<SaleItem> items,
    required String paymentMethod,
    required String person,
    required DateTime date,
    required String status,
    required String note,
  }) async {
    final newPerson =
        person.trim();

    if (paymentMethod == 'Fiado' &&
        newPerson.isEmpty) {
      return 'Si la venta es fiada debes ingresar el nombre del cliente.';
    }

    final newTotal =
        items.fold<double>(
      0,
      (sum, item) =>
          sum + item.total,
    );

    if (sale.paymentMethod ==
        'Fiado') {
      final oldAccount =
          findReceivable(
        sale.person,
      );

      if (oldAccount != null) {
        final otherCharges =
            oldAccount.movements
                .where(
                  (movement) =>
                      movement.type ==
                          'Venta' &&
                      movement.saleId !=
                          sale.id,
                )
                .fold<double>(
                  0,
                  (sum, movement) =>
                      sum +
                      movement.amount,
                );

        final payments =
            oldAccount.paid;

        final sameCustomer =
            paymentMethod == 'Fiado' &&
            newPerson.toLowerCase() ==
                sale.person
                    .toLowerCase();

        final futureCharges =
            sameCustomer
                ? otherCharges +
                    newTotal
                : otherCharges;

        if (futureCharges + 0.0001 <
            payments) {
          return 'No puedes modificar esta venta porque los pagos registrados superarían el saldo de la cuenta.';
        }
      }
    }

    sale
      ..items = items
          .map((e) => e.copy())
          .toList()
      ..paymentMethod =
          paymentMethod
      ..person = newPerson
      ..date = date
      ..status = status
      ..note = note.trim();

    await database.updateSale(
      sale,
    );

    await loadData();

    return null;
  }

  Future<String?> deleteSale(
    Sale sale,
  ) async {
    if (sale.paymentMethod ==
        'Fiado') {
      final account =
          findReceivable(
        sale.person,
      );

      if (account != null) {
        final otherCharges =
            account.movements
                .where(
                  (movement) =>
                      movement.type ==
                          'Venta' &&
                      movement.saleId !=
                          sale.id,
                )
                .fold<double>(
                  0,
                  (sum, movement) =>
                      sum +
                      movement.amount,
                );

        if (otherCharges + 0.0001 <
            account.paid) {
          return 'No puedes eliminar esta venta porque existen pagos registrados en la cuenta del cliente.';
        }
      }
    }

    await database.deleteSale(
      sale.id,
    );

    await loadData();

    return null;
  }

  Future<void> changeSaleStatus(
    Sale sale,
    String status,
  ) async {
    sale.status = status;

    await database.updateSale(
      sale,
    );

    await loadData();
  }

  // ==========================================================
  // GASTOS
  // ==========================================================

  Future<String?> addExpense({
    required List<PurchaseItem> items,
    required String provider,
    required String paymentMethod,
    required DateTime date,
    required String note,
  }) async {
    final supplier =
        provider.trim();

    if (paymentMethod == 'Fiado' &&
        supplier.isEmpty) {
      return 'Si la compra es fiada debes ingresar el proveedor.';
    }

    final expense = Expense(
      items:
          items.map((e) => e.copy()).toList(),
      provider: supplier,
      paymentMethod: paymentMethod,
      date: date,
      note: note.trim(),
    );

    expense.id =
        await database.insertExpense(
      expense,
    );

    await loadData();

    return null;
  }

  Future<String?> updateExpense({
    required Expense expense,
    required List<PurchaseItem> items,
    required String provider,
    required String paymentMethod,
    required DateTime date,
    required String note,
  }) async {
    final newProvider =
        provider.trim();

    if (paymentMethod == 'Fiado' &&
        newProvider.isEmpty) {
      return 'Si la compra es fiada debes ingresar el proveedor.';
    }

    final newTotal =
        items.fold<double>(
      0,
      (sum, item) =>
          sum + item.total,
    );

    if (expense.paymentMethod ==
        'Fiado') {
      final oldAccount =
          findPayable(
        expense.provider,
      );

      if (oldAccount != null) {
        final otherCharges =
            oldAccount.movements
                .where(
                  (movement) =>
                      movement.type ==
                          'Compra' &&
                      movement.expenseId !=
                          expense.id,
                )
                .fold<double>(
                  0,
                  (sum, movement) =>
                      sum +
                      movement.amount,
                );

        final payments =
            oldAccount.paid;

        final sameProvider =
            paymentMethod == 'Fiado' &&
            newProvider.toLowerCase() ==
                expense.provider
                    .toLowerCase();

        final futureCharges =
            sameProvider
                ? otherCharges +
                    newTotal
                : otherCharges;

        if (futureCharges + 0.0001 <
            payments) {
          return 'No puedes modificar esta compra porque los abonos registrados superarían el saldo restante.';
        }
      }
    }

    expense
      ..items = items
          .map((e) => e.copy())
          .toList()
      ..provider = newProvider
      ..paymentMethod =
          paymentMethod
      ..date = date
      ..note = note.trim();

    await database.updateExpense(
      expense,
    );

    await loadData();

    return null;
  }

  Future<String?> deleteExpense(
    Expense expense,
  ) async {
    if (expense.paymentMethod ==
        'Fiado') {
      final account =
          findPayable(
        expense.provider,
      );

      if (account != null) {
        final otherCharges =
            account.movements
                .where(
                  (movement) =>
                      movement.type ==
                          'Compra' &&
                      movement.expenseId !=
                          expense.id,
                )
                .fold<double>(
                  0,
                  (sum, movement) =>
                      sum +
                      movement.amount,
                );

        if (otherCharges + 0.0001 <
            account.paid) {
          return 'No puedes eliminar esta compra porque existen abonos registrados en la cuenta del proveedor.';
        }
      }
    }

    await database.deleteExpense(
      expense.id,
    );

    await loadData();

    return null;
  }

  // ==========================================================
  // CUENTAS POR COBRAR
  // ==========================================================

  List<ReceivableAccount>
      get receivables {
    final map =
        <String, List<ReceivableMovement>>{};

    for (final movement
        in receivableMovements) {
      final key =
          movement.person
              .trim()
              .toLowerCase();

      map.putIfAbsent(
        key,
        () => [],
      );

      map[key]!.add(movement);
    }

    return map.entries.map(
      (entry) {
        return ReceivableAccount(
          person:
              entry.value.first.person,
          movements: entry.value,
        );
      },
    ).toList();
  }

  ReceivableAccount? findReceivable(
    String person,
  ) {
    final search =
        person.trim().toLowerCase();

    if (search.isEmpty) {
      return null;
    }

    for (final account
        in receivables) {
      if (account.person
              .toLowerCase() ==
          search) {
        return account;
      }
    }

    return null;
  }

  Future<String?> registerCustomerPayment({
    required ReceivableAccount account,
    required double amount,
    required String paymentMethod,
    required DateTime date,
    required String note,
  }) async {
    if (amount <= 0) {
      return 'Ingresa un valor mayor a cero.';
    }

    if (amount >
        account.balance + 0.0001) {
      return 'El pago no puede ser mayor al saldo por cobrar.';
    }

    await database.insertCustomerPayment(
      person: account.person,
      amount: amount,
      paymentMethod:
          paymentMethod,
      date: date,
      note: note.trim(),
    );

    await loadData();

    return null;
  }

  // ==========================================================
  // CUENTAS POR PAGAR
  // ==========================================================

  List<PayableAccount>
      get payables {
    final map =
        <String, List<PayableMovement>>{};

    for (final movement
        in payableMovements) {
      final key =
          movement.provider
              .trim()
              .toLowerCase();

      map.putIfAbsent(
        key,
        () => [],
      );

      map[key]!.add(movement);
    }

    return map.entries.map(
      (entry) {
        return PayableAccount(
          provider:
              entry.value.first.provider,
          movements: entry.value,
        );
      },
    ).toList();
  }

  PayableAccount? findPayable(
    String provider,
  ) {
    final search =
        provider.trim().toLowerCase();

    if (search.isEmpty) {
      return null;
    }

    for (final account
        in payables) {
      if (account.provider
              .toLowerCase() ==
          search) {
        return account;
      }
    }

    return null;
  }

  Future<String?> registerProviderPayment({
    required PayableAccount account,
    required double amount,
    required String paymentMethod,
    required DateTime date,
    required String note,
  }) async {
    if (amount <= 0) {
      return 'Ingresa un valor mayor a cero.';
    }

    if (amount >
        account.balance + 0.0001) {
      return 'El abono no puede ser mayor al saldo por pagar.';
    }

    await database.insertProviderPayment(
      provider: account.provider,
      amount: amount,
      paymentMethod:
          paymentMethod,
      date: date,
      note: note.trim(),
    );

    await loadData();

    return null;
  }

  // ==========================================================
  // TOTALES
  // ==========================================================

  double get totalSales =>
      sales.fold<double>(
        0,
        (sum, sale) =>
            sum + sale.total,
      );

  double get totalExpenses =>
      expenses.fold<double>(
        0,
        (sum, expense) =>
            sum + expense.total,
      );

  double get totalReceivable {
    return receivables.fold<double>(
      0,
      (sum, account) =>
          sum +
          (account.balance > 0
              ? account.balance
              : 0),
    );
  }

  double get totalPayable {
    return payables.fold<double>(
      0,
      (sum, account) =>
          sum +
          (account.balance > 0
              ? account.balance
              : 0),
    );
  }

  double get result =>
      totalSales - totalExpenses;

  bool dateBetween(
    DateTime date,
    DateTime start,
    DateTime end,
  ) {
    final d = dateOnly(date);
    final s = dateOnly(start);
    final e = dateOnly(end);

    return !d.isBefore(s) &&
        !d.isAfter(e);
  }

  List<Sale> salesBetween(
    DateTime start,
    DateTime end,
  ) {
    return sales
        .where(
          (sale) => dateBetween(
            sale.date,
            start,
            end,
          ),
        )
        .toList();
  }

  List<Expense> expensesBetween(
    DateTime start,
    DateTime end,
  ) {
    return expenses
        .where(
          (expense) => dateBetween(
            expense.date,
            start,
            end,
          ),
        )
        .toList();
  }

  double salesTotalBetween(
    DateTime start,
    DateTime end,
  ) {
    return salesBetween(
      start,
      end,
    ).fold<double>(
      0,
      (sum, sale) =>
          sum + sale.total,
    );
  }

  double expenseTotalBetween(
    DateTime start,
    DateTime end,
  ) {
    return expensesBetween(
      start,
      end,
    ).fold<double>(
      0,
      (sum, expense) =>
          sum + expense.total,
    );
  }

  double salesByMethodBetween(
    String method,
    DateTime start,
    DateTime end,
  ) {
    return salesBetween(
      start,
      end,
    )
        .where(
          (sale) =>
              sale.paymentMethod ==
              method,
        )
        .fold<double>(
          0,
          (sum, sale) =>
              sum + sale.total,
        );
  }

  double expensesByMethodBetween(
    String method,
    DateTime start,
    DateTime end,
  ) {
    return expensesBetween(
      start,
      end,
    )
        .where(
          (expense) =>
              expense.paymentMethod ==
              method,
        )
        .fold<double>(
          0,
          (sum, expense) =>
              sum + expense.total,
        );
  }

  double customerPaymentsByMethodBetween(
    String method,
    DateTime start,
    DateTime end,
  ) {
    return receivableMovements
        .where(
          (movement) =>
              movement.type == 'Pago' &&
              movement.paymentMethod ==
                  method &&
              dateBetween(
                movement.date,
                start,
                end,
              ),
        )
        .fold<double>(
          0,
          (sum, movement) =>
              sum + movement.amount,
        );
  }

  double providerPaymentsByMethodBetween(
    String method,
    DateTime start,
    DateTime end,
  ) {
    return payableMovements
        .where(
          (movement) =>
              movement.type == 'Pago' &&
              movement.paymentMethod ==
                  method &&
              dateBetween(
                movement.date,
                start,
                end,
              ),
        )
        .fold<double>(
          0,
          (sum, movement) =>
              sum + movement.amount,
        );
  }

  double realMoneyReceivedBetween(
    DateTime start,
    DateTime end,
  ) {
    return salesByMethodBetween(
          'Efectivo',
          start,
          end,
        ) +
        salesByMethodBetween(
          'Transferencia',
          start,
          end,
        ) +
        customerPaymentsByMethodBetween(
          'Efectivo',
          start,
          end,
        ) +
        customerPaymentsByMethodBetween(
          'Transferencia',
          start,
          end,
        );
  }

  double realMoneyPaidBetween(
    DateTime start,
    DateTime end,
  ) {
    return expensesByMethodBetween(
          'Efectivo',
          start,
          end,
        ) +
        expensesByMethodBetween(
          'Transferencia',
          start,
          end,
        ) +
        providerPaymentsByMethodBetween(
          'Efectivo',
          start,
          end,
        ) +
        providerPaymentsByMethodBetween(
          'Transferencia',
          start,
          end,
        );
  }

  int quantityByCategoryBetween(
    String category,
    DateTime start,
    DateTime end,
  ) {
    int total = 0;

    for (final sale
        in salesBetween(
      start,
      end,
    )) {
      for (final item in sale.items) {
        if (item.category ==
            category) {
          total += item.quantity;
        }
      }
    }

    return total;
  }

  double amountByCategoryBetween(
    String category,
    DateTime start,
    DateTime end,
  ) {
    double total = 0;

    for (final sale
        in salesBetween(
      start,
      end,
    )) {
      for (final item in sale.items) {
        if (item.category ==
            category) {
          total += item.total;
        }
      }
    }

    return total;
  }
}

// ============================================================
// APP
// ============================================================

class ComedorApp
    extends StatelessWidget {
  const ComedorApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner:
          false,
      title: 'Control de Comedor',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed:
            Colors.teal,
        scaffoldBackgroundColor:
            const Color(
          0xFFF5F8F7,
        ),
        inputDecorationTheme:
            InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            borderSide: BorderSide(
              color:
                  Colors.grey.shade300,
            ),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// ============================================================
// NAVEGACIÓN
// ============================================================

class MainScreen
    extends StatefulWidget {
  const MainScreen({
    super.key,
  });

  @override
  State<MainScreen> createState() =>
      _MainScreenState();
}

class _MainScreenState
    extends State<MainScreen> {
  int currentIndex = 0;

  final pages = const [
    HomePage(),
    ProductsPage(),
    SalesPage(),
    ExpensesPage(),
    UtilitiesPage(),
    ReportsPage(),
  ];

  final titles = const [
    'Inicio',
    'Comidas',
    'Ventas',
    'Gastos',
    'Utilidad',
    'Reportes',
  ];

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[currentIndex],
          style: const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
      body: pages[currentIndex],
      bottomNavigationBar:
          NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected:
            (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon:
                Icon(Icons.home_outlined),
            selectedIcon:
                Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(
              Icons
                  .restaurant_menu_outlined,
            ),
            selectedIcon:
                Icon(
              Icons.restaurant_menu,
            ),
            label: 'Comidas',
          ),
          NavigationDestination(
            icon:
                Icon(Icons.receipt_long_outlined),
            selectedIcon:
                Icon(Icons.receipt_long),
            label: 'Ventas',
          ),
          NavigationDestination(
            icon:
                Icon(Icons.shopping_cart_outlined),
            selectedIcon:
                Icon(Icons.shopping_cart),
            label: 'Gastos',
          ),
          NavigationDestination(
            icon:
                Icon(Icons.trending_up_outlined),
            selectedIcon:
                Icon(Icons.trending_up),
            label: 'Utilidad',
          ),
          NavigationDestination(
            icon:
                Icon(Icons.bar_chart_outlined),
            selectedIcon:
                Icon(Icons.bar_chart),
            label: 'Reportes',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// INICIO
// ============================================================

class HomePage
    extends StatelessWidget {
  const HomePage({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final today =
            dateOnly(
          DateTime.now(),
        );

        final salesToday =
            appStore.salesTotalBetween(
          today,
          today,
        );

        final expensesToday =
            appStore.expenseTotalBetween(
          today,
          today,
        );

        final utilityToday =
            salesToday -
                expensesToday;

        final openSales =
            appStore.sales
                .where(
                  (sale) =>
                      sale.status ==
                      'Abierta',
                )
                .length;

        return ListView(
          padding:
              const EdgeInsets.all(
            16,
          ),
          children: [
            const Text(
              '🍽️ Control del Comedor',
              style: TextStyle(
                fontSize: 27,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              'Resumen de hoy • ${formatDate(today)}',
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title:
                        'Ventas de hoy',
                    value:
                        money(salesToday),
                    icon:
                        Icons.attach_money,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(
                    title:
                        'Gastos de hoy',
                    value:
                        money(expensesToday),
                    icon:
                        Icons.shopping_cart,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Por cobrar',
                    value: money(
                      appStore
                          .totalReceivable,
                    ),
                    icon: Icons.person,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(
                    title: 'Por pagar',
                    value: money(
                      appStore.totalPayable,
                    ),
                    icon: Icons.store,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Card(
              child: ListTile(
                leading:
                    const CircleAvatar(
                  child: Icon(
                    Icons.pending_actions,
                  ),
                ),
                title:
                    const Text(
                  'Pedidos abiertos',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                subtitle:
                    const Text(
                  'Ventas que todavía pueden recibir productos',
                ),
                trailing: Text(
                  '$openSales',
                  style:
                      const TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TotalBox(
              title:
                  utilityToday >= 0
                      ? 'UTILIDAD DE HOY'
                      : 'PÉRDIDA DE HOY',
              value: utilityToday,
              subtitle:
                  'Ventas - Gastos',
            ),

            const SizedBox(height: 22),

            const SectionTitle(
              icon: Icons.restaurant,
              title:
                  'Productos vendidos hoy',
            ),

            CategoryCard(
              emoji: '☕',
              title: 'Desayunos',
              quantity: appStore
                  .quantityByCategoryBetween(
                'Desayuno',
                today,
                today,
              ),
              amount: appStore
                  .amountByCategoryBetween(
                'Desayuno',
                today,
                today,
              ),
            ),

            CategoryCard(
              emoji: '🍛',
              title:
                  'Almuerzos completos',
              quantity: appStore
                  .quantityByCategoryBetween(
                'Almuerzo',
                today,
                today,
              ),
              amount: appStore
                  .amountByCategoryBetween(
                'Almuerzo',
                today,
                today,
              ),
            ),

            CategoryCard(
              emoji: '🍽️',
              title:
                  'Platos a la carta',
              quantity: appStore
                  .quantityByCategoryBetween(
                'Platos a la carta',
                today,
                today,
              ),
              amount: appStore
                  .amountByCategoryBetween(
                'Platos a la carta',
                today,
                today,
              ),
            ),

            CategoryCard(
              emoji: '🥤',
              title:
                  'Bebidas / Adicionales',
              quantity: appStore
                  .quantityByCategoryBetween(
                'Bebidas / Adicionales',
                today,
                today,
              ),
              amount: appStore
                  .amountByCategoryBetween(
                'Bebidas / Adicionales',
                today,
                today,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// COMIDAS
// ============================================================

class ProductsPage
    extends StatelessWidget {
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
              FloatingActionButton
                  .extended(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) =>
                    const ProductDialog(),
              );
            },
            icon:
                const Icon(Icons.add),
            label: const Text(
              'Nuevo producto',
            ),
          ),
          body:
              appStore.products.isEmpty
                  ? const EmptyState(
                      icon:
                          Icons.restaurant,
                      title:
                          'No hay productos',
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
                      children: const [
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

// ============================================================
// VENTAS
// ============================================================

class SalesPage
    extends StatefulWidget {
  const SalesPage({
    super.key,
  });

  @override
  State<SalesPage> createState() =>
      _SalesPageState();
}

class _SalesPageState
    extends State<SalesPage> {
  String filter = 'Todas';

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final sales =
            appStore.sales
                .where(
                  (sale) =>
                      filter == 'Todas' ||
                      sale.status ==
                          filter,
                )
                .toList()
              ..sort(
                (a, b) =>
                    b.id.compareTo(
                  a.id,
                ),
              );

        return ListView(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            80,
          ),
          children: [
            FilledButton.icon(
              onPressed: () {
                if (!appStore.products
                    .any(
                  (product) =>
                      product.available,
                )) {
                  showMessage(
                    context,
                    'Primero registra productos disponibles.',
                  );

                  return;
                }

                showDialog(
                  context: context,
                  barrierDismissible:
                      false,
                  builder: (_) =>
                      const SaleDialog(),
                );
              },
              icon: const Icon(
                Icons.add_shopping_cart,
              ),
              label: const Text(
                'Crear nuevo pedido',
              ),
            ),

            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  selected:
                      filter == 'Todas',
                  label:
                      const Text('Todas'),
                  onSelected: (_) {
                    setState(() {
                      filter = 'Todas';
                    });
                  },
                ),
                ChoiceChip(
                  selected:
                      filter == 'Abierta',
                  label:
                      const Text(
                    '🟠 Abiertas',
                  ),
                  onSelected: (_) {
                    setState(() {
                      filter = 'Abierta';
                    });
                  },
                ),
                ChoiceChip(
                  selected:
                      filter == 'Cerrada',
                  label:
                      const Text(
                    '✅ Cerradas',
                  ),
                  onSelected: (_) {
                    setState(() {
                      filter = 'Cerrada';
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (sales.isEmpty)
              const EmptyState(
                icon:
                    Icons.receipt_long,
                title:
                    'No hay ventas',
                subtitle:
                    'Crea el primer pedido.',
              ),

            ...sales.map(
              (sale) =>
                  SaleOrderCard(
                sale: sale,
              ),
            ),
          ],
        );
      },
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
    if (orderItems.isEmpty) {
      showMessage(
        context,
        'Agrega productos al pedido.',
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
                      '👤 Fiado',
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

// ============================================================
// GASTOS
// ============================================================

class ExpensesPage
    extends StatelessWidget {
  const ExpensesPage({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final expenses =
            [...appStore.expenses]
              ..sort(
                (a, b) =>
                    b.id.compareTo(
                  a.id,
                ),
              );

        return ListView(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            80,
          ),
          children: [
            FilledButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible:
                      false,
                  builder: (_) =>
                      const ExpenseDialog(),
                );
              },
              icon:
                  const Icon(
                Icons.add_shopping_cart,
              ),
              label: const Text(
                'Registrar nueva compra',
              ),
            ),

            const SizedBox(height: 16),

            if (expenses.isEmpty)
              const EmptyState(
                icon:
                    Icons.shopping_cart,
                title:
                    'No hay gastos',
                subtitle:
                    'Registra la primera compra.',
              ),

            ...expenses.map(
              (expense) =>
                  ExpenseCard(
                expense: expense,
              ),
            ),
          ],
        );
      },
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
    if (purchaseItems.isEmpty) {
      showMessage(
        context,
        'Agrega productos a la compra.',
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
                      '🏪 Fiado',
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
        price < 0) {
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

// ============================================================
// UTILIDAD
// ============================================================

class UtilitiesPage
    extends StatefulWidget {
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

  DateTime customStart =
      DateTime.now();

  DateTime customEnd =
      DateTime.now();

  DateTimeRange get range {
    final now =
        dateOnly(DateTime.now());

    if (period == 'Semana') {
      final start = now.subtract(
        Duration(
          days:
              now.weekday - 1,
        ),
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

    if (period ==
        'Personalizado') {
      return DateTimeRange(
        start:
            dateOnly(customStart),
        end: dateOnly(customEnd),
      );
    }

    return DateTimeRange(
      start: now,
      end: now,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        final selectedRange =
            range;

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

        final utility =
            sales - expenses;

        final received = appStore
            .realMoneyReceivedBetween(
          selectedRange.start,
          selectedRange.end,
        );

        final paid = appStore
            .realMoneyPaidBetween(
          selectedRange.start,
          selectedRange.end,
        );

        final cashFlow =
            received - paid;

        return ListView(
          padding:
              const EdgeInsets.all(
            16,
          ),
          children: [
            const Text(
              '📈 Utilidad',
              style: TextStyle(
                fontSize: 27,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            Wrap(
              spacing: 7,
              children: [
                for (final item
                    in const [
                  'Hoy',
                  'Semana',
                  'Mes',
                  'Personalizado',
                ])
                  ChoiceChip(
                    selected:
                        period == item,
                    label: Text(item),
                    onSelected: (_) {
                      setState(() {
                        period = item;
                      });
                    },
                  ),
              ],
            ),

            if (period ==
                'Personalizado') ...[
              const SizedBox(
                height: 12,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                        FilterDateButton(
                      label: 'Desde',
                      date:
                          customStart,
                      onPressed:
                          () async {
                        final value =
                            await chooseDate(
                          context,
                          customStart,
                        );

                        if (value !=
                            null) {
                          setState(() {
                            customStart =
                                value;

                            if (customEnd
                                .isBefore(
                              value,
                            )) {
                              customEnd =
                                  value;
                            }
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child:
                        FilterDateButton(
                      label: 'Hasta',
                      date:
                          customEnd,
                      onPressed:
                          () async {
                        final value =
                            await chooseDate(
                          context,
                          customEnd,
                        );

                        if (value !=
                            null) {
                          setState(() {
                            customEnd =
                                value;
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
                  child:
                      SummaryCard(
                    title: 'Ventas',
                    value:
                        money(sales),
                    icon:
                        Icons.attach_money,
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child:
                      SummaryCard(
                    title: 'Gastos',
                    value:
                        money(expenses),
                    icon:
                        Icons.shopping_cart,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            TotalBox(
              title:
                  utility >= 0
                      ? 'UTILIDAD CONTABLE'
                      : 'PÉRDIDA CONTABLE',
              value: utility,
              subtitle:
                  'Ventas - Gastos',
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child:
                      SummaryCard(
                    title:
                        'Dinero recibido',
                    value:
                        money(received),
                    icon:
                        Icons.south_west,
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child:
                      SummaryCard(
                    title:
                        'Dinero pagado',
                    value:
                        money(paid),
                    icon:
                        Icons.north_east,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            TotalBox(
              title:
                  'FLUJO REAL',
              value: cashFlow,
              subtitle:
                  'Dinero recibido - dinero pagado',
            ),

            const SizedBox(height: 22),

            const SectionTitle(
              icon:
                  Icons.point_of_sale,
              title:
                  'Cierre diario',
            ),

            DailyCashCloseCard(
              date:
                  selectedRange.end,
            ),
          ],
        );
      },
    );
  }
}

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

// ============================================================
// REPORTES
// ============================================================

class ReportsPage
    extends StatefulWidget {
  const ReportsPage({
    super.key,
  });

  @override
  State<ReportsPage> createState() =>
      _ReportsPageState();
}

class _ReportsPageState
    extends State<ReportsPage> {
  bool salesReport = true;

  String viewMode =
      'Movimientos';

  String paymentFilter =
      'Todas';

  String accountFilter =
      'Todos';

  String search = '';

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedBuilder(
      animation: appStore,
      builder: (context, _) {
        return ListView(
          padding:
              const EdgeInsets.all(
            16,
          ),
          children: [
            const Text(
              '📊 Reportes',
              style: TextStyle(
                fontSize: 27,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    selected:
                        salesReport,
                    label:
                        const SizedBox(
                      width:
                          double.infinity,
                      child: Text(
                        '💰 Ventas',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                    onSelected: (_) {
                      setState(() {
                        salesReport =
                            true;
                      });
                    },
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: ChoiceChip(
                    selected:
                        !salesReport,
                    label:
                        const SizedBox(
                      width:
                          double.infinity,
                      child: Text(
                        '🛒 Gastos',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                    onSelected: (_) {
                      setState(() {
                        salesReport =
                            false;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    selected:
                        viewMode ==
                            'Movimientos',
                    label:
                        const Text(
                      '📋 Movimientos',
                    ),
                    onSelected: (_) {
                      setState(() {
                        viewMode =
                            'Movimientos';
                      });
                    },
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: ChoiceChip(
                    selected:
                        viewMode ==
                            'Cuentas',
                    label: Text(
                      salesReport
                          ? '👥 Clientes'
                          : '🏪 Proveedores',
                    ),
                    onSelected: (_) {
                      setState(() {
                        viewMode =
                            'Cuentas';
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (viewMode ==
                'Movimientos')
              DropdownButtonFormField<
                  String>(
                value:
                    paymentFilter,
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
                    value: 'Todas',
                    child:
                        Text('Todas'),
                  ),
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
                      '👤 Fiado',
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      paymentFilter =
                          value;
                    });
                  }
                },
              )
            else
              Wrap(
                spacing: 7,
                children: [
                  ChoiceChip(
                    selected:
                        accountFilter ==
                            'Todos',
                    label:
                        const Text(
                      'Todos',
                    ),
                    onSelected: (_) {
                      setState(() {
                        accountFilter =
                            'Todos';
                      });
                    },
                  ),
                  ChoiceChip(
                    selected:
                        accountFilter ==
                            'Pagados',
                    label:
                        const Text(
                      '✅ Pagados',
                    ),
                    onSelected: (_) {
                      setState(() {
                        accountFilter =
                            'Pagados';
                      });
                    },
                  ),
                  ChoiceChip(
                    selected:
                        accountFilter ==
                            'Pendientes',
                    label: Text(
                      salesReport
                          ? '🔴 Por cobrar'
                          : '🔴 Por pagar',
                    ),
                    onSelected: (_) {
                      setState(() {
                        accountFilter =
                            'Pendientes';
                      });
                    },
                  ),
                ],
              ),

            const SizedBox(height: 12),

            TextField(
              decoration:
                  InputDecoration(
                labelText:
                    'Buscar',
                hintText:
                    salesReport
                        ? 'Cliente o producto...'
                        : 'Proveedor o insumo...',
                prefixIcon:
                    const Icon(
                  Icons.search,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  search =
                      value
                          .trim()
                          .toLowerCase();
                });
              },
            ),

            const SizedBox(height: 18),

            if (viewMode ==
                'Movimientos')
              salesReport
                  ? buildSales()
                  : buildExpenses()
            else
              salesReport
                  ? buildCustomers()
                  : buildProviders(),
          ],
        );
      },
    );
  }

  Widget buildSales() {
    final items =
        appStore.sales.where(
      (sale) {
        if (paymentFilter !=
                'Todas' &&
            sale.paymentMethod !=
                paymentFilter) {
          return false;
        }

        if (search.isEmpty) {
          return true;
        }

        return sale.person
                .toLowerCase()
                .contains(search) ||
            sale.items.any(
              (item) =>
                  item.productName
                      .toLowerCase()
                      .contains(search),
            );
      },
    ).toList()
          ..sort(
            (a, b) =>
                b.date.compareTo(
              a.date,
            ),
          );

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title:
            'No se encontraron ventas',
        subtitle:
            'Cambia los filtros.',
      );
    }

    return Column(
      children: items
          .map(
            (sale) =>
                SaleReportCard(
              sale: sale,
            ),
          )
          .toList(),
    );
  }

  Widget buildExpenses() {
    final items =
        appStore.expenses.where(
      (expense) {
        if (paymentFilter !=
                'Todas' &&
            expense.paymentMethod !=
                paymentFilter) {
          return false;
        }

        if (search.isEmpty) {
          return true;
        }

        return expense.provider
                .toLowerCase()
                .contains(search) ||
            expense.items.any(
              (item) =>
                  item.description
                      .toLowerCase()
                      .contains(search),
            );
      },
    ).toList()
          ..sort(
            (a, b) =>
                b.date.compareTo(
              a.date,
            ),
          );

    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title:
            'No se encontraron compras',
        subtitle:
            'Cambia los filtros.',
      );
    }

    return Column(
      children: items
          .map(
            (expense) =>
                ExpenseReportCard(
              expense: expense,
            ),
          )
          .toList(),
    );
  }

  Widget buildCustomers() {
    final items =
        appStore.receivables
            .where(
              (account) {
                if (accountFilter ==
                        'Pendientes' &&
                    account.balance <=
                        0) {
                  return false;
                }

                if (accountFilter ==
                        'Pagados' &&
                    account.balance > 0) {
                  return false;
                }

                return search.isEmpty ||
                    account.person
                        .toLowerCase()
                        .contains(
                          search,
                        );
              },
            )
            .toList()
          ..sort(
            (a, b) =>
                b.balance.compareTo(
              a.balance,
            ),
          );

    if (items.isEmpty) {
      return const EmptyState(
        icon:
            Icons.people_outline,
        title:
            'No hay clientes',
        subtitle:
            'Las ventas fiadas aparecerán aquí.',
      );
    }

    return Column(
      children: items
          .map(
            (account) =>
                ReceivableAccountCard(
              account: account,
            ),
          )
          .toList(),
    );
  }

  Widget buildProviders() {
    final items =
        appStore.payables
            .where(
              (account) {
                if (accountFilter ==
                        'Pendientes' &&
                    account.balance <=
                        0) {
                  return false;
                }

                if (accountFilter ==
                        'Pagados' &&
                    account.balance > 0) {
                  return false;
                }

                return search.isEmpty ||
                    account.provider
                        .toLowerCase()
                        .contains(
                          search,
                        );
              },
            )
            .toList()
          ..sort(
            (a, b) =>
                b.balance.compareTo(
              a.balance,
            ),
          );

    if (items.isEmpty) {
      return const EmptyState(
        icon:
            Icons.store_outlined,
        title:
            'No hay proveedores',
        subtitle:
            'Las compras fiadas aparecerán aquí.',
      );
    }

    return Column(
      children: items
          .map(
            (account) =>
                PayableAccountCard(
              account: account,
            ),
          )
          .toList(),
    );
  }
}

class SaleReportCard
    extends StatelessWidget {
  final Sale sale;

  const SaleReportCard({
    super.key,
    required this.sale,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final account =
        sale.paymentMethod ==
                'Fiado'
            ? appStore.findReceivable(
                sale.person,
              )
            : null;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '🧾 Venta #${sale.id}',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  money(sale.total),
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

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

            if (sale.paymentMethod ==
                    'Fiado' &&
                account != null) ...[
              const SizedBox(
                height: 5,
              ),
              Text(
                account.balance > 0
                    ? '🔴 Cuenta actual por cobrar: ${money(account.balance)}'
                    : '✅ Cuenta actual pagada',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  color:
                      account.balance > 0
                          ? Colors.red
                          : Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ExpenseReportCard
    extends StatelessWidget {
  final Expense expense;

  const ExpenseReportCard({
    super.key,
    required this.expense,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final account =
        expense.paymentMethod ==
                'Fiado'
            ? appStore.findPayable(
                expense.provider,
              )
            : null;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),
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
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  money(expense.total),
                  style:
                      const TextStyle(
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

            if (expense.paymentMethod ==
                    'Fiado' &&
                account != null) ...[
              const SizedBox(
                height: 5,
              ),
              Text(
                account.balance > 0
                    ? '🔴 Cuenta actual por pagar: ${money(account.balance)}'
                    : '✅ Cuenta actual pagada',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  color:
                      account.balance > 0
                          ? Colors.red
                          : Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ReceivableAccountCard
    extends StatelessWidget {
  final ReceivableAccount account;

  const ReceivableAccountCard({
    super.key,
    required this.account,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final pending =
        account.balance > 0;

    return Card(
      child: ListTile(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) =>
                CustomerAccountDialog(
              account: account,
            ),
          );
        },
        leading: CircleAvatar(
          child:
              Text(
            pending ? '🔴' : '✅',
          ),
        ),
        title: Text(
          account.person,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Consumido: ${money(account.charged)}\n'
          'Pagado: ${money(account.paid)}',
        ),
        trailing: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Text(
              pending
                  ? 'Por cobrar'
                  : 'Pagado',
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.bold,
                color: pending
                    ? Colors.red
                    : Colors.green,
              ),
            ),
            Text(
              money(
                pending
                    ? account.balance
                    : 0,
              ),
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                color: pending
                    ? Colors.red
                    : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PayableAccountCard
    extends StatelessWidget {
  final PayableAccount account;

  const PayableAccountCard({
    super.key,
    required this.account,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final pending =
        account.balance > 0;

    return Card(
      child: ListTile(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) =>
                ProviderAccountDialog(
              account: account,
            ),
          );
        },
        leading: CircleAvatar(
          child:
              Text(
            pending ? '🔴' : '✅',
          ),
        ),
        title: Text(
          account.provider,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Comprado: ${money(account.purchased)}\n'
          'Pagado: ${money(account.paid)}',
        ),
        trailing: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Text(
              pending
                  ? 'Por pagar'
                  : 'Pagado',
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.bold,
                color: pending
                    ? Colors.red
                    : Colors.green,
              ),
            ),
            Text(
              money(
                pending
                    ? account.balance
                    : 0,
              ),
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                color: pending
                    ? Colors.red
                    : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();

    super.dispose();
  }

  Future<void> registerPayment() async {
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
                registerPayment,
            icon:
                const Icon(
              Icons.payments,
            ),
            label:
                const Text(
              'Registrar pago',
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

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();

    super.dispose();
  }

  Future<void> registerPayment() async {
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
            onPressed:
                registerPayment,
            icon:
                const Icon(
              Icons.payments,
            ),
            label:
                const Text(
              'Registrar abono',
            ),
          ),
      ],
    );
  }
}

// ============================================================
// WIDGETS
// ============================================================

class SummaryCard
    extends StatelessWidget {
  final String title;
  final String value;

  final IconData icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(
              height: 8,
            ),
            Text(
              title,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              value,
              style:
                  const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryCard
    extends StatelessWidget {
  final String emoji;
  final String title;

  final int quantity;
  final double amount;

  const CategoryCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.quantity,
    required this.amount,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: ListTile(
        leading:
            CircleAvatar(
          child: Text(emoji),
        ),
        title: Text(
          title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$quantity vendidos',
        ),
        trailing: Text(
          money(amount),
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class TotalBox
    extends StatelessWidget {
  final String title;

  final double value;

  final String subtitle;

  const TotalBox({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color:
            Theme.of(context)
                .colorScheme
                .primaryContainer
                .withOpacity(
                  0.45,
                ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            money(value),
            style:
                const TextStyle(
              fontSize: 28,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            textAlign:
                TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class SectionTitle
    extends StatelessWidget {
  final IconData icon;
  final String title;

  const SectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 7),
          Text(
            title,
            style:
                const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 58,
              color:
                  Colors.grey.shade400,
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              title,
              style:
                  const TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              subtitle,
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBadge
    extends StatelessWidget {
  final String text;

  final bool positive;

  const StatusBadge({
    super.key,
    required this.text,
    required this.positive,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: positive
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight:
              FontWeight.bold,
          color: positive
              ? Colors.green.shade800
              : Colors.orange.shade800,
        ),
      ),
    );
  }
}

class CashCloseRow
    extends StatelessWidget {
  final String label;

  final double value;

  final bool strong;

  const CashCloseRow({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${value < 0 ? '-' : ''}'
            '${money(value.abs())}',
            style: TextStyle(
              fontWeight: strong
                  ? FontWeight.bold
                  : FontWeight.w600,
              color: value < 0
                  ? Colors.red
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class DateSelector
    extends StatelessWidget {
  final String title;

  final DateTime date;

  final VoidCallback onTap;

  const DateSelector({
    super.key,
    required this.title,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(
        14,
      ),
      onTap: onTap,
      child: InputDecorator(
        decoration:
            InputDecoration(
          labelText: title,
          prefixIcon:
              const Icon(
            Icons.calendar_month,
          ),
        ),
        child:
            Text(
          formatDate(date),
        ),
      ),
    );
  }
}

class FilterDateButton
    extends StatelessWidget {
  final String label;

  final DateTime? date;

  final VoidCallback onPressed;

  const FilterDateButton({
    super.key,
    required this.label,
    required this.date,
    required this.onPressed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon:
          const Icon(
        Icons.calendar_month,
      ),
      label: Text(
        '$label\n${date == null ? 'Sin fecha' : formatDate(date!)}',
        textAlign:
            TextAlign.center,
      ),
    );
  }
}

class InfoBox
    extends StatelessWidget {
  final String text;

  const InfoBox({
    super.key,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration: BoxDecoration(
        color:
            Colors.orange.shade50,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Text(text),
    );
  }
}

// ============================================================
// FUNCIONES
// ============================================================

DateTime dateOnly(
  DateTime date,
) {
  return DateTime(
    date.year,
    date.month,
    date.day,
  );
}

String formatDate(
  DateTime date,
) {
  final day =
      date.day.toString().padLeft(
            2,
            '0',
          );

  final month =
      date.month
          .toString()
          .padLeft(
            2,
            '0',
          );

  return '$day/$month/${date.year}';
}

String money(
  double value,
) {
  return '\$${value.toStringAsFixed(2)}';
}

String formatQuantity(
  double value,
) {
  if (value ==
      value.roundToDouble()) {
    return value
        .toInt()
        .toString();
  }

  return value
      .toStringAsFixed(2);
}

String categoryEmoji(
  String category,
) {
  switch (category) {
    case 'Desayuno':
      return '☕';

    case 'Almuerzo':
      return '🍛';

    case 'Platos a la carta':
      return '🍽️';

    default:
      return '🥤';
  }
}

String paymentIcon(
  String paymentMethod,
) {
  switch (paymentMethod) {
    case 'Efectivo':
      return '💵';

    case 'Transferencia':
      return '🏦';

    case 'Fiado':
      return '👤';

    default:
      return '💰';
  }
}

Future<DateTime?> chooseDate(
  BuildContext context,
  DateTime current,
) {
  return showDatePicker(
    context: context,
    initialDate: current,
    firstDate:
        DateTime(2020),
    lastDate:
        DateTime(2100),
  );
}

void showMessage(
  BuildContext context,
  String message,
) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(
    SnackBar(
      content: Text(message),
    ),
  );
}

Future<bool> askConfirmation(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result =
      await showDialog<bool>(
    context: context,
    builder: (_) =>
        AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(
            context,
            false,
          ),
          child:
              const Text(
            'Cancelar',
          ),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(
            context,
            true,
          ),
          child:
              const Text(
            'Confirmar',
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}