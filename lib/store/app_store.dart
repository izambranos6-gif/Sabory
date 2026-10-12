part of '../main.dart';



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



    if (items.isEmpty) {

      return 'No puedes guardar una venta sin productos.';

    }



    if (items.any((item) =>

        item.quantity <= 0 ||

        item.unitPrice <= 0)) {

      return 'Todos los productos deben tener cantidad y precio mayores a cero.';

    }



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



    if (items.isEmpty) {

      return 'No puedes guardar una venta sin productos.';

    }



    if (items.any((item) =>

        item.quantity <= 0 ||

        item.unitPrice <= 0)) {

      return 'Todos los productos deben tener cantidad y precio mayores a cero.';

    }



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

      required String invoiceType,
    required String invoiceNumber,
    required String invoiceTaxId,
}) async {

    final supplier =

        provider.trim();



    if (items.isEmpty) {

      return 'No puedes guardar una compra sin productos.';

    }



    if (items.any((item) =>

        item.quantity <= 0 ||

        item.unitPrice <= 0)) {

      return 'Todos los productos de la compra deben tener cantidad y precio mayores a cero.';

    }



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
      invoiceType: invoiceType,
      invoiceNumber: invoiceNumber.trim(),
      invoiceTaxId: invoiceTaxId.trim(),

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

      required String invoiceType,
    required String invoiceNumber,
    required String invoiceTaxId,
}) async {

    final newProvider =

        provider.trim();



    if (items.isEmpty) {

      return 'No puedes guardar una compra sin productos.';

    }



    if (items.any((item) =>

        item.quantity <= 0 ||

        item.unitPrice <= 0)) {

      return 'Todos los productos de la compra deben tener cantidad y precio mayores a cero.';

    }



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

      ..note = note.trim()
      ..invoiceType = invoiceType
      ..invoiceNumber = invoiceNumber.trim()
      ..invoiceTaxId = invoiceTaxId.trim();



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