import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import 'main.dart';
import 'admin_dashboard.dart';
import 'cart_manager.dart';
import 'wishlist_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CartManager _cart = CartManager.instance;
  final WishlistManager _wishlist = WishlistManager.instance;

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  String _searchFilter = '';
  String _genderFilter = 'ALL';
  String _selectedCategory = 'HOME';
  bool _isArabic = false;

  int _currentPage = 1;
  final int _itemsPerPage = 16;
  int _currentHeroIndex = 0;
  Timer? _heroTimer;

  final List<Map<String, String>> _heroSlides = [
    {
      'title': 'WALK\nBEYOND\nLIMITS',
      'title_ar': 'تخطَّ\nكل\nالحدود',
      'desc': 'Premium sneakers crafted for comfort, style and everyday performance.',
      'desc_ar': 'أحذية رياضية فاخرة صُممت لتجمع بين الراحة والأناقة والأداء اليومي.',
      'image': 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=1200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'STREET\nLEGACY\nEDITION',
      'title_ar': 'إصدار\nتراث\nالشارع',
      'desc': 'Engineered with cutting-edge cushioning and iconic timeless silhouettes.',
      'desc_ar': 'مصممة بأحدث تقنيات التوسيد وبطابع بصري كلاسيكي يدوم.',
      'image': 'https://images.unsplash.com/photo-1608231387042-66d1773070a5?w=1200&auto=format&fit=crop&q=80',
    },
    {
      'title': 'MINIMAL\nURBAN\nFORCE',
      'title_ar': 'القوة\nالحضرية\nالمطلقة',
      'desc': 'Monochromatic aesthetics for those who command the streets in silence.',
      'desc_ar': 'تصاميم أحادية اللون مستوحاة من نبض المدينة وأناقتها الهادئة.',
      'image': 'https://images.unsplash.com/photo-1552346154-21d32810aba3?w=1200&auto=format&fit=crop&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cart.addListener(_updateUI);
      _wishlist.addListener(_updateUI);
    });
    _fetchProducts();
    _startHeroAutoPlay();
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _cart.removeListener(_updateUI);
    _wishlist.removeListener(_updateUI);
    super.dispose();
  }

  String _safeId(dynamic id) {
    if (id == null) return '00000000';
    String s = id.toString();
    return s.length > 8 ? s.substring(0, 8) : s.padLeft(8, '0');
  }

  void _startHeroAutoPlay() {
    _heroTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (mounted && _selectedCategory == 'HOME') {
        setState(() {
          _currentHeroIndex = (_currentHeroIndex + 1) % _heroSlides.length;
        });
      }
    });
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('products')
          .select('*, product_variants(*)')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response ?? []);

      if (mounted) {
        setState(() {
          _allProducts = data;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = List.from(_allProducts);

    if (_searchFilter.trim().isNotEmpty) {
      temp = temp.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        return name.contains(_searchFilter.toLowerCase().trim());
      }).toList();
      if (_selectedCategory == 'HOME') _selectedCategory = 'SHOP';
    } else {
      if (_genderFilter != 'ALL') {
        temp = temp.where((p) => (p['category']?.toString().toLowerCase() ?? 'men') == _genderFilter.toLowerCase()).toList();
      }
      
      if (_selectedCategory == 'NEW ARRIVALS') {
        temp = temp.where((p) => p['is_new_arrival'] == true).toList();
      } else if (_selectedCategory == 'BEST SELLERS') {
        temp = temp.where((p) => p['is_best_seller'] == true).toList();
      }
    }

    _filteredProducts = temp;
    final int totalPages = (_filteredProducts.length / _itemsPerPage).ceil();
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    } else if (totalPages == 0) {
      _currentPage = 1;
    }
  }

  void _changeCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _genderFilter = 'ALL'; 
      _searchFilter = '';
      _currentPage = 1;
      _applyFilters();
    });
  }

  List<String> _extractImages(Map<String, dynamic> product) {
    final variants = product['product_variants'] as List<dynamic>?;
    final firstVariant = (variants != null && variants.isNotEmpty) ? variants[0] : null;
    List<String> images = [];
    if (firstVariant != null) {
      final dynamic urls = firstVariant['image_urls'];
      if (urls != null && urls is List && urls.isNotEmpty) {
        images = urls.map((e) {
          String s = e.toString();
          s = s.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').trim();
          return s;
        }).where((s) => s.startsWith('http')).toList();
      } else if (firstVariant['image_url'] != null) {
        String s = firstVariant['image_url'].toString().trim();
        if (s.startsWith('http')) images = [s];
      }
    }
    if (images.isEmpty) {
      images = ['https://images.unsplash.com/photo-1542291026-7eec264c27ff'];
    }
    return images;
  }

  void _showProductDetailsModal(Map<String, dynamic> product) {
    List<String> images = _extractImages(product);
    final variants = product['product_variants'] as List<dynamic>?;
    final firstVariant = (variants != null && variants.isNotEmpty) ? variants[0] : null;
    final variantId = firstVariant?['id'];
    final stock = firstVariant != null ? (firstVariant['stock_quantity'] ?? 10) : 10;
    
    final sizes = ['40', '41', '42', '43', '44', '45'];
    String selectedSize = '42';
    int selectedImageIndex = 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 750),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Image.network(
                                  images[selectedImageIndex],
                                  key: ValueKey<String>(images[selectedImageIndex]),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Center(child: Icon(Icons.broken_image, size: 60, color: isDark ? Colors.white24 : Colors.grey)),
                                ),
                              ),
                            ),
                            if (images.length > 1) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 80,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(images.length, (index) {
                                    final isSelected = selectedImageIndex == index;
                                    return GestureDetector(
                                      onTap: () => setModalState(() => selectedImageIndex = index),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.symmetric(horizontal: 8),
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF262626) : Colors.white,
                                          border: Border.all(color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent, width: 2),
                                          image: DecorationImage(image: NetworkImage(images[index]), fit: BoxFit.cover),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(64),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  stock > 0 ? (_isArabic ? 'متوفر ($stock قطعة)' : 'IN STOCK ($stock UNITS)') : (_isArabic ? 'نفذت الكمية' : 'SOLD OUT'),
                                  style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: stock > 0 ? (isDark ? Colors.greenAccent : Colors.green[700]) : (isDark ? Colors.redAccent : Colors.red[700])),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  color: isDark ? Colors.white12 : Colors.black12,
                                  child: Text((product['category'] ?? 'Men').toString().toUpperCase(), style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Text(product['name'] ?? '', style: GoogleFonts.montserrat(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1, height: 1.1, color: isDark ? Colors.white : Colors.black)),
                            const SizedBox(height: 16),
                            Text('\$${product['base_price']}', style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                            const SizedBox(height: 32),
                            Text(
                              product['description'] != null && product['description'].toString().trim().isNotEmpty
                                  ? product['description']
                                  : (_isArabic ? 'حذاء فاخر مصنوع يدوياً مصمم لضمان أقصى درجات التحمل والأناقة اليومية.' : 'Handcrafted luxury silhouette built for high-performance durability and effortless daily styling.'),
                              style: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black54, height: 1.6, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 48),
                            Text(_isArabic ? 'اختر المقاس (EU)' : 'SELECT SIZE (EU)', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black)),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: sizes.map((s) {
                                final isSelected = s == selectedSize;
                                return InkWell(
                                  onTap: () => setModalState(() => selectedSize = s),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 54,
                                    height: 54,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0xFF141414) : Colors.white),
                                      border: Border.all(color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB)), width: 1.5),
                                    ),
                                    child: Text(s, style: GoogleFonts.montserrat(color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white : Colors.black), fontWeight: FontWeight.bold, fontSize: 15)),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 48),
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.white : Colors.black,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  elevation: 0,
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                ),
                                onPressed: stock <= 0
                                    ? null
                                    : () {
                                        _cart.addItem(
                                          productId: product['id'],
                                          variantId: variantId,
                                          name: product['name'],
                                          price: double.tryParse('${product['base_price']}') ?? 0.0,
                                          imageUrl: images[0],
                                          size: selectedSize,
                                        );
                                        Navigator.pop(ctx);
                                        _openCartDrawer();
                                      },
                                child: Text(
                                  stock > 0 ? (_isArabic ? 'إضافة إلى الحقيبة' : 'ADD TO BAG') : (_isArabic ? 'غير متوفر' : 'OUT OF STOCK'),
                                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 24,
                  right: 24,
                  child: IconButton(
                    icon: Icon(Icons.close, size: 28, color: isDark ? Colors.white54 : Colors.black54),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCartDrawer() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cart',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: Offset(_isArabic ? -1 : 1, 0), end: Offset.zero)
              .animate(CurveTween(curve: Curves.easeOutQuart).animate(anim1)),
          child: Align(
            alignment: _isArabic ? Alignment.centerLeft : Alignment.centerRight,
            child: Material(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              child: SizedBox(
                width: 500,
                height: double.infinity,
                child: StatefulBuilder(
                  builder: (context, setDrawerState) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(40, 40, 40, 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isArabic ? 'حقيبة التسوق (${_cart.totalCount})' : 'SHOPPING BAG (${_cart.totalCount})',
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 24, color: isDark ? Colors.white54 : Colors.black54),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6)),
                      Expanded(
                        child: _cart.items.isEmpty
                            ? _buildPremiumEmptyCartState(isDark)
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                                itemCount: _cart.items.length,
                                separatorBuilder: (_, __) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Divider(height: 1, color: isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6)),
                                ),
                                itemBuilder: (context, idx) {
                                  final item = _cart.items[idx];
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: Image.network(
                                            item.imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_,__,___) => Icon(Icons.image, color: isDark ? Colors.white12 : Colors.black12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.name, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : Colors.black)),
                                            const SizedBox(height: 8),
                                            Text('${_isArabic ? "المقاس" : "Size"}: EU ${item.size}', style: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 16),
                                            Container(
                                              width: 100,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB)),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      _cart.updateQuantity(idx, -1);
                                                      setDrawerState(() {});
                                                    },
                                                    child: SizedBox(
                                                      width: 32,
                                                      child: Center(child: Icon(Icons.remove, size: 14, color: isDark ? Colors.white70 : Colors.black87)),
                                                    ),
                                                  ),
                                                  Text('${item.quantity}', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black)),
                                                  InkWell(
                                                    onTap: () {
                                                      _cart.updateQuantity(idx, 1);
                                                      setDrawerState(() {});
                                                    },
                                                    child: SizedBox(
                                                      width: 32,
                                                      child: Center(child: Icon(Icons.add, size: 14, color: isDark ? Colors.white70 : Colors.black87)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text('\$${(item.price * item.quantity).toStringAsFixed(2)}', style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black, fontSize: 15, fontWeight: FontWeight.w900)),
                                    ],
                                  );
                                },
                              ),
                      ),
                      if (_cart.items.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB),
                            border: Border(top: BorderSide(color: isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB))),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_isArabic ? 'بيانات التوصيل السريع' : 'EXPRESS DELIVERY DETAILS', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5, color: isDark ? Colors.white54 : Colors.black54)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: _buildCartTextField(nameCtrl, _isArabic ? 'الاسم بالكامل' : 'Full Name', isDark)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildCartTextField(phoneCtrl, _isArabic ? 'رقم الهاتف' : 'Contact Phone', isDark)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildCartTextField(addressCtrl, _isArabic ? 'العنوان بالتفصيل' : 'Shipping Address', isDark),
                              const SizedBox(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_isArabic ? 'الإجمالي:' : 'SUBTOTAL:', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                                  Text('\$${_cart.totalPrice.toStringAsFixed(2)}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 26, color: isDark ? Colors.white : Colors.black)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? Colors.white : Colors.black,
                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                    elevation: 0,
                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                  ),
                                  onPressed: () async {
                                    if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty || addressCtrl.text.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isArabic ? 'يرجى إكمال جميع بيانات الشحن' : 'Please complete all shipping address fields', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))));
                                      return;
                                    }

                                    final orderRes = await _supabase.from('orders').insert({
                                      'customer_name': nameCtrl.text.trim(),
                                      'customer_phone': phoneCtrl.text.trim(),
                                      'shipping_address': addressCtrl.text.trim(),
                                      'total_amount': _cart.totalPrice,
                                      'status': 'pending',
                                      'payment_method': 'cash_on_delivery',
                                    }).select().single();

                                    for (var item in _cart.items) {
                                      await _supabase.from('order_items').insert({
                                        'order_id': orderRes['id'],
                                        'product_variant_id': item.variantId,
                                        'quantity': item.quantity,
                                        'price_at_time': item.price,
                                      });

                                      if (item.variantId != null) {
                                        final String vId = item.variantId!;
                                        final variantData = await _supabase
                                            .from('product_variants')
                                            .select('stock_quantity')
                                            .eq('id', vId)
                                            .single();

                                        int currentStock = variantData['stock_quantity'] ?? 0;
                                        int newStock = currentStock - item.quantity;
                                        if (newStock < 0) newStock = 0;

                                        await _supabase
                                            .from('product_variants')
                                            .update({'stock_quantity': newStock})
                                            .eq('id', vId);
                                      }
                                    }

                                    _cart.clearCart();
                                    Navigator.pop(context);
                                    _fetchProducts();

                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                        title: Text(_isArabic ? 'تم تأكيد طلبك بنجاح! 🎉' : 'Order Confirmed! 🎉', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
                                        content: Text(
                                          _isArabic ? 'شكراً لك، تم تسجيل طلبك وسنتواصل معك قريباً لتأكيد موعد التوصيل.' : 'Thank you. We received your order and will contact you shortly.',
                                          style: GoogleFonts.montserrat(height: 1.5, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(_isArabic ? 'متابعة التسوق' : 'CONTINUE SHOPPING', style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: Text(
                                    _isArabic ? 'تأكيد الطلب (الدفع عند الاستلام)' : 'CONFIRM ORDER (CASH)',
                                    style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // شاشة المفضلة المنبثقة (Wishlist Drawer)
  // ==========================================================
  void _openWishlistDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Wishlist',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: Offset(_isArabic ? -1 : 1, 0), end: Offset.zero)
              .animate(CurveTween(curve: Curves.easeOutQuart).animate(anim1)),
          child: Align(
            alignment: _isArabic ? Alignment.centerLeft : Alignment.centerRight,
            child: Material(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              child: SizedBox(
                width: 500,
                height: double.infinity,
                child: StatefulBuilder(
                  builder: (context, setWishState) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(40, 40, 40, 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isArabic ? 'قائمة المفضلة (${_wishlist.totalCount})' : 'WISHLIST (${_wishlist.totalCount})',
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 24, color: isDark ? Colors.white54 : Colors.black54),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6)),
                      Expanded(
                        child: _wishlist.items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.favorite_border, size: 80, color: isDark ? Colors.white12 : Colors.black12),
                                    const SizedBox(height: 32),
                                    Text(
                                      _isArabic ? 'قائمة المفضلة فارغة' : 'YOUR WISHLIST IS EMPTY',
                                      style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _isArabic ? 'احفظ الكوتشيات المميزة للرجوع إليها لاحقاً.' : 'Save luxury sneakers you love for later.',
                                      style: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w500, fontSize: 13),
                                    ),
                                    const SizedBox(height: 48),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isDark ? Colors.white : Colors.black,
                                        side: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5),
                                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _changeCategory('SHOP');
                                      },
                                      child: Text(
                                        _isArabic ? 'تصفح المتجر' : 'EXPLORE COLLECTION',
                                        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12),
                                      ),
                                    )
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                                itemCount: _wishlist.items.length,
                                separatorBuilder: (_, __) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Divider(height: 1, color: isDark ? const Color(0xFF262626) : const Color(0xFFF3F4F6)),
                                ),
                                itemBuilder: (context, idx) {
                                  final item = _wishlist.items[idx];
                                  final images = _extractImages(item);
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: Image.network(
                                            images[0],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_,__,___) => Icon(Icons.image, color: isDark ? Colors.white12 : Colors.black12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item['name'] ?? '', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : Colors.black)),
                                            const SizedBox(height: 6),
                                            Text('\$${item['base_price']}', style: GoogleFonts.montserrat(color: isDark ? Colors.white70 : Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: isDark ? Colors.white : Colors.black,
                                                    foregroundColor: isDark ? Colors.black : Colors.white,
                                                    elevation: 0,
                                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                  ),
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    _showProductDetailsModal(item);
                                                  },
                                                  child: Text(
                                                    _isArabic ? 'عرض الخيارات' : 'SELECT SIZE',
                                                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                                  onPressed: () {
                                                    _wishlist.removeItem(item['id']);
                                                    setWishState(() {});
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumEmptyCartState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 80, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 32),
          Text(
            _isArabic ? 'حقيبة التسوق الخاصة بك فارغة' : 'YOUR BAG IS EMPTY',
            style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Text(
            _isArabic ? 'يبدو أنك لم تقم بإضافة أي منتجات بعد.' : 'Looks like you haven\'t added any items yet.',
            style: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w500, fontSize: 13),
          ),
          const SizedBox(height: 48),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : Colors.black,
              side: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: () {
              Navigator.pop(context);
              _changeCategory('SHOP');
            },
            child: Text(
              _isArabic ? 'ابدأ التسوق' : 'START SHOPPING',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCartTextField(TextEditingController controller, String label, bool isDark) {
    return TextField(
      controller: controller,
      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: isDark ? const Color(0xFF141414) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5)),
      ),
    );
  }

  void _showCustomerAccountModal() {
    final searchPhoneCtrl = TextEditingController();
    List<Map<String, dynamic>> customerOrders = [];
    bool isSearching = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setAccState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(_isArabic ? 'بوابة العميل' : 'CUSTOMER PORTAL', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isArabic ? 'أدخل رقم هاتفك المسجل لعرض ومتابعة شحناتك السابقة:' : 'Track your recent sneaker orders by entering your phone number:',
                  style: GoogleFonts.montserrat(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchPhoneCtrl,
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: _isArabic ? 'رقم الهاتف' : 'Phone Number',
                          labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                          border: const OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : Colors.grey)),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white : Colors.black)),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.white : Colors.black, foregroundColor: isDark ? Colors.black : Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                        onPressed: () async {
                          if (searchPhoneCtrl.text.isEmpty) return;
                          setAccState(() => isSearching = true);
                          final data = await _supabase.from('orders').select().eq('customer_phone', searchPhoneCtrl.text.trim());
                          setAccState(() {
                            customerOrders = List<Map<String, dynamic>>.from(data ?? []);
                            isSearching = false;
                          });
                        },
                        child: Text(_isArabic ? 'بحث' : 'FIND', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (isSearching)
                  Center(child: Padding(padding: const EdgeInsets.all(16), child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black)))
                else if (customerOrders.isNotEmpty)
                  SizedBox(
                    height: 250,
                    child: ListView.separated(
                      itemCount: customerOrders.length,
                      separatorBuilder: (_, __) => Divider(color: isDark ? const Color(0xFF262626) : Colors.grey[300]),
                      itemBuilder: (context, i) {
                        final ord = customerOrders[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${_isArabic ? "طلب رقم" : "Order"} #${_safeId(ord['id'])}', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                          subtitle: Text('${_isArabic ? "الحالة" : "Status"}: ${ord['status'].toString().toUpperCase()} • ${_isArabic ? "الإجمالي" : "Total"}: \$${ord['total_amount']}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                        );
                      },
                    ),
                  )
                else if (searchPhoneCtrl.text.isNotEmpty)
                  Text(_isArabic ? 'لم يتم العثور على طلبات مرتبطة بهذا الرقم.' : 'No orders found with this phone number.', style: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_isArabic ? 'إغلاق' : 'CLOSE', style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  void _showPolicyModal(String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black)),
                  IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB)),
              const SizedBox(height: 24),
              Text(
                content,
                style: GoogleFonts.montserrat(fontSize: 14, height: 1.8, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 40),
              Align(
                alignment: _isArabic ? Alignment.centerLeft : Alignment.centerRight,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_isArabic ? 'إغلاق' : 'CLOSE', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumSkeletonLoading(bool isDark) {
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[200]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.white;
    final bgColor = isDark ? const Color(0xFF141414) : Colors.white;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedCategory == 'HOME') ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 500,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 80),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Container(width: 250, height: 32, color: bgColor),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                childAspectRatio: 0.72,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(2)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(color: baseColor),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: double.infinity, height: 14, color: baseColor),
                            const SizedBox(height: 8),
                            Container(width: 80, height: 14, color: baseColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            _buildTopBanner(isDark),
            _buildSlimHeader(isDark),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1300),
                        child: _isLoading
                            ? _buildPremiumSkeletonLoading(isDark)
                            : Column(
                                children: [
                                  if (_selectedCategory == 'HOME') ...[
                                    _buildHeroSection(isDark),
                                    const SizedBox(height: 60),
                                    _buildFeaturesBar(isDark),
                                    const SizedBox(height: 80),
                                    _buildHomePreviewSection(title: _isArabic ? 'وصل حديثاً' : 'NEW ARRIVALS', isNew: true, isDark: isDark),
                                    const SizedBox(height: 80),
                                    _buildHomePreviewSection(title: _isArabic ? 'الأكثر مبيعاً' : 'BEST SELLERS', isNew: false, isDark: isDark),
                                    const SizedBox(height: 100),
                                  ] else ...[
                                    const SizedBox(height: 48),
                                    _buildFullShopCatalog(isDark),
                                    const SizedBox(height: 120),
                                  ],
                                ],
                              ),
                      ),
                    ),
                    _buildFooter(context, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBanner(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[900] : Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 8),
      width: double.infinity,
      child: Center(
        child: Text(
          _isArabic ? 'شحن مجاني للطلبات فوق 100\$ | إرجاع مجاني خلال 14 يوماً' : 'FREE SHIPPING OVER \$100 | FREE 14-DAY RETURNS',
          style: GoogleFonts.montserrat(color: Colors.white, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSlimHeader(bool isDark) {
    final links = [
      {'en': 'HOME', 'ar': 'الرئيسية', 'key': 'HOME'},
      {'en': 'SHOP', 'ar': 'المتجر', 'key': 'SHOP'},
      {'en': 'NEW ARRIVALS', 'ar': 'وصل حديثاً', 'key': 'NEW ARRIVALS'},
      {'en': 'BEST SELLERS', 'ar': 'الأكثر طلباً', 'key': 'BEST SELLERS'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => _changeCategory('HOME'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('EL DOC', style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4, height: 1, color: isDark ? Colors.white : Colors.black)),
                Text('PREMIUM SNEAKERS', style: GoogleFonts.montserrat(fontSize: 8, letterSpacing: 3, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.black54)),
              ],
            ),
          ),
          Row(
            children: links.map((link) {
              final isSelected = _selectedCategory == link['key'];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InkWell(
                  onTap: () => _changeCategory(link['key']!),
                  child: Text(
                    _isArabic ? link['ar']! : link['en']!,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      letterSpacing: 1.2,
                      color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 18, color: isDark ? Colors.white : Colors.black87),
                onPressed: () {
                  themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                },
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 160,
                height: 36,
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchFilter = val;
                      _applyFilters();
                    });
                  },
                  style: GoogleFonts.montserrat(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: _isArabic ? 'بحث...' : 'Search...',
                    hintStyle: GoogleFonts.montserrat(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w500),
                    prefixIcon: Icon(Icons.search, size: 16, color: isDark ? Colors.white : Colors.black87),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => setState(() => _isArabic = !_isArabic),
                child: Text(_isArabic ? 'EN' : 'عربي', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
              ),
              const SizedBox(width: 16),
              IconButton(icon: Icon(Icons.person_outline, size: 22, color: isDark ? Colors.white : Colors.black), onPressed: _showCustomerAccountModal, constraints: const BoxConstraints()),
              const SizedBox(width: 12),
              
              // أيقونة المفضلة الجديدة في الهيدر
              InkWell(
                onTap: _openWishlistDrawer,
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.favorite_border, size: 22, color: isDark ? Colors.white : Colors.black)),
                    if (_wishlist.totalCount > 0)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: Text('${_wishlist.totalCount}', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // أيقونة السلة
              InkWell(
                onTap: _openCartDrawer,
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.shopping_bag_outlined, size: 22, color: isDark ? Colors.white : Colors.black)),
                    if (_cart.totalCount > 0)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: isDark ? Colors.white : Colors.black, shape: BoxShape.circle),
                        child: Text('${_cart.totalCount}', style: GoogleFonts.montserrat(color: isDark ? Colors.black : Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(bool isDark) {
    final slide = _heroSlides[_currentHeroIndex];
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF111111) : const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(_isArabic ? slide['title_ar']! : slide['title']!, key: ValueKey<String>('${_currentHeroIndex}_title'), style: GoogleFonts.montserrat(fontSize: 56, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -2, color: isDark ? Colors.white : Colors.black87)),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(_isArabic ? slide['desc_ar']! : slide['desc']!, key: ValueKey<String>('${_currentHeroIndex}_desc'), style: GoogleFonts.montserrat(fontSize: 15, color: isDark ? Colors.white70 : Colors.black54, height: 1.6, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.white : Colors.black, foregroundColor: isDark ? Colors.black : Colors.white, elevation: 5, padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                      onPressed: () => _changeCategory('SHOP'),
                      child: Text(_isArabic ? 'تسوق الآن' : 'SHOP NOW', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.white : Colors.black, side: BorderSide(color: isDark ? Colors.white : Colors.black87, width: 1.5), padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                      onPressed: () => _changeCategory('NEW ARRIVALS'),
                      child: Text(_isArabic ? 'استكشف' : 'EXPLORE', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: Container(
                      key: ValueKey<String>(slide['image']!),
                      height: 500,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        image: DecorationImage(image: NetworkImage(slide['image']!), fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_heroSlides.length, (idx) {
                    final isCurrent = _currentHeroIndex == idx;
                    return InkWell(
                      onTap: () => setState(() => _currentHeroIndex = idx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('0${idx + 1}', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600, color: isCurrent ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white30 : Colors.black26))),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildFeatureItem(Icons.local_shipping_outlined, _isArabic ? 'شحن مجاني' : 'FREE SHIPPING', _isArabic ? 'للطلبات فوق 100\$' : 'On orders over \$100', isDark),
          _buildFeatureItem(Icons.refresh_outlined, _isArabic ? 'إرجاع واستبدال' : 'EASY RETURNS', _isArabic ? 'خلال 14 يوماً' : '14 days return policy', isDark),
          _buildFeatureItem(Icons.verified_user_outlined, _isArabic ? 'دفع آمن' : 'SECURE PAYMENT', _isArabic ? 'دفع آمن 100%' : '100% secure checkout', isDark),
          _buildFeatureItem(Icons.headset_mic_outlined, _isArabic ? 'دعم مستمر' : '24/7 SUPPORT', _isArabic ? 'فريقنا في خدمتك' : "We're here to help", isDark),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 28, color: isDark ? Colors.white : Colors.black87),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildHomePreviewSection({required String title, required bool isNew, required bool isDark}) {
    List<Map<String, dynamic>> previewList = isNew 
        ? _filteredProducts.where((p) => p['is_new_arrival'] == true).take(4).toList()
        : _filteredProducts.where((p) => p['is_best_seller'] == true).take(4).toList();

    if (previewList.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black)),
              TextButton(
                onPressed: () => _changeCategory(isNew ? 'NEW ARRIVALS' : 'BEST SELLERS'),
                child: Row(
                  children: [
                    Text(_isArabic ? 'عرض الكل' : 'VIEW ALL', style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 8),
                    Icon(_isArabic ? Icons.arrow_back : Icons.arrow_forward, size: 16, color: isDark ? Colors.white : Colors.black),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 24, crossAxisSpacing: 24, childAspectRatio: 0.72),
            itemCount: previewList.length,
            itemBuilder: (context, index) {
              return PremiumProductCard(
                item: previewList[index],
                isNewBadge: isNew,
                isArabic: _isArabic,
                onTap: () => _showProductDetailsModal(previewList[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFullShopCatalog(bool isDark) {
    int totalProducts = _filteredProducts.length;
    int totalPages = totalProducts == 0 ? 1 : (totalProducts / _itemsPerPage).ceil();
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = (startIndex + _itemsPerPage > totalProducts) ? totalProducts : startIndex + _itemsPerPage;
    
    List<Map<String, dynamic>> pageItems = startIndex < totalProducts ? _filteredProducts.sublist(startIndex, endIndex) : [];
    String pageTitle = _selectedCategory == 'SHOP' ? (_isArabic ? 'كل المنتجات' : 'ALL COLLECTION') : (_selectedCategory == 'NEW ARRIVALS' ? (_isArabic ? 'وصل حديثاً' : 'NEW ARRIVALS') : (_isArabic ? 'الأكثر طلباً' : 'BEST SELLERS'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(pageTitle, style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black)),
              Text(_isArabic ? 'عرض $totalProducts منتج' : 'SHOWING $totalProducts RESULTS', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black45)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
          const SizedBox(height: 32),
          
          if (pageItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(80),
                child: Text(_isArabic ? 'لم يتم العثور على منتجات.' : 'No products found.', style: GoogleFonts.montserrat(fontSize: 16, color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w600)),
              ),
            )
          else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 24, crossAxisSpacing: 24, childAspectRatio: 0.72),
              itemCount: pageItems.length,
              itemBuilder: (context, index) {
                return PremiumProductCard(
                  item: pageItems[index],
                  isNewBadge: _selectedCategory == 'NEW ARRIVALS' || pageItems[index]['is_new_arrival'] == true,
                  isArabic: _isArabic,
                  onTap: () => _showProductDetailsModal(pageItems[index]),
                );
              },
            ),
            
            if (totalPages > 1) ...[
              const SizedBox(height: 60),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(_isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios, size: 14),
                    color: _currentPage > 1 ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white24 : Colors.black26),
                    onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  ),
                  const SizedBox(width: 16),
                  ...List.generate(totalPages, (index) {
                    int pageNum = index + 1;
                    bool isCurrent = _currentPage == pageNum;
                    return GestureDetector(
                      onTap: () => setState(() => _currentPage = pageNum),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                          border: Border.all(color: isCurrent ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB))),
                        ),
                        child: Text(
                          pageNum.toString(),
                          style: GoogleFonts.montserrat(color: isCurrent ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(_isArabic ? Icons.arrow_back_ios : Icons.arrow_forward_ios, size: 14),
                    color: _currentPage < totalPages ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white24 : Colors.black26),
                    onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                  ),
                ],
              ),
            ]
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF111111) : const Color(0xFFF9FAFB),
      width: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 60),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EL DOC', style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2, color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(height: 6),
                        Text('PREMIUM SNEAKERS', style: GoogleFonts.montserrat(fontSize: 9, letterSpacing: 2, color: isDark ? Colors.white54 : Colors.black45, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    
                    _buildFooterCol(
                      _isArabic ? 'المتجر' : 'SHOP',
                      [
                        {
                          'label': _isArabic ? 'جميع المنتجات' : 'All Products',
                          'onTap': () => _changeCategory('SHOP'),
                        },
                        {
                          'label': _isArabic ? 'رجالي' : 'Men',
                          'onTap': () {
                            setState(() {
                              _selectedCategory = 'SHOP';
                              _genderFilter = 'Men';
                              _searchFilter = '';
                              _currentPage = 1;
                              _applyFilters();
                            });
                          },
                        },
                        {
                          'label': _isArabic ? 'نسائي' : 'Women',
                          'onTap': () {
                            setState(() {
                              _selectedCategory = 'SHOP';
                              _genderFilter = 'Women';
                              _searchFilter = '';
                              _currentPage = 1;
                              _applyFilters();
                            });
                          },
                        },
                        {
                          'label': _isArabic ? 'وصل حديثاً' : 'New Arrivals',
                          'onTap': () => _changeCategory('NEW ARRIVALS'),
                        },
                      ],
                      isDark
                    ),

                    _buildFooterCol(
                      _isArabic ? 'خدمة العملاء' : 'CUSTOMER CARE',
                      [
                        {
                          'label': _isArabic ? 'الشحن والتوصيل' : 'Shipping',
                          'onTap': () => _showPolicyModal(
                            _isArabic ? 'سياسة الشحن والتوصيل' : 'SHIPPING POLICY',
                            _isArabic 
                              ? 'نقدم شحن قياسي مجاني لجميع الطلبات التي تتجاوز قيمتها 100 دولار. تستغرق عمليات التوصيل عادةً من 3 إلى 5 أيام عمل داخل المدن الرئيسية لضمان وصول حذائك الفاخر بأمان وسرعة.' 
                              : 'Enjoy complimentary standard shipping on all orders exceeding \$100. Deliveries are typically completed within 3-5 business days within major cities, ensuring your premium sneakers arrive safely and swiftly.'
                          ),
                        },
                        {
                          'label': _isArabic ? 'الإرجاع' : 'Returns',
                          'onTap': () => _showPolicyModal(
                            _isArabic ? 'سياسة الإرجاع' : 'RETURN POLICY',
                            _isArabic 
                              ? 'يسعدنا قبول المرتجعات للأحذية غير المستخدمة وبحالتها الأصلية خلال 14 يوماً من تاريخ الاستلام. نوفر عملية إرجاع سلسة وخالية من المتاعب لعملائنا المميزين.' 
                              : 'We gladly accept returns of unworn merchandise in its original condition within 14 days of delivery. We provide a seamless and hassle-free return process for our premium clientele.'
                          ),
                        },
                        {
                          'label': _isArabic ? 'طرق الدفع' : 'Payment Methods',
                          'onTap': () => _showPolicyModal(
                            _isArabic ? 'طرق الدفع' : 'PAYMENT METHODS',
                            _isArabic 
                              ? 'لضمان راحتكم وثقتكم، نقبل حالياً الدفع نقداً عند الاستلام (COD) فقط. يتم معاينة المنتج قبل الدفع لضمان أعلى معايير الجودة.' 
                              : 'To ensure your absolute comfort and trust, we currently accept Cash on Delivery (COD) exclusively. You may inspect your premium product before payment.'
                          ),
                        },
                      ],
                      isDark
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                Divider(color: isDark ? const Color(0xFF262626) : Colors.black12),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('© 2026 EL DOC. ALL RIGHTS RESERVED.', style: GoogleFonts.montserrat(fontSize: 11, color: isDark ? Colors.white54 : Colors.black38, fontWeight: FontWeight.w600)),
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboard())),
                      child: Text('Portal Login', style: GoogleFonts.montserrat(fontSize: 10, color: isDark ? Colors.white38 : Colors.black26, decoration: TextDecoration.underline, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterCol(String title, List<Map<String, dynamic>> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 20),
        ...items.map((item) => _FooterLink(
              text: item['label'],
              onTap: item['onTap'],
              isDark: isDark,
            )),
      ],
    );
  }
}

class PremiumProductCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isNewBadge;
  final bool isArabic;
  final VoidCallback onTap;

  const PremiumProductCard({
    super.key,
    required this.item,
    required this.isNewBadge,
    required this.isArabic,
    required this.onTap,
  });

  @override
  State<PremiumProductCard> createState() => _PremiumProductCardState();
}

class _PremiumProductCardState extends State<PremiumProductCard> {
  bool _isHovered = false;
  final WishlistManager _wishlist = WishlistManager.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final variants = widget.item['product_variants'] as List<dynamic>?;
    final firstVariant = (variants != null && variants.isNotEmpty) ? variants[0] : null;

    String? imgUrl;
    if (firstVariant != null) {
      final dynamic urls = firstVariant['image_urls'];
      if (urls != null && urls is List && urls.isNotEmpty && urls[0].toString().startsWith('http')) {
        imgUrl = urls[0].toString();
      } else if (firstVariant['image_url'] != null && firstVariant['image_url'].toString().startsWith('http')) {
        imgUrl = firstVariant['image_url'].toString();
      }
    }
    imgUrl ??= 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600&q=80';

    final isFav = _wishlist.isFavorite(widget.item['id'] ?? '');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _isHovered ? -8 : 0, 0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
            borderRadius: BorderRadius.circular(2),
            boxShadow: _isHovered
                ? [BoxShadow(color: isDark ? Colors.white12 : Colors.black12, blurRadius: 20, offset: const Offset(0, 10))]
                : [const BoxShadow(color: Colors.transparent)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB),
                      ),
                      child: ClipRRect(
                        child: AnimatedScale(
                          scale: _isHovered ? 1.05 : 1.0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          child: Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.broken_image, color: isDark ? Colors.white24 : Colors.black26, size: 40),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.isNewBadge)
                      Positioned(
                        top: 10,
                        left: widget.isArabic ? null : 10,
                        right: widget.isArabic ? 10 : null,
                        child: Container(
                          color: isDark ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Text(
                            widget.isArabic ? 'جديد' : 'NEW',
                            style: GoogleFonts.montserrat(color: isDark ? Colors.black : Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    
                    // زرار الإضافة للمفضلة على الكارت
                    Positioned(
                      top: 6,
                      right: widget.isArabic ? null : 6,
                      left: widget.isArabic ? 6 : null,
                      child: IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: isFav ? Colors.redAccent : (isDark ? Colors.white60 : Colors.black45),
                        ),
                        onPressed: () {
                          _wishlist.toggleFavorite(widget.item);
                          setState(() {});
                        },
                      ),
                    ),

                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _isHovered ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            color: isDark ? Colors.black.withOpacity(0.95) : Colors.white.withOpacity(0.95),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              widget.isArabic ? 'عرض التفاصيل' : 'QUICK VIEW',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item['name'] ?? '',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : Colors.black),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$${widget.item['base_price']}',
                      style: GoogleFonts.montserrat(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool isDark;

  const _FooterLink({required this.text, required this.onTap, required this.isDark});

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: _isHovered ? (widget.isDark ? Colors.white : Colors.black) : (widget.isDark ? Colors.white54 : Colors.black54),
              fontWeight: _isHovered ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(widget.text),
          ),
        ),
      ),
    );
  }
}