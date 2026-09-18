part of '../main.dart';

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

// La pantalla de Comidas está separada en pages/products_page.dart.

// La pantalla de Ventas está separada en pages/sales_page.dart.

// La pantalla de Gastos está separada en pages/expenses_page.dart.

// La pantalla de Utilidad está separada en pages/utilities_page.dart.
