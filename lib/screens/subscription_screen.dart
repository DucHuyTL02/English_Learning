import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/services/app_services.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _selectedPlan = 'monthly';
  bool _loading = true;
  bool _activating = false;
  bool _isActivePremium = false;
  DateTime? _premiumExpiresAt;
  String _currentPlan = '';
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserStatus();
  }

  Future<void> _loadUserStatus() async {
    final user = await AppServices.userRepository.getActiveUser();
    if (!mounted || user == null) return;
    setState(() {
      _userId = user.id;
      _isActivePremium = user.isActivePremium;
      _premiumExpiresAt = user.premiumExpiresAt;
      _currentPlan = user.subscriptionPlan;
      _loading = false;
    });
  }

  Future<void> _activatePremium() async {
    if (_userId == null || _activating) return;
    setState(() => _activating = true);
    try {
      await AppServices.userRepository.activatePremium(
        userId: _userId!,
        plan: _selectedPlan,
      );
      await _loadUserStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Kích hoạt Premium thành công!'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Có lỗi xảy ra. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Gói Premium'),
        backgroundColor: const Color(0xFFFA5C5C),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Premium status card
                  if (_isActivePremium) _buildActiveCard(),
                  if (!_isActivePremium) ...[
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildFeatureList(),
                    const SizedBox(height: 24),
                    _buildPlanSelector(),
                    const SizedBox(height: 24),
                    _buildActivateButton(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildActiveCard() {
    final expiryText = _premiumExpiresAt != null
        ? '${_premiumExpiresAt!.day}/${_premiumExpiresAt!.month}/${_premiumExpiresAt!.year}'
        : '';
    final planLabel = _currentPlan == 'yearly' ? 'Gói Năm' : 'Gói Tháng';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40FA5C5C),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Text('👑', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Premium đang hoạt động',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$planLabel • Hết hạn: $expiryText',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '✅ Tất cả bài học đã được mở khóa',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFEC288), Color(0xFFFBEF76)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(
            child: Text('👑', style: TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Nâng cấp Premium',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Mở khóa toàn bộ bài học và tính năng nâng cao',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildFeatureList() {
    const features = [
      '📚 Mở khóa toàn bộ bài học',
      '🎯 Luyện tập không giới hạn',
      '📊 Theo dõi tiến độ chi tiết',
      '🏆 Tham gia bảng xếp hạng',
      '🔄 Cập nhật nội dung mới',
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tính năng Premium',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                f,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    return Column(
      children: [
        _PlanCard(
          title: 'Gói Tháng',
          price: '99.000₫',
          period: '30 ngày',
          selected: _selectedPlan == 'monthly',
          onTap: () => setState(() => _selectedPlan = 'monthly'),
        ),
        const SizedBox(height: 12),
        _PlanCard(
          title: 'Gói Năm',
          price: '599.000₫',
          period: '365 ngày',
          badge: 'Tiết kiệm ~50%',
          selected: _selectedPlan == 'yearly',
          onTap: () => setState(() => _selectedPlan = 'yearly'),
        ),
      ],
    );
  }

  Widget _buildActivateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _activating ? null : _activatePremium,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFA5C5C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: const StadiumBorder(),
          elevation: 4,
          shadowColor: const Color(0x40FA5C5C),
        ),
        child: _activating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Kích hoạt Premium',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String price;
  final String period;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFFA5C5C) : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      selected ? const Color(0xFFFA5C5C) : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                color: selected ? const Color(0xFFFA5C5C) : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    period,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color:
                    selected ? const Color(0xFFFA5C5C) : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
