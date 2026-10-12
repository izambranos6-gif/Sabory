import 'dart:io';
import 'dart:typed_data';



import 'package:excel/excel.dart' as xls;

import 'package:file_saver/file_saver.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:sqflite/sqflite.dart';

import 'data/web_memory_service.dart';

import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';



part 'models/app_models.dart';

part 'data/app_database.dart';

part 'store/app_store.dart';

part 'reports/excel_report_service.dart';

part 'pages/products_page.dart';

part 'pages/sales_page.dart';

part 'pages/expenses_page.dart';

part 'pages/utilities_page.dart';

part 'pages/home_page.dart';

part 'widgets/shared_widgets.dart';

part 'dialogs/account_dialogs.dart';
part 'pages/backup_page.dart';



// ============================================================

// MAIN

// ============================================================



Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();



  print('>>> SABORY INICIANDO');

  print('>>> kIsWeb = $kIsWeb');



  if (!kIsWeb) {

    print('>>> INICIANDO SQLITE');

    await database.init();

    await appStore.loadData();

  } else {

    print('>>> WEB: MODO DE PRUEBA EN MEMORIA');

    await appStore.loadData();

  }



  print('>>> EJECUTANDO runApp');

  runApp(const ComedorApp());

}



final AppDatabase database = AppDatabase();

final AppStore appStore = AppStore();



// La implementación de SQLite está separada en data/app_database.dart.



// Los modelos están separados en models/app_models.dart.



// La lógica de estado está separada en store/app_store.dart.

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

];



  final titles = const [

    'Inicio',

    'Comidas',

    'Ventas',

    'Gastos',

    'Utilidad',

  ];



  @override

  Widget build(

    BuildContext context,

  ) {

    return Scaffold(

      appBar: AppBar(
        title: Text(
        titles[currentIndex],
        style: const TextStyle(fontWeight: FontWeight.bold),
  ),
  actions: [
    if (currentIndex == 0)
      IconButton(
        tooltip: 'Configuración',
        icon: const Icon(Icons.settings_outlined),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        },
      ),
    const SizedBox(width: 8),
  ],
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

        ],

      ),

    );

  }

}



// La pantalla de Inicio está separada en pages/home_page.dart.



// El módulo antiguo de Reportes fue retirado del main.dart.

// Los reportes actuales se generan desde Utilidad mediante reports/excel_report_service.dart.



class ReceivableAccountCard extends StatefulWidget {

  final ReceivableAccount account;

  final List<Sale> creditSales;



  const ReceivableAccountCard({

    super.key,

    required this.account,

    this.creditSales = const [],

  });



  @override

  State<ReceivableAccountCard> createState() => _ReceivableAccountCardState();

}



class _ReceivableAccountCardState extends State<ReceivableAccountCard> {

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

                CircleAvatar(child: Text(pending ? '🔴' : '✅')),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(account.person, style: const TextStyle(fontSize:18, fontWeight:FontWeight.bold)),

                      Text('Consumido: ${money(account.charged)}'),

                      Text('Pagado: ${money(account.paid)}'),

                    ],

                  ),

                ),

                Column(

                  crossAxisAlignment: CrossAxisAlignment.end,

                  children: [

                    Text(pending ? 'Por cobrar' : 'Pagado', style: TextStyle(fontWeight:FontWeight.bold, color:pending ? Colors.red : Colors.green)),

                    Text(money(pending ? account.balance : 0), style: TextStyle(fontSize:17, fontWeight:FontWeight.bold, color:pending ? Colors.red : Colors.green)),

                  ],

                ),

              ],

            ),

            if (widget.creditSales.isNotEmpty) ...[

              const SizedBox(height: 10),

              OutlinedButton.icon(

                onPressed: ()=>setState(()=>showDetails=!showDetails),

                icon: Icon(showDetails ? Icons.expand_less : Icons.expand_more),

                label: Text(showDetails ? 'Ocultar detalle de ventas' : 'Ver detalle de ventas'),

              ),

              if (showDetails) ...[

                const Divider(),

                ...widget.creditSales.map((sale) => Padding(

                  padding: const EdgeInsets.only(bottom: 12),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text('🧾 Pedido #${sale.id}', style: const TextStyle(fontWeight:FontWeight.bold)),

                      const SizedBox(height: 3),

                      Text('📅 ${formatDate(sale.date)}'),

                      const SizedBox(height: 7),

                      ...sale.items.map((item)=>Padding(

                        padding: const EdgeInsets.only(left: 8, bottom: 4),

                        child: Text('${item.quantity} × ${item.productName} = ${money(item.total)}'),

                      )),

                    ],

                  ),

                )),

              ],

            ],

            const Divider(),

            Row(

              children: [

                Expanded(

                  child: FilledButton.icon(

                    onPressed: () => showDialog(

                      context: context,

                      builder: (_) => CustomerAccountDialog(account: account),

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



// Los diálogos de cuentas están separados en dialogs/account_dialogs.dart.



// Los widgets compartidos están separados en widgets/shared_widgets.dart.



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



String money(double value) {
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

      return '📝';



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

  showDialog<void>(

    context: context,

    builder: (dialogContext) {

      return AlertDialog(

        title: const Row(

          children: [

            Icon(

              Icons.warning_amber_rounded,

              color: Colors.orange,

            ),

            SizedBox(width: 10),

            Expanded(

              child: Text(

                'Falta información',

              ),

            ),

          ],

        ),

        content: Text(

          message,

          style: const TextStyle(

            fontSize: 16,

          ),

        ),

        actions: [

          FilledButton(

            onPressed: () =>

                Navigator.pop(dialogContext),

            child: const Text(

              'Aceptar',

            ),

          ),

        ],

      );

    },

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