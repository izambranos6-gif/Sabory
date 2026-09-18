/// Almacenamiento temporal usado únicamente al ejecutar Sabory en Flutter Web.
///
/// No reemplaza SQLite de Android. Los datos guardados aquí viven solamente
/// mientras la aplicación Web está ejecutándose y se pierden al reiniciarla.
class WebMemoryService {
  final List<dynamic> products = [];
  final List<dynamic> sales = [];
  final List<dynamic> expenses = [];
  final List<dynamic> receivables = [];
  final List<dynamic> payables = [];
  final List<dynamic> catalog = [];

  int productId = 0;
  int saleId = 0;
  int expenseId = 0;
  int receivableId = 0;
  int payableId = 0;
  int catalogId = 0;

  void clear() {
    products.clear();
    sales.clear();
    expenses.clear();
    receivables.clear();
    payables.clear();
    catalog.clear();
    productId = 0;
    saleId = 0;
    expenseId = 0;
    receivableId = 0;
    payableId = 0;
    catalogId = 0;
  }
}
