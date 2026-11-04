import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';
import '../features/devices/domain/device.dart';
import '../features/devices/domain/device_repository.dart';
import '../features/locations/domain/location.dart';
import '../features/locations/domain/location_repository.dart';

const _explorerAccent = AppTheme.primary;

class InventoryExplorerScreen extends StatefulWidget {
  const InventoryExplorerScreen({super.key});

  @override
  State<InventoryExplorerScreen> createState() =>
      _InventoryExplorerScreenState();
}

class _InventoryExplorerScreenState extends State<InventoryExplorerScreen> {
  final LocationRepository _locationRepository =
      GetIt.instance<LocationRepository>();
  final DeviceRepository _deviceRepository = GetIt.instance<DeviceRepository>();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<_DeviceItem> _devices = const [];
  List<Location> _locationOptions = const [];
  List<String> _classificationOptions = const [];
  String? _selectedClassification;
  String? _selectedLocationCode;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final locationResult = await _locationRepository.findLocations(
      limit: 100,
      offset: 0,
    );
    final deviceResult = await _deviceRepository.findDevices(
      search: _searchController.text,
      classification: _selectedClassification,
      locationCode: _selectedLocationCode,
      limit: 100,
      offset: 0,
    );
    final classificationsResult = await _deviceRepository.findClassifications();
    final locationsByCode = locationResult.match(
      (_) => <String, Location>{},
      (locations) => <String, Location>{
        for (final location in locations) location.code.toUpperCase(): location,
      },
    );

    final nextDevices = deviceResult.match(
      (failure) => <_DeviceItem>[],
      (devices) => devices
          .map((device) {
            final location = locationsByCode[device.locationCode.toUpperCase()];
            return _DeviceItem(
              inventoryNumber: device.inventoryNumber,
              name: device.name,
              classification: device.classification,
              locationCode: device.locationCode,
              locationName: device.locationName ?? location?.name,
            );
          })
          .toList(growable: false),
    );

