import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

class PublicReviewScreen extends ConsumerStatefulWidget {
  final String token;
  const PublicReviewScreen({super.key, required this.token});

  @override
  ConsumerState<PublicReviewScreen> createState() => _PublicReviewScreenState();
}

class _PublicReviewScreenState extends ConsumerState<PublicReviewScreen> {
  bool _isValidating = true;
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  String? _errorMessage;

  // Booking info populated after token validation
  String _guestName = '';
  String _propertyName = '';
  String _roomNumber = '';
  String _roomType = '';
  DateTime? _checkIn;
  DateTime? _checkOut;

  // Review form fields — each rating category is independently scored 1-5
  int _overallRating = 0;
  int _cleanlinessRating = 0;
  int _comfortRating = 0;
  int _locationRating = 0;
  int _serviceRating = 0;
  int _valueRating = 0;
  final _titleController = TextEditingController();
  final _commentController = TextEditingController();
  String _recommendation = 'Yes';

  @override
  void initState() {
    super.initState();
    _validateToken();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _validateToken() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        '/review/validate',
        queryParameters: {'token': widget.token},
      );
      final data = res.data['data'];
      setState(() {
        _guestName = data['guestName'] ?? '';
        _propertyName = data['propertyName'] ?? '';
        _roomNumber = data['roomNumber'] ?? '';
        _roomType = data['roomType'] ?? '';
        _checkIn = data['checkIn'] != null
            ? DateTime.tryParse(data['checkIn'])
            : null;
        _checkOut = data['checkOut'] != null
            ? DateTime.tryParse(data['checkOut'])
            : null;
        _isValidating = false;
      });
    } catch (e) {
      setState(() {
        _isValidating = false;
        _errorMessage =
            'This review link is invalid, has expired, or has already been used.';
      });
    }
  }

  Future<void> _submitReview() async {
    if (_overallRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an overall rating'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/review/submit',
        data: {
          'token': widget.token,
          'rating': _overallRating,
          'title': _titleController.text.trim(),
          'comment': _commentController.text.trim(),
          'categories': {
            if (_cleanlinessRating > 0) 'cleanliness': _cleanlinessRating,
            if (_comfortRating > 0) 'comfort': _comfortRating,
            if (_locationRating > 0) 'location': _locationRating,
            if (_serviceRating > 0) 'service': _serviceRating,
            if (_valueRating > 0) 'value': _valueRating,
          },
          'recommendation': _recommendation,
        },
      );
      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Column(
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 24),
                // Body card
                if (_isValidating)
                  _buildLoadingCard()
                else if (_errorMessage != null)
                  _buildErrorCard()
                else if (_isSubmitted)
                  _buildSuccessCard()
                else
                  _buildReviewForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.hotel, color: Colors.white, size: 40),
          const SizedBox(height: 8),
          const Text(
            'EaseInn',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Guest Review Portal',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return _card(
      child: const Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          children: [
            CircularProgressIndicator(color: Color(0xFF1B5E20)),
            SizedBox(height: 16),
            Text(
              'Validating your review link...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(Icons.link_off, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Invalid Review Link',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1B5E20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Thank You!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your review for $_propertyName has been submitted successfully. We truly appreciate your feedback!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text('⭐⭐⭐⭐⭐', style: TextStyle(fontSize: 28)),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewForm() {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking summary banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF1B5E20).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hotel, color: Color(0xFF1B5E20), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, $_guestName!',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '$_propertyName • Room $_roomNumber${_roomType.isNotEmpty ? ' ($_roomType)' : ''}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        if (_checkIn != null && _checkOut != null)
                          Text(
                            '${_formatDate(_checkIn!)} – ${_formatDate(_checkOut!)}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Overall rating
            const Text(
              'Overall Rating *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'How was your overall experience?',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildStarRow(
              rating: _overallRating,
              size: 44,
              onTap: (r) => setState(() => _overallRating = r),
            ),
            const SizedBox(height: 28),

            // Category ratings
            const Text(
              'Rate by Category',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Optional — help us understand the details.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildCategoryRow(
              '🧹 Cleanliness',
              _cleanlinessRating,
              (r) => setState(() => _cleanlinessRating = r),
            ),
            _buildCategoryRow(
              '🛏 Comfort',
              _comfortRating,
              (r) => setState(() => _comfortRating = r),
            ),
            _buildCategoryRow(
              '📍 Location',
              _locationRating,
              (r) => setState(() => _locationRating = r),
            ),
            _buildCategoryRow(
              '🤝 Service',
              _serviceRating,
              (r) => setState(() => _serviceRating = r),
            ),
            _buildCategoryRow(
              '💰 Value for Money',
              _valueRating,
              (r) => setState(() => _valueRating = r),
            ),
            const SizedBox(height: 24),

            // Review title
            const Text(
              'Review Title',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Summarize your experience in one line...',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),

            // Comment
            const Text(
              'Your Review',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _commentController,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText:
                    'Tell us about your stay — what did you love? What could be improved?',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),

            // Recommendation
            const Text(
              'Would you recommend this property?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.thumb_up, color: Colors.green),
                    label: const Text('Yes, I recommend'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _recommendation == 'Yes'
                            ? Colors.green
                            : Colors.grey.shade300,
                        width: _recommendation == 'Yes' ? 2 : 1,
                      ),
                      backgroundColor: _recommendation == 'Yes'
                          ? Colors.green.withOpacity(0.05)
                          : null,
                    ),
                    onPressed: () => setState(() => _recommendation = 'Yes'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.thumb_down, color: Colors.red),
                    label: const Text('No, I do not recommend'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _recommendation == 'No'
                            ? Colors.red
                            : Colors.grey.shade300,
                        width: _recommendation == 'No' ? 2 : 1,
                      ),
                      backgroundColor: _recommendation == 'No'
                          ? Colors.red.withOpacity(0.05)
                          : null,
                    ),
                    onPressed: () => setState(() => _recommendation = 'No'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit My Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Your review will be visible to the property management team.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(String label, int rating, ValueChanged<int> onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          _buildStarRow(rating: rating, size: 26, onTap: onTap),
        ],
      ),
    );
  }

  Widget _buildStarRow({
    required int rating,
    required double size,
    required ValueChanged<int> onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        return GestureDetector(
          onTap: () => onTap(starIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              starIndex <= rating ? Icons.star : Icons.star_border,
              color: starIndex <= rating
                  ? const Color(0xFFFFC107)
                  : Colors.grey.shade400,
              size: size,
            ),
          ),
        );
      }),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
