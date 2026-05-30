import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';
import '../../property/data/property_provider.dart';
import '../../booking/data/booking_provider.dart';
import '../widgets/web_form_dialog.dart';
import '../widgets/web_data_table.dart';

class WebPropertiesScreen extends ConsumerStatefulWidget {
  const WebPropertiesScreen({super.key});

  @override
  ConsumerState<WebPropertiesScreen> createState() => _WebPropertiesScreenState();
}

class _WebPropertiesScreenState extends ConsumerState<WebPropertiesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(propertyProvider.notifier).fetchProperties();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(propertyProvider);
    final auth = ref.watch(authProvider);
    final isAdmin = auth.user?.isAdmin ?? false;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Properties', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              if (isAdmin)
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Property'),
                  onPressed: () => _showPropertyDialog(context),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: state.isLoading && state.properties.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.properties.isEmpty
                    ? const Center(child: Text('No properties found'))
                    : WebDataTable(
                        searchHint: 'Search properties...',
                        columns: [
                          const DataColumn(label: Text('Image')),
                          const DataColumn(label: Text('Name')),
                          const DataColumn(label: Text('Description')),
                          const DataColumn(label: Text('City')),
                          const DataColumn(label: Text('Country')),
                          const DataColumn(label: Text('Phone')),
                          const DataColumn(label: Text('Rooms')),
                          const DataColumn(label: Text('Status')),
                          if (isAdmin) const DataColumn(label: Text('Actions')),
                        ],
                        rows: state.properties.map((p) => _propertyRow(p, isAdmin)).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  List<DataCell> _propertyRow(Property p, bool isAdmin) {
    return [
      DataCell(
        p.images.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  p.images.first,
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
      DataCell(Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(SizedBox(width: 200, child: Text(p.description, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600)))),
      DataCell(Text(p.address['city']?.toString() ?? '-')),
      DataCell(Text(p.address['country']?.toString() ?? '-')),
      DataCell(Text(p.contact['phone']?.toString() ?? '-')),
      DataCell(Text('${p.totalRooms}')),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: p.isActive ? const Color(0xFF2E7D32).withOpacity(0.1) : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(p.isActive ? 'ACTIVE' : 'INACTIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: p.isActive ? const Color(0xFF2E7D32) : Colors.red)),
      )),
      if (isAdmin)
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.visibility_outlined, size: 18), tooltip: 'View', onPressed: () => _showPropertyDetail(context, p)),
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), tooltip: 'Edit', onPressed: () => _showPropertyDialog(context, property: p)),
            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), tooltip: 'Delete', onPressed: () => _confirmDelete(p)),
          ],
        )),
    ];
  }

  void _showPropertyDetail(BuildContext context, Property p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.name),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(p.description, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                _detailRow('City', p.address['city']?.toString() ?? '-'),
                _detailRow('Country', p.address['country']?.toString() ?? '-'),
                _detailRow('Phone', p.contact['phone']?.toString() ?? '-'),
                _detailRow('Email', p.contact['email']?.toString() ?? '-'),
                _detailRow('Rooms', '${p.totalRooms}'),
                _detailRow('Status', p.isActive ? 'Active' : 'Inactive'),
                if (p.images.isNotEmpty) ...[
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
                    itemCount: p.images.length,
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(p.images[i], fit: BoxFit.cover,
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

  Future<void> _showPropertyDialog(BuildContext context, {Property? property}) async {
    final nameController = TextEditingController(text: property?.name ?? '');
    final descController = TextEditingController(text: property?.description ?? '');
    final cityController = TextEditingController(text: property?.address['city']?.toString() ?? '');
    final countryController = TextEditingController(text: property?.address['country']?.toString() ?? '');
    final phoneController = TextEditingController(text: property?.contact['phone']?.toString() ?? '');
    final emailController = TextEditingController(text: property?.contact['email']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool isUploading = false;
    List<String> images = List<String>.from(property?.images ?? []);

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

    final result = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(property == null ? 'Add Property' : 'Edit Property'),
        content: SizedBox(width: 480, child: Form(key: formKey, child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            WebFormField(
              label: 'Name',
              controller: nameController,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            WebFormField(
              label: 'Description',
              controller: descController,
              maxLines: 3,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            WebFormField(
              label: 'City',
              controller: cityController,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            WebFormField(
              label: 'Country',
              controller: countryController,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            WebFormField(
              label: 'Phone',
              controller: phoneController,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final phoneRegex = RegExp(r'^\+?[0-9\s\-]{8,15}$');
                if (!phoneRegex.hasMatch(v.trim())) return 'Invalid phone number';
                return null;
              },
            ),
            WebFormField(
              label: 'Email',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(v.trim())) return 'Invalid email address';
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
          ]),
        ))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: isSaving ? null : () async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() => isSaving = true);
              final data = {'name': nameController.text.trim(), 'description': descController.text.trim(), 'address': {'city': cityController.text.trim(), 'country': countryController.text.trim()}, 'contact': {'phone': phoneController.text.trim(), 'email': emailController.text.trim()}, 'images': images};
              bool success = property != null
                  ? await ref.read(propertyProvider.notifier).updateProperty(property.id, data)
                  : await ref.read(propertyProvider.notifier).createProperty(data);
              if (ctx.mounted) Navigator.pop(ctx, success);
            },
            child: isSaving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(property == null ? 'Create' : 'Update'),
          ),
        ],
      ),
    ));

    if (result == true && mounted) {
      ref.read(propertyProvider.notifier).fetchProperties();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(property == null ? 'Property created' : 'Property updated'), backgroundColor: const Color(0xFF2E7D32)));
    }
  }

  void _confirmDelete(Property property) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Property'),
      content: Text('Are you sure you want to delete "${property.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Navigator.pop(ctx);
            final success = await ref.read(propertyProvider.notifier).deleteProperty(property.id);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Property deleted' : ref.read(propertyProvider).error ?? 'Failed'), backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red));
          },
          child: const Text('Delete'),
        ),
      ],
    ));
  }
}
