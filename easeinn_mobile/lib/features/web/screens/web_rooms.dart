import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';
import '../../property/data/property_provider.dart';
import '../../property/data/room_provider.dart';
import '../widgets/web_data_table.dart';
import '../widgets/web_form_dialog.dart';

class WebRoomsScreen extends ConsumerStatefulWidget {
  const WebRoomsScreen({super.key});

  @override
  ConsumerState<WebRoomsScreen> createState() => _WebRoomsScreenState();
}

class _WebRoomsScreenState extends ConsumerState<WebRoomsScreen> {
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await ref.read(propertyProvider.notifier).fetchProperties();
    final properties = ref.read(propertyProvider).properties;
    if (properties.isNotEmpty) {
      final pid = properties.first.id;
      await ref.read(roomProvider.notifier).fetchRooms(
            pid,
            status: _statusFilter.isEmpty ? null : _statusFilter,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rooms',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  _filterChip('All', ''),
                  const SizedBox(width: 8),
                  _filterChip('Available', 'available'),
                  const SizedBox(width: 8),
                  _filterChip('Occupied', 'occupied'),
                  const SizedBox(width: 8),
                  _filterChip('Maintenance', 'maintenance'),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Room'),
                    onPressed: () => _showRoomDialog(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: state.isLoading && state.rooms.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.rooms.isEmpty
                    ? const Center(child: Text('No rooms found'))
                    : WebDataTable(
                        searchHint: 'Search rooms...',
                        columns: const [
                          DataColumn(label: Text('Image')),
                          DataColumn(label: Text('Room #')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Floor')),
                          DataColumn(label: Text('Capacity')),
                          DataColumn(label: Text('Price')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: state.rooms.map((r) => _roomRow(r)).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _statusFilter = value);
        _loadData();
      },
      selectedColor: const Color(0xFF1B5E20).withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  List<DataCell> _roomRow(Room r) {
    return [
      DataCell(
        r.images.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  r.images.first,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image, size: 20, color: Colors.grey),
                  ),
                ),
              )
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.image_outlined, size: 20, color: Colors.grey),
              ),
      ),
      DataCell(
        Text(r.roomNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      DataCell(Text(r.roomType)),
      DataCell(Text(r.name.isNotEmpty ? r.name : '-')),
      DataCell(Text('${r.floor}')),
      DataCell(Text('${r.capacity}')),
      DataCell(Text('LKR ${r.basePrice.toStringAsFixed(0)}/night')),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _roomStatusColor(r.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            r.status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _roomStatusColor(r.status),
            ),
          ),
        ),
      ),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 18),
              tooltip: 'View',
              onPressed: () => _showRoomDetail(context, r),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              onPressed: () => _showRoomDialog(context, room: r),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(r),
            ),
          ],
        ),
      ),
    ];
  }

  void _showRoomDetail(BuildContext context, Room r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Room ${r.roomNumber}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Type', r.roomType.toUpperCase()),
                _detailRow('Name', r.name.isNotEmpty ? r.name : '-'),
                _detailRow('Floor', '${r.floor}'),
                _detailRow('Capacity', '${r.capacity}'),
                _detailRow('Price', 'LKR ${r.basePrice.toStringAsFixed(0)}/night'),
                _detailRow('Status', r.status.toUpperCase()),
                if (r.images.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Images', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: r.images.length,
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(r.images[i], fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _showRoomDialog(BuildContext context, {Room? room}) async {
    final properties = ref.read(propertyProvider).properties;
    if (properties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No properties available. Create a property first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final propertyId = properties.first.id;

    final roomNumberController =
        TextEditingController(text: room?.roomNumber ?? '');
    final nameController = TextEditingController(text: room?.name ?? '');
    final capacityController =
        TextEditingController(text: room?.capacity.toString() ?? '1');
    final priceController =
        TextEditingController(text: room?.basePrice.toString() ?? '0');
    final floorController =
        TextEditingController(text: room?.floor.toString() ?? '0');
    String roomType = room?.roomType ?? 'single';
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool isUploading = false;
    List<String> images = List<String>.from(room?.images ?? []);

    Future<void> _pickAndUploadImage(StateSetter setDialogState) async {
      final input = html.FileUploadInputElement()..accept = 'image/*';
      input.click();
      input.onChange.listen((_) async {
        if (input.files == null || input.files!.isEmpty) return;
        final file = input.files!.first;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;
        final bytes = reader.result as Uint8List;

        setDialogState(() => isUploading = true);
        try {
          final api = ref.read(apiClientProvider);
          final formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(bytes, filename: file.name),
          });
          final response = await api.dio.post('/upload/single', data: formData);
          final url = response.data['url'] as String;
          setDialogState(() => images.add(url));
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          setDialogState(() => isUploading = false);
        }
      });
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            scrollable: true,
            title: Text(room == null ? 'Add Room' : 'Edit Room'),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      WebFormField(
                        label: 'Room Number',
                        controller: roomNumberController,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: roomType,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'single', child: Text('Single')),
                            DropdownMenuItem(
                                value: 'double', child: Text('Double')),
                            DropdownMenuItem(
                                value: 'suite', child: Text('Suite')),
                            DropdownMenuItem(
                                value: 'deluxe', child: Text('Deluxe')),
                            DropdownMenuItem(
                                value: 'family', child: Text('Family')),
                            DropdownMenuItem(
                                value: 'presidential',
                                child: Text('Presidential')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => roomType = v);
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Room Type',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      WebFormField(
                        label: 'Name',
                        controller: nameController,
                      ),
                      WebFormField(
                        label: 'Capacity',
                        controller: capacityController,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final val = int.tryParse(v.trim());
                          if (val == null || val < 1) {
                            return 'Must be at least 1';
                          }
                          return null;
                        },
                      ),
                      WebFormField(
                        label: 'Price per Night',
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final val = double.tryParse(v.trim());
                          if (val == null || val <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                      WebFormField(
                        label: 'Floor',
                        controller: floorController,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (int.tryParse(v.trim()) == null) return 'Invalid integer';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Images', style: TextStyle(fontWeight: FontWeight.w600)),
                          TextButton.icon(
                            onPressed: isUploading ? null : () => _pickAndUploadImage(setDialogState),
                            icon: isUploading
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.cloud_upload_outlined, size: 18),
                            label: Text(isUploading ? 'Uploading...' : 'Upload Image'),
                          ),
                        ],
                      ),
                      if (images.isNotEmpty)
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(images[i], width: 100, height: 100, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(width: 100, height: 100, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setDialogState(() => images.removeAt(i)),
                                  child: Container(
                                    margin: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        final data = {
                          'roomNumber': roomNumberController.text.trim(),
                          'roomType': roomType,
                          'name': nameController.text.trim(),
                          'capacity': int.parse(capacityController.text),
                          'basePrice': double.parse(priceController.text),
                          'floor': int.parse(floorController.text),
                          'images': images,
                        };
                        bool success;
                        if (room != null) {
                          success = await ref
                              .read(roomProvider.notifier)
                              .updateRoom(room.id, data);
                        } else {
                          success = await ref
                              .read(roomProvider.notifier)
                              .createRoom(propertyId, data);
                        }
                        if (ctx.mounted) Navigator.pop(ctx, success);
                      },
                child: isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(room == null ? 'Create' : 'Update'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(room == null ? 'Room created' : 'Room updated'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      _loadData();
    }
  }

  void _confirmDelete(Room room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text('Delete room ${room.roomNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final success =
                  await ref.read(roomProvider.notifier).deleteRoom(room.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Room deleted'
                        : ref.read(roomProvider).error ?? 'Failed'),
                    backgroundColor:
                        success ? const Color(0xFF2E7D32) : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _roomStatusColor(String status) {
    switch (status) {
      case 'available':
        return const Color(0xFF2E7D32);
      case 'occupied':
        return const Color(0xFF1565C0);
      case 'maintenance':
        return const Color(0xFFE65100);
      case 'cleaning':
        return const Color(0xFF6A1B9A);
      default:
        return Colors.grey;
    }
  }
}
