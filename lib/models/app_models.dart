part of '../main.dart';

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
