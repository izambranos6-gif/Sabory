part of '../main.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool working = false;

  Future<void> createBackup() async {
    if (kIsWeb) {
      showMessage(context, 'El respaldo de la base de datos se probará en la aplicación Android.');
      return;
    }

    setState(() => working = true);

    try {
      final backupPath = await database.createBackup();
      final file = XFile(backupPath);

      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          fileNameOverrides: [p.basename(backupPath)],
          subject: 'Respaldo de Sabory',
          text: 'Copia de seguridad de los datos de Sabory.',
        ),
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('✅ Respaldo creado'),
          content: const Text('La copia de seguridad fue creada correctamente. Guárdala en un lugar seguro.'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Aceptar')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo crear el respaldo: $e');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> restoreBackup() async {
    if (kIsWeb) {
      showMessage(context, 'La restauración de la base de datos se probará en la aplicación Android.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Seleccionar respaldo de Sabory',
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;

    if (!mounted) return;
    final confirmed = await askConfirmation(
      context,
      title: 'Restaurar respaldo',
      message: 'La información actual de Sabory será reemplazada por la información del respaldo seleccionado. ¿Deseas continuar?',
    );

    if (!confirmed) return;
    setState(() => working = true);

    try {
      await database.restoreBackup(result.files.single.path!);
      await appStore.loadData();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('✅ Respaldo restaurado'),
          content: const Text('Los datos de Sabory fueron restaurados correctamente.'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Aceptar')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showMessage(context, 'No se pudo restaurar el respaldo: $e');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Respaldo y restauración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('☁️ Respaldo de datos', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Protege la información almacenada en Sabory.', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📁 Respaldo manual', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Crea una copia completa de tus comidas, ventas, gastos, cuentas, pagos y demás información de Sabory.'),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: working ? null : createBackup,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Crear respaldo'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: working ? null : restoreBackup,
                      icon: const Icon(Icons.restore),
                      label: const Text('Restaurar respaldo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (working) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(child: Text('Procesando...')),
          ],
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.info_outline)),
              title: const Text('Importante', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Guarda tu respaldo en un lugar seguro. Al restaurarlo, los datos actuales serán reemplazados por los datos guardados en esa copia.'),
            ),
          ),
        ],
      ),
    );
  }
}