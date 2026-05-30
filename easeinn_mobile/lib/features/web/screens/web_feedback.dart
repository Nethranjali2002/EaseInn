import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../auth/data/auth_provider.dart';
import '../../property/data/property_provider.dart';
import 'package:intl/intl.dart';

class WebFeedbackScreen extends ConsumerStatefulWidget {
  const WebFeedbackScreen({super.key});

  @override
  ConsumerState<WebFeedbackScreen> createState() => _WebFeedbackScreenState();
}

class _WebFeedbackScreenState extends ConsumerState<WebFeedbackScreen> {
  String? _selectedPropertyId;
  List<Map<String, dynamic>> _feedback = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = false;
  int? _filterRating; // null = all

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final props = ref.read(propertyProvider).properties;
      if (props.isNotEmpty) {
        setState(() => _selectedPropertyId = props.first.id);
        _loadFeedback();
      }
    });
  }

  Future<void> _loadFeedback() async {
    if (_selectedPropertyId == null) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final qp = <String, dynamic>{};
      if (_filterRating != null) qp['minRating'] = _filterRating;
      final results = await Future.wait([
        api.get('/properties/$_selectedPropertyId/feedback', queryParameters: qp),
        api.get('/properties/$_selectedPropertyId/feedback/stats'),
      ]);
      setState(() {
        _feedback = (results[0].data['data']['feedback'] as List).cast<Map<String, dynamic>>();
        _stats = results[1].data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _respondToFeedback(String feedbackId, String guestName) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Respond to $guestName'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write a thoughtful response...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Send Response', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        final api = ref.read(apiClientProvider);
        await api.patch('/feedback/$feedbackId/respond', data: {'text': result});
        _loadFeedback();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Response sent successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _togglePublic(String feedbackId, bool currentPublic) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/feedback/$feedbackId', data: {'isPublic': !currentPublic});
      _loadFeedback();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final props = ref.watch(propertyProvider).properties;
    final auth = ref.watch(authProvider);
    final isAdmin = auth.user?.role == 'admin';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Guest Reviews', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Manage and respond to guest feedback', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
              Row(
                children: [
                  // Rating filter
                  DropdownButton<int?>(
                    value: _filterRating,
                    hint: const Text('All Ratings'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Ratings')),
                      ...List.generate(5, (i) => DropdownMenuItem(
                        value: 5 - i,
                        child: Row(children: [
                          Icon(Icons.star, color: Colors.amber, size: 14),
                          Text(' ${5 - i} Stars'),
                        ]),
                      )),
                    ],
                    onChanged: (v) { setState(() => _filterRating = v); _loadFeedback(); },
                  ),
                  const SizedBox(width: 16),
                  // Property selector
                  if (props.isNotEmpty)
                    DropdownButton<String>(
                      value: _selectedPropertyId,
                      hint: const Text('Select Property'),
                      items: props.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                      onChanged: (v) { setState(() { _selectedPropertyId = v; _filterRating = null; }); _loadFeedback(); },
                    ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFeedback, tooltip: 'Refresh'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats bar
          if (_stats != null) _buildStatsBar(_stats!),
          const SizedBox(height: 16),

          // Reviews list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _feedback.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.reviews_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('No reviews yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('Reviews appear here after guests check out and submit their feedback.',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _feedback.length,
                        itemBuilder: (ctx, i) => _buildFeedbackCard(_feedback[i], isAdmin),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(Map<String, dynamic> stats) {
    final avg = (stats['avgRating'] ?? 0.0) as num;
    final total = (stats['totalReviews'] ?? 0) as num;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20).withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          // Average score
          Column(
            children: [
              Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
              _buildStars(avg.toDouble(), size: 18),
              Text('${total.toInt()} reviews', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 24),
          const VerticalDivider(width: 1),
          const SizedBox(width: 24),
          // Star breakdown
          Expanded(
            child: Column(
              children: [
                _buildRatingBar('5 ⭐', stats['fiveStar'] ?? 0, total.toInt(), Colors.green),
                _buildRatingBar('4 ⭐', stats['fourStar'] ?? 0, total.toInt(), Colors.teal),
                _buildRatingBar('3 ⭐', stats['threeStar'] ?? 0, total.toInt(), Colors.amber),
                _buildRatingBar('2 ⭐', stats['twoStar'] ?? 0, total.toInt(), Colors.orange),
                _buildRatingBar('1 ⭐', stats['oneStar'] ?? 0, total.toInt(), Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(String label, dynamic count, int total, Color color) {
    final c = (count as num).toInt();
    final pct = total > 0 ? c / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text(label, style: const TextStyle(fontSize: 11))),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.grey.shade200,
                color: color,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 20, child: Text('$c', style: const TextStyle(fontSize: 11, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> fb, bool isAdmin) {
    final rating = (fb['rating'] ?? 0) as num;
    final hasResponse = fb['response'] != null && (fb['response']['text'] as String?)?.isNotEmpty == true;
    final categories = fb['categories'] as Map<String, dynamic>?;
    final createdAt = fb['createdAt'] != null ? DateTime.tryParse(fb['createdAt']) : null;
    final isPublic = fb['isPublic'] ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Guest info row
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF1B5E20).withOpacity(0.12),
                  child: Text(
                    (fb['guestName'] as String? ?? 'G').isNotEmpty ? (fb['guestName'] as String)[0].toUpperCase() : 'G',
                    style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(fb['guestName'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          if (!isPublic)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                              child: const Text('Hidden', style: TextStyle(fontSize: 10, color: Colors.orange)),
                            ),
                        ],
                      ),
                      if (fb['guestEmail'] != null)
                        Text(fb['guestEmail'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStars(rating.toDouble(), size: 18),
                    if (createdAt != null)
                      Text(DateFormat('dd MMM yyyy').format(createdAt),
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ],
            ),

            // Review title
            if ((fb['title'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(fb['title']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],

            // Comment
            if ((fb['comment'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(fb['comment']!, style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
            ],

            // Category scores
            if (categories != null && categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (categories['cleanliness'] != null) _CategoryChip('Cleanliness', categories['cleanliness']),
                  if (categories['comfort'] != null) _CategoryChip('Comfort', categories['comfort']),
                  if (categories['location'] != null) _CategoryChip('Location', categories['location']),
                  if (categories['service'] != null) _CategoryChip('Service', categories['service']),
                  if (categories['value'] != null) _CategoryChip('Value', categories['value']),
                ],
              ),
            ],

            // Manager response
            if (hasResponse) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.reply, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Management Response', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                          const SizedBox(height: 4),
                          Text(fb['response']['text'] ?? '', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Actions row
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isAdmin)
                  TextButton.icon(
                    icon: Icon(isPublic ? Icons.visibility_off : Icons.visibility, size: 16),
                    label: Text(isPublic ? 'Hide' : 'Show'),
                    onPressed: () => _togglePublic(fb['_id'], isPublic),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                  ),
                if (!hasResponse) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.reply, size: 16),
                    label: const Text('Respond'),
                    onPressed: () => _respondToFeedback(fb['_id'], fb['guestName'] ?? 'Guest'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStars(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (i < rating) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.grey.shade400, size: size);
        }
      }),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final dynamic score;
  const _CategoryChip(this.label, this.score);

  @override
  Widget build(BuildContext context) {
    final s = (score as num).toInt();
    final color = s >= 4 ? Colors.green : s == 3 ? Colors.amber : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Icon(Icons.star, size: 11, color: color),
          Text('$s', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