    final failure = locationResult.match(
      (failure) => failure.message,
      (_) => null,
    );
    final deviceFailure = deviceResult.match(
      (failure) => failure.message,
      (_) => null,
    );
    final classificationsFailure = classificationsResult.match(
      (failure) => failure.message,
      (_) => null,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _devices = nextDevices;
        _locationOptions = locationResult.match(
          (_) => const <Location>[],
          (locations) => locations,
        );
        _classificationOptions = classificationsResult.match(
          (_) => const <String>[],
          (classifications) => classifications,
        );
        _error = failure ?? deviceFailure ?? classificationsFailure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: SpinKitPulse(color: _explorerAccent, size: 54)),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Explorador de inventario')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.circleAlert, size: 48),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Explorador de inventario')),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _DevicesTab(
              items: _devices,
              onEdit: _editDevice,
              onDelete: _deleteDevice,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDevice,
        backgroundColor: _explorerAccent,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Equipo'),
      ),
    );
  }

  Widget _buildFilters() {
    final classifications = [..._classificationOptions];
    if (_selectedClassification != null &&
        !classifications.contains(_selectedClassification)) {
      classifications.insert(0, _selectedClassification!);
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onSubmitted: (_) => _loadData(),
              decoration: InputDecoration(
                hintText: 'Buscar equipo, número o clasificación',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Buscar',
                  onPressed: _loadData,
                  icon: const Icon(LucideIcons.search),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedClassification,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Clasificación',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ...classifications.map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedClassification = value);
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLocationCode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ubicación',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      if (_selectedLocationCode != null &&
                          !_locationOptions.any(
                            (location) =>
                                location.code == _selectedLocationCode,
                          ))
                        DropdownMenuItem(
                          value: _selectedLocationCode,
                          child: Text(
                            _locationNameForCode(_selectedLocationCode!),
                          ),
                        ),
                      ..._locationOptions.map(
                        (location) => DropdownMenuItem(
                          value: location.code,
                          child: Text(
                            location.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedLocationCode = value);
                      _loadData();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _locationNameForCode(String code) {
    for (final location in _locationOptions) {
      if (location.code == code) return location.name;
    }
    return code;
  }

  Future<void> _addDevice() async {
    final result = await _showDeviceForm();
    if (result == null) return;

    final saveResult = await _deviceRepository.create(
      Device(
        inventoryNumber: result.inventoryNumber,
        name: result.name,
        classification: result.classification,
        locationCode: result.locationCode,
      ),
    );
    if (!mounted) return;

    if (saveResult.isLeft()) {
      final failure = saveResult.match((value) => value, (_) => null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure?.message ?? 'No se pudo crear el equipo.'),
        ),
      );
      return;
    }

    await _loadData();
  }

  Future<void> _editDevice(_DeviceItem item) async {
    final result = await _showDeviceForm(initial: item);
    if (result == null) return;

    final saveResult = await _deviceRepository.update(
      Device(
        inventoryNumber: result.inventoryNumber,
        name: result.name,
        classification: result.classification,
        locationCode: result.locationCode,
      ),
    );
    if (!mounted) return;

    if (saveResult.isLeft()) {
      final failure = saveResult.match((value) => value, (_) => null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure?.message ?? 'No se pudo actualizar el equipo.'),
        ),
      );
      return;
    }

    await _loadData();
  }

  Future<void> _deleteDevice(_DeviceItem item) async {
    final deleteResult = await _deviceRepository.delete(item.inventoryNumber);
    if (!mounted) return;
    if (deleteResult.isLeft()) {
      final failure = deleteResult.match((value) => value, (_) => null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure?.message ?? 'No se pudo eliminar el equipo.'),
        ),
      );
      return;
    }
    await _loadData();
  }

  Future<_DeviceItem?> _showDeviceForm({_DeviceItem? initial}) {
    final controllerInventory = TextEditingController(
      text: initial?.inventoryNumber ?? '',
    );
    final controllerName = TextEditingController(text: initial?.name ?? '');
    final controllerClassification = TextEditingController(
      text: initial?.classification ?? '',
    );
    final controllerLocation = TextEditingController(
      text: initial?.locationCode ?? '',
    );
    final formKey = GlobalKey<FormState>();

    return showModalBottomSheet<_DeviceItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  initial == null ? 'Nuevo equipo' : 'Editar equipo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controllerInventory,
                  decoration: const InputDecoration(
                    labelText: 'Número de inventario',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'El número es obligatorio'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controllerName,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'El nombre es obligatorio'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controllerClassification,
                  decoration: const InputDecoration(labelText: 'Clasificación'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'La clasificación es obligatoria'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controllerLocation,
                  decoration: const InputDecoration(
                    labelText: 'Código de ubicación',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'La ubicación es obligatoria'
                      : null,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(context).pop(
                      _DeviceItem(
                        inventoryNumber: controllerInventory.text
                            .trim()
                            .toUpperCase(),
                        name: controllerName.text.trim(),
                        classification: controllerClassification.text.trim(),
                        locationCode: controllerLocation.text
                            .trim()
                            .toUpperCase(),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.save),
                  label: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DevicesTab extends StatelessWidget {
  const _DevicesTab({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  final List<_DeviceItem> items;
  final ValueChanged<_DeviceItem> onEdit;
  final ValueChanged<_DeviceItem> onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(label: 'No hay equipos aún');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Slidable(
          key: ValueKey(item.inventoryNumber),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.42,
            children: [
              SlidableAction(
                onPressed: (_) => onEdit(item),
                backgroundColor: _explorerAccent,
                foregroundColor: Colors.white,
                icon: LucideIcons.pencil,
                label: 'Editar',
                borderRadius: BorderRadius.circular(16),
              ),
              SlidableAction(
                onPressed: (_) => onDelete(item),
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
                icon: LucideIcons.trash2,
                label: 'Eliminar',
                borderRadius: BorderRadius.circular(16),
              ),
            ],
          ),
          child: _DeviceCard(item: item)
              .animate(delay: (index * 45).ms)
              .fadeIn(duration: 260.ms)
              .slideX(
                begin: .04,
                end: 0,
                duration: 260.ms,
                curve: Curves.easeOutCubic,
              ),
        );
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.item});

  final _DeviceItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            LucideIcons.package,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _InfoBadge(icon: LucideIcons.tag, label: item.inventoryNumber),
              _InfoBadge(
                icon: LucideIcons.mapPin,
                label: item.locationName ?? item.locationCode,
              ),
              _InfoBadge(icon: LucideIcons.layers2, label: item.classification),
            ],
          ),
        ),
        onTap: () => _showDeviceDetails(context),
      ),
    );
  }

  void _showDeviceDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              label: 'Número de inventario',
              value: item.inventoryNumber,
            ),
            _DetailRow(label: 'Clasificación', value: item.classification),
            _DetailRow(
              label: 'Ubicación',
              value: item.locationName ?? item.locationCode,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(
              '''
              <svg xmlns="http://www.w3.org/2000/svg" width="88" height="88" viewBox="0 0 24 24" fill="none" stroke="#168BC2" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="4" width="18" height="16" rx="3"/>
                <path d="M8 9h8M8 13h5M8 17h3"/>
              </svg>
              ''',
              width: 88,
              height: 88,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceItem {
  const _DeviceItem({
    required this.inventoryNumber,
    required this.name,
    required this.classification,
    required this.locationCode,
    this.locationName,
  });

  final String inventoryNumber;
  final String name;
  final String classification;
  final String locationCode;
  final String? locationName;
}
