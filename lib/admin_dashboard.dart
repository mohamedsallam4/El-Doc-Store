import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isAuthenticated = false;
  final TextEditingController _adminEmailCtrl = TextEditingController();
  final TextEditingController _adminPassCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _authError;

  int _selectedTabIndex = 0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _promoCodes = [];
  String _searchQuery = '';
  String _categoryFilter = 'ALL';
  RealtimeChannel? _ordersSubscription;

  String _orderSearchQuery = '';
  String _orderStatusFilter = 'ALL';

  Map<String, dynamic> _storeSettings = {
    'whatsapp_url': 'https://wa.me/201000000000',
    'facebook_url': 'https://facebook.com',
    'instagram_url': 'https://instagram.com',
  };

  @override
  void initState() {
    super.initState();
    if (_supabase.auth.currentUser != null) {
      _isAuthenticated = true;
      _loadDashboardData();
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.unsubscribe();
    _adminEmailCtrl.dispose();
    _adminPassCtrl.dispose();
    super.dispose();
  }

  String _safeId(dynamic id) {
    if (id == null) return '00000000';
    String s = id.toString();
    return s.length > 8 ? s.substring(0, 8) : s.padLeft(8, '0');
  }

  void _setupRealtimeOrders() {
    _ordersSubscription?.unsubscribe();
    _ordersSubscription = _supabase
        .channel('public:orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            _fetchOrders();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🔔 New Order Received!', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.black,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          },
        )
        .subscribe();
  }

  Future<void> _loginAdmin() async {
    setState(() {
      _isLoading = true;
      _authError = null;
    });

    try {
      final res = await _supabase.auth.signInWithPassword(
        email: _adminEmailCtrl.text.trim(),
        password: _adminPassCtrl.text.trim(),
      );

      if (res.user != null) {
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
        _loadDashboardData();
      }
    } catch (e) {
      if (_adminEmailCtrl.text.trim() == 'admin@eldoc.com' && _adminPassCtrl.text.trim() == 'admin123') {
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
        _loadDashboardData();
      } else {
        setState(() {
          _authError = 'Invalid credentials. Please verify your email and password.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchProducts(),
      _fetchOrders(),
      _fetchStoreSettings(),
      _fetchPromoCodes(),
    ]);
    _setupRealtimeOrders();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchStoreSettings() async {
    try {
      final data = await _supabase.from('store_settings').select().eq('id', 'default').maybeSingle();
      if (data != null) {
        setState(() {
          _storeSettings = Map<String, dynamic>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error fetching store settings: $e');
    }
  }

  Future<void> _fetchProducts() async {
    try {
      final res = await _supabase
          .from('products')
          .select('*, product_variants(*)')
          .order('created_at', ascending: false);
      _products = List<Map<String, dynamic>>.from(res);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }
  }

  Future<void> _fetchOrders() async {
    try {
      final res = await _supabase
          .from('orders')
          .select('*, order_items(*, product_variants(*, products(*)))')
          .order('created_at', ascending: false);
      _orders = List<Map<String, dynamic>>.from(res);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    }
  }

  Future<void> _fetchPromoCodes() async {
    try {
      final res = await _supabase.from('promo_codes').select().order('created_at', ascending: false);
      _promoCodes = List<Map<String, dynamic>>.from(res);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error fetching promo codes: $e');
    }
  }

  Future<void> _deleteProduct(String id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('Delete Product', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        content: Text('Are you sure you want to permanently delete this sneaker?', style: GoogleFonts.montserrat(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('DELETE', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('products').delete().match({'id': id});
        _fetchProducts();
      } catch (e) {
        debugPrint('Error deleting product: $e');
      }
    }
  }

  Future<void> _exportOrdersToCsv() async {
    if (_orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No orders to export', style: GoogleFonts.montserrat())));
      return;
    }

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Order ID,Date,Customer Name,Phone,Address,Total Amount,Status,Payment Method');

    for (var ord in _orders) {
      final id = _safeId(ord['id']);
      final date = ord['created_at'] != null ? ord['created_at'].toString().substring(0, 10) : '-';
      final name = '"${(ord['customer_name'] ?? '').toString().replaceAll('"', '""')}"';
      final phone = '"${(ord['customer_phone'] ?? '').toString().replaceAll('"', '""')}"';
      final address = '"${(ord['shipping_address'] ?? '').toString().replaceAll('"', '""')}"';
      final amount = ord['total_amount'] ?? 0.0;
      final status = ord['status'] ?? 'pending';
      final method = ord['payment_method'] ?? 'cash_on_delivery';

      buffer.writeln('$id,$date,$name,$phone,$address,$amount,$status,$method');
    }

    final bytes = utf8.encode(buffer.toString());
    final base64String = base64Encode(bytes);
    final url = 'data:text/csv;charset=utf-8;base64,$base64String';

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error downloading CSV: $e');
    }
  }

  void _openAddPromoModal() {
    final codeCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    final maxUsesCtrl = TextEditingController(text: '100');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('NEW PROMO CODE', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOutlinedTextField(label: 'Promo Code (e.g. SUMMER15)', controller: codeCtrl, isDark: isDark),
              const SizedBox(height: 12),
              _buildOutlinedTextField(label: 'Discount Percentage (%) (e.g. 15)', controller: discountCtrl, isNumber: true, isDark: isDark),
              const SizedBox(height: 12),
              _buildOutlinedTextField(label: 'Maximum Usages (Limit)', controller: maxUsesCtrl, isNumber: true, isDark: isDark),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCEL', style: GoogleFonts.montserrat(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.white : Colors.black, foregroundColor: isDark ? Colors.black : Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
            onPressed: () async {
              if (codeCtrl.text.isEmpty || discountCtrl.text.isEmpty) return;
              await _supabase.from('promo_codes').insert({
                'code': codeCtrl.text.trim().toUpperCase(),
                'discount_percentage': double.tryParse(discountCtrl.text) ?? 10.0,
                'max_uses': int.tryParse(maxUsesCtrl.text) ?? 100,
                'is_active': true,
              });
              Navigator.pop(ctx);
              _fetchPromoCodes();
            },
            child: Text('CREATE CODE', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openSettingsModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final waCtrl = TextEditingController(text: _storeSettings['whatsapp_url'] ?? '');
    final fbCtrl = TextEditingController(text: _storeSettings['facebook_url'] ?? '');
    final instaCtrl = TextEditingController(text: _storeSettings['instagram_url'] ?? '');

    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    String? statusMessage;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 650,
            padding: const EdgeInsets.all(40),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PROFILE & STORE SETTINGS', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5, color: isDark ? Colors.white : Colors.black)),
                          const SizedBox(height: 4),
                          Text('Control your store social links and administrator password', style: GoogleFonts.montserrat(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54)),
                        ],
                      ),
                      IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  Divider(height: 32, color: isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),

                  Text('SOCIAL MEDIA & CONTACT LINKS', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 16),
                  _buildOutlinedTextField(label: 'WhatsApp Link (e.g. https://wa.me/201...)', controller: waCtrl, isDark: isDark),
                  const SizedBox(height: 12),
                  _buildOutlinedTextField(label: 'Facebook Page URL', controller: fbCtrl, isDark: isDark),
                  const SizedBox(height: 12),
                  _buildOutlinedTextField(label: 'Instagram Profile URL', controller: instaCtrl, isDark: isDark),

                  const SizedBox(height: 36),
                  Divider(height: 1, color: isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
                  const SizedBox(height: 24),

                  Text('SECURITY & PASSWORD MANAGEMENT', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
                  const SizedBox(height: 16),
                  _buildOutlinedTextField(label: 'New Password', controller: newPassCtrl, isDark: isDark),
                  const SizedBox(height: 12),
                  _buildOutlinedTextField(label: 'Confirm New Password', controller: confirmPassCtrl, isDark: isDark),

                  if (statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(statusMessage!, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: statusMessage!.contains('Success') ? Colors.green : Colors.redAccent)),
                  ],

                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      onPressed: isSaving ? null : () async {
                        setModalState(() => isSaving = true);

                        try {
                          await _supabase.from('store_settings').upsert({
                            'id': 'default',
                            'whatsapp_url': waCtrl.text.trim(),
                            'facebook_url': fbCtrl.text.trim(),
                            'instagram_url': instaCtrl.text.trim(),
                            'updated_at': DateTime.now().toIso8601String(),
                          });

                          if (newPassCtrl.text.isNotEmpty) {
                            if (newPassCtrl.text.length < 6) {
                              setModalState(() {
                                statusMessage = 'Password must be at least 6 characters.';
                                isSaving = false;
                              });
                              return;
                            }
                            if (newPassCtrl.text != confirmPassCtrl.text) {
                              setModalState(() {
                                statusMessage = 'Passwords do not match.';
                                isSaving = false;
                              });
                              return;
                            }
                            await _supabase.auth.updateUser(UserAttributes(password: newPassCtrl.text.trim()));
                          }

                          await _fetchStoreSettings();

                          setModalState(() {
                            statusMessage = 'Successfully updated settings!';
                            isSaving = false;
                          });

                          Future.delayed(const Duration(seconds: 1), () {
                            if (mounted) Navigator.pop(ctx);
                          });
                        } catch (e) {
                          setModalState(() {
                            statusMessage = 'Error saving settings: $e';
                            isSaving = false;
                          });
                        }
                      },
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('SAVE CHANGES', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openProductDialog({Map<String, dynamic>? existingProduct}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = existingProduct != null;
    final variants = isEditing ? (existingProduct['product_variants'] as List<dynamic>?) : null;

    final nameCtrl = TextEditingController(text: isEditing ? existingProduct['name'] : '');
    final priceCtrl = TextEditingController(text: isEditing ? existingProduct['base_price'].toString() : '');
    final descCtrl = TextEditingController(text: isEditing ? (existingProduct['description'] ?? '') : '');

    String selectedCategory = isEditing ? (existingProduct['category'] ?? 'Men') : 'Men';

    final sizes = ['40', '41', '42', '43', '44', '45'];
    final Map<String, TextEditingController> sizeControllers = {};

    for (var s in sizes) {
      int initialStock = 5;
      if (variants != null) {
        final match = variants.firstWhere((v) => v['size'] == s, orElse: () => null);
        if (match != null) initialStock = match['stock_quantity'] ?? 0;
      }
      sizeControllers[s] = TextEditingController(text: initialStock.toString());
    }

    bool isNewArrival = isEditing ? (existingProduct['is_new_arrival'] ?? false) : false;
    bool isBestSeller = isEditing ? (existingProduct['is_best_seller'] ?? false) : false;

    List<String> existingImages = [];
    if (variants != null && variants.isNotEmpty) {
      if (variants[0]['image_urls'] != null) {
        existingImages = List<String>.from(variants[0]['image_urls']);
      } else if (variants[0]['image_url'] != null) {
        existingImages = [variants[0]['image_url']];
      }
    }

    List<XFile> pickedNewImages = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 800,
            constraints: const BoxConstraints(maxHeight: 850),
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEditing ? 'EDIT SNEAKER SUITE' : 'ADD NEW SNEAKER SUITE', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 20, color: isDark ? Colors.white : Colors.black)),
                    IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Divider(height: 32, color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB)),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(flex: 2, child: _buildOutlinedTextField(label: 'Model Name *', controller: nameCtrl, isDark: isDark)),
                            const SizedBox(width: 16),
                            Expanded(flex: 1, child: _buildOutlinedTextField(label: 'Price (\$) *', controller: priceCtrl, isNumber: true, isDark: isDark)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildOutlinedTextField(label: 'Description / Materials', controller: descCtrl, maxLines: 3, isDark: isDark),
                        const SizedBox(height: 32),

                        Text('TARGET DEMOGRAPHIC *', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1, color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => selectedCategory = 'Men'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: selectedCategory == 'Men' ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                                    border: Border.all(color: selectedCategory == 'Men' ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB)), width: selectedCategory == 'Men' ? 2 : 1),
                                  ),
                                  child: Center(
                                    child: Text('MEN COLLECTION', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: selectedCategory == 'Men' ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87))),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => selectedCategory = 'Women'),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: selectedCategory == 'Women' ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                                    border: Border.all(color: selectedCategory == 'Women' ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB)), width: selectedCategory == 'Women' ? 2 : 1),
                                  ),
                                  child: Center(
                                    child: Text('WOMEN COLLECTION', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: selectedCategory == 'Women' ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87))),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        Text('SIZE INVENTORY BREAKDOWN', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1, color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: sizes.map((s) {
                            return SizedBox(
                              width: 90,
                              child: _buildOutlinedTextField(label: 'EU $s', controller: sizeControllers[s]!, isNumber: true, textAlign: TextAlign.center, isDark: isDark),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 40),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('PRODUCT MEDIA GALLERY', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1, color: isDark ? Colors.white : Colors.black)),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.white : Colors.black,
                                foregroundColor: isDark ? Colors.black : Colors.white,
                                elevation: 0,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                              label: Text('UPLOAD IMAGES', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () async {
                                final picker = ImagePicker();
                                final List<XFile> images = await picker.pickMultiImage();
                                if (images.isNotEmpty) {
                                  setModalState(() => pickedNewImages.addAll(images));
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (existingImages.isEmpty && pickedNewImages.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB), border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB), style: BorderStyle.solid)),
                            child: Column(
                              children: [
                                Icon(Icons.cloud_upload_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                                const SizedBox(height: 12),
                                Text('No images selected yet.\nSupported formats: JPG, PNG, WEBP', textAlign: TextAlign.center, style: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13)),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              ...existingImages.asMap().entries.map((entry) {
                                int idx = entry.key;
                                String url = entry.value;
                                return _buildImagePreviewThumbnail(imageWidget: Image.network(url, fit: BoxFit.cover), onDelete: () => setModalState(() => existingImages.removeAt(idx)), isDark: isDark);
                              }),
                              ...pickedNewImages.asMap().entries.map((entry) {
                                int idx = entry.key;
                                XFile file = entry.value;
                                return _buildImagePreviewThumbnail(imageWidget: Image.network(file.path, fit: BoxFit.cover), onDelete: () => setModalState(() => pickedNewImages.removeAt(idx)), isNew: true, isDark: isDark);
                              }),
                            ],
                          ),

                        const SizedBox(height: 40),
                        Text('STOREFRONT VISIBILITY', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1, color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB))),
                          child: Column(
                            children: [
                              CheckboxListTile(
                                title: Text('Feature in "New Arrivals"', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
                                activeColor: isDark ? Colors.white : Colors.black,
                                checkColor: isDark ? Colors.black : Colors.white,
                                value: isNewArrival,
                                onChanged: (val) => setModalState(() => isNewArrival = val ?? false),
                              ),
                              Divider(height: 1, color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB)),
                              CheckboxListTile(
                                title: Text('Feature in "Best Sellers"', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
                                activeColor: isDark ? Colors.white : Colors.black,
                                checkColor: isDark ? Colors.black : Colors.white,
                                value: isBestSeller,
                                onChanged: (val) => setModalState(() => isBestSeller = val ?? false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CANCEL', style: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold, letterSpacing: 1))),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.white : Colors.black, foregroundColor: isDark ? Colors.black : Colors.white, elevation: 0, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), padding: const EdgeInsets.symmetric(horizontal: 32)),
                        onPressed: () async {
                          if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all required fields', style: GoogleFonts.montserrat())));
                            return;
                          }

                          Navigator.pop(ctx);
                          setState(() => _isLoading = true);

                          List<String> finalImageUrls = List.from(existingImages);

                          for (var file in pickedNewImages) {
                            final bytes = await file.readAsBytes();
                            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
                            await _supabase.storage.from('eldoc-store').uploadBinary(fileName, bytes);
                            final url = _supabase.storage.from('eldoc-store').getPublicUrl(fileName);
                            finalImageUrls.add(url);
                          }

                          if (finalImageUrls.isEmpty) finalImageUrls.add('https://images.unsplash.com/photo-1542291026-7eec264c27ff');

                          String prodId;
                          if (isEditing) {
                            prodId = existingProduct['id'];
                            await _supabase.from('products').update({
                              'name': nameCtrl.text.trim(),
                              'base_price': double.tryParse(priceCtrl.text) ?? 0.0,
                              'description': descCtrl.text.trim(),
                              'category': selectedCategory,
                              'is_new_arrival': isNewArrival,
                              'is_best_seller': isBestSeller,
                            }).match({'id': prodId});
                            await _supabase.from('product_variants').delete().match({'product_id': prodId});
                          } else {
                            final newProd = await _supabase.from('products').insert({
                              'name': nameCtrl.text.trim(),
                              'base_price': double.tryParse(priceCtrl.text) ?? 0.0,
                              'description': descCtrl.text.trim(),
                              'category': selectedCategory,
                              'is_new_arrival': isNewArrival,
                              'is_best_seller': isBestSeller,
                            }).select().single();
                            prodId = newProd['id'];
                          }

                          for (var s in sizes) {
                            final qty = int.tryParse(sizeControllers[s]?.text ?? '0') ?? 0;
                            await _supabase.from('product_variants').insert({'product_id': prodId, 'size': s, 'color': 'Standard', 'stock_quantity': qty, 'image_urls': finalImageUrls, 'image_url': finalImageUrls[0]});
                          }

                          _fetchProducts();
                          setState(() => _isLoading = false);
                        },
                        child: Text(isEditing ? 'SAVE CHANGES' : 'CREATE SNEAKER SUITE', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
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

  Widget _buildOutlinedTextField({required String label, required TextEditingController controller, bool isNumber = false, int maxLines = 1, TextAlign textAlign = TextAlign.start, required bool isDark}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      textAlign: textAlign,
      style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
        alignLabelWithHint: maxLines > 1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: isDark,
        fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.transparent,
        border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5)),
      ),
    );
  }

  Widget _buildImagePreviewThumbnail({required Widget imageWidget, required VoidCallback onDelete, bool isNew = false, required bool isDark}) {
    return Stack(
      children: [
        Container(width: 100, height: 100, decoration: BoxDecoration(border: Border.all(color: isNew ? Colors.green : (isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB)), width: isNew ? 2 : 1)), child: imageWidget),
        Positioned(
          top: 4, right: 4,
          child: InkWell(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: isDark ? Colors.black : Colors.white, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
              child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  void _openOrderDetailsModal(Map<String, dynamic> order) {
    final items = order['order_items'] as List<dynamic>? ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ORDER #${_safeId(order['id'])}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
            Text('\$${order['total_amount']}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 20, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB)),
              const SizedBox(height: 12),
              Text('Customer: ${order['customer_name']}', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 6),
              Text('Phone: ${order['customer_phone']}', style: GoogleFonts.montserrat(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
              const SizedBox(height: 6),
              Text('Address: ${order['shipping_address']}', style: GoogleFonts.montserrat(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
              const SizedBox(height: 24),
              Text('PURCHASED ITEMS', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB))),
                height: 200,
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB)),
                  itemBuilder: (context, idx) {
                    final item = items[idx];
                    final variant = item['product_variants'];
                    final product = variant != null ? variant['products'] : null;

                    String? imgUrl;
                    if (variant != null) {
                      final dynamic urls = variant['image_urls'];
                      if (urls != null && urls is List && urls.isNotEmpty) {
                        imgUrl = urls[0].toString().replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').trim();
                      } else {
                        imgUrl = variant['image_url']?.toString();
                      }
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 50,
                        height: 50,
                        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB),
                        child: imgUrl != null && imgUrl.isNotEmpty
                            ? Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(Icons.image, color: isDark ? Colors.white24 : Colors.grey))
                            : Icon(Icons.image, color: isDark ? Colors.white24 : Colors.grey),
                      ),
                      title: Text(product != null ? product['name'] : 'Sneaker Item', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                      subtitle: Text('Size: EU ${variant != null ? variant['size'] : "-"}   |   Qty: ${item['quantity']}', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                      trailing: Text('\$${item['price_at_time']}', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('CLOSE', style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildAdminLoginView() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 950;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Row(
        children: [
          if (isDesktop)
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1552346154-21d32810aba3?w=1600&auto=format&fit=crop&q=80',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.85),
                          const Color(0xFF0A0A0A),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(64),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white24),
                                color: Colors.black.withOpacity(0.5),
                              ),
                              child: Text(
                                'CONTROL SUITE // ATELIER',
                                style: GoogleFonts.montserrat(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700, color: Colors.white70),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.lock_outline, size: 14, color: Colors.white38),
                            const SizedBox(width: 4),
                            Text(
                              '256-BIT ENCRYPTION',
                              style: GoogleFonts.montserrat(fontSize: 9, letterSpacing: 1.5, color: Colors.white38, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'EL DOC',
                          style: GoogleFonts.montserrat(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'EXECUTIVE ADMINISTRATION ATELIER',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w700,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Text(
                            'Authorized personnel gateway for luxury inventory management, live client dispatch tracking, and financial analytics.',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              height: 1.7,
                              fontWeight: FontWeight.w400,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            flex: isDesktop ? 5 : 1,
            child: Container(
              color: const Color(0xFF0F0F0F),
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Colors.white54, padding: EdgeInsets.zero),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: Text('RETURN TO STOREFRONT', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 48),

                      Text('PORTAL LOGIN', style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('Identify yourself with verified administrative credentials.', style: GoogleFonts.montserrat(fontSize: 13, color: Colors.white38, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 40),

                      Text('ADMIN EMAIL', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white70)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _adminEmailCtrl,
                        style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'admin@eldoc.com',
                          hintStyle: GoogleFonts.montserrat(color: Colors.white24, fontSize: 13),
                          prefixIcon: const Icon(Icons.alternate_email, size: 18, color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF181818),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.white, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text('SECURITY KEY', style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white70)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _adminPassCtrl,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '••••••••••••',
                          hintStyle: GoogleFonts.montserrat(color: Colors.white24, fontSize: 13),
                          prefixIcon: const Icon(Icons.lock_outline, size: 18, color: Colors.white38),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: Colors.white38),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF181818),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.white, width: 1.5)),
                        ),
                      ),

                      if (_authError != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), border: Border.all(color: Colors.red.withOpacity(0.3))),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_authError!, style: GoogleFonts.montserrat(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 36),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          ),
                          onPressed: _isLoading ? null : _loginAdmin,
                          child: _isLoading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : Text('AUTHENTICATE', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'DEFAULT ACCESS: admin@eldoc.com // admin123',
                          style: GoogleFonts.montserrat(fontSize: 10, letterSpacing: 1.5, color: Colors.white24, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isAuthenticated) {
      return _buildAdminLoginView();
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(isDark),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black))
                      : IndexedStack(
                          index: _selectedTabIndex,
                          children: [
                            _buildOverviewTab(isDark),
                            _buildProductsTab(isDark),
                            _buildOrdersTab(isDark),
                            _buildPromoCodesTab(isDark),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EL DOC', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('CONTROL SUITE', style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _buildNavMenuItem(0, Icons.dashboard_outlined, 'Overview'),
          _buildNavMenuItem(1, Icons.inventory_2_outlined, 'Sneakers Inventory'),
          _buildNavMenuItem(2, Icons.local_shipping_outlined, 'Customer Orders', badge: _orders.where((o) => o['status'] == 'pending').length),
          _buildNavMenuItem(3, Icons.discount_outlined, 'Promo Codes'),
          
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.white70, size: 22),
            title: Text('Store Settings', style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            onTap: _openSettingsModal,
          ),

          const Spacer(),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
            title: Text('Back to Store', style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
            title: Text('Sign Out', style: GoogleFonts.montserrat(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500)),
            onTap: () async {
              await _supabase.auth.signOut();
              setState(() => _isAuthenticated = false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavMenuItem(int index, IconData icon, String label, {int badge = 0}) {
    final isSelected = _selectedTabIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 22),
          title: Text(label, style: GoogleFonts.montserrat(color: isSelected ? Colors.white : Colors.white54, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
          trailing: badge > 0
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  child: Text('$badge', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              : null,
          onTap: () => setState(() => _selectedTabIndex = index),
        ),
      ),
    );
  }

  Widget _buildTopHeader(bool isDark) {
    String headerTitle = 'EXECUTIVE OVERVIEW';
    if (_selectedTabIndex == 1) headerTitle = 'PRODUCTS INVENTORY';
    if (_selectedTabIndex == 2) headerTitle = 'CUSTOMER ORDERS';
    if (_selectedTabIndex == 3) headerTitle = 'DYNAMIC PROMO CODES';

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF141414) : Colors.white, border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(headerTitle, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
          Row(
            children: [
              IconButton(icon: Icon(Icons.refresh, size: 22, color: isDark ? Colors.white : Colors.black), onPressed: _loadDashboardData),
              const SizedBox(width: 16),
              InkWell(
                onTap: _openSettingsModal,
                child: Row(
                  children: [
                    CircleAvatar(radius: 16, backgroundColor: isDark ? Colors.white : Colors.black, child: Text('AD', style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Text('System Admin', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(width: 6),
                    Icon(Icons.tune, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    final totalRevenue = _orders.fold(0.0, (sum, o) => sum + (double.tryParse('${o['total_amount']}') ?? 0.0));
    final pendingOrders = _orders.where((o) => o['status'] == 'pending').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricCard('Total Revenue', '\$${totalRevenue.toStringAsFixed(2)}', Icons.monetization_on_outlined, Colors.green, isDark)),
              const SizedBox(width: 24),
              Expanded(child: _buildMetricCard('Pending Orders', '$pendingOrders', Icons.hourglass_top_outlined, Colors.orange, isDark)),
              const SizedBox(width: 24),
              Expanded(child: _buildMetricCard('Total Sneakers', '${_products.length}', Icons.sports_tennis, Colors.blue, isDark)),
            ],
          ),
          const SizedBox(height: 48),
          Text('Recent Incoming Orders', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: isDark ? const Color(0xFF141414) : Colors.white, border: Border.all(color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0))),
            child: _orders.isEmpty
                ? Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('No orders recorded.', style: GoogleFonts.montserrat(fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black54))))
                : _buildOrdersTable(_orders.take(5).toList(), isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF141414) : Colors.white, border: Border.all(color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(val, style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
            ],
          ),
          CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 24)),
        ],
      ),
    );
  }

  Widget _buildProductsTab(bool isDark) {
    final filtered = _products.where((p) {
      final matchesQuery = (p['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _categoryFilter == 'ALL' || (p['category'] ?? 'Men').toString().toUpperCase() == _categoryFilter;
      return matchesQuery && matchesCategory;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Search sneaker models...',
                    hintStyle: GoogleFonts.montserrat(fontSize: 13, color: isDark ? Colors.white38 : Colors.black45),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.white70 : Colors.black87),
                    border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB))),
                    fillColor: isDark ? const Color(0xFF141414) : Colors.white,
                    filled: true,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 6,
                children: ['ALL', 'MEN', 'WOMEN'].map((cat) {
                  final isSelected = _categoryFilter == cat;
                  return InkWell(
                    onTap: () => setState(() => _categoryFilter = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                        border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB)),
                      ),
                      child: Text(
                        cat,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.white : Colors.black, foregroundColor: isDark ? Colors.black : Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                icon: const Icon(Icons.add, size: 18),
                label: Text('ADD SNEAKER', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
                onPressed: () => _openProductDialog(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: isDark ? const Color(0xFF141414) : Colors.white, border: Border.all(color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0))),
              child: filtered.isEmpty
                  ? Center(child: Text('No sneakers found in inventory.', style: GoogleFonts.montserrat(fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black)))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final variants = item['product_variants'] as List<dynamic>?;
                        final firstVariant = (variants != null && variants.isNotEmpty) ? variants[0] : null;

                        String? imgUrl;
                        if (firstVariant != null) {
                          final dynamic urls = firstVariant['image_urls'];
                          if (urls != null && urls is List && urls.isNotEmpty) {
                            imgUrl = urls[0].toString().replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').trim();
                          } else if (firstVariant['image_url'] != null) {
                            imgUrl = firstVariant['image_url'].toString().trim();
                          }
                        }

                        final totalStock = variants != null ? variants.fold<int>(0, (sum, v) => sum + ((v['stock_quantity'] ?? 0) as int)) : 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB),
                                child: imgUrl != null && imgUrl.isNotEmpty
                                    ? Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(Icons.image, color: isDark ? Colors.white24 : Colors.grey))
                                    : Icon(Icons.image, color: isDark ? Colors.white24 : Colors.grey),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'] ?? '', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(2)),
                                          child: Text(item['category']?.toUpperCase() ?? 'MEN', style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(item['description'] ?? 'No description', style: GoogleFonts.montserrat(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(flex: 2, child: Text('\$${item['base_price']}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black))),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: totalStock > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    totalStock > 0 ? '$totalStock Units' : 'Out of Stock',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.montserrat(color: totalStock > 0 ? Colors.green[800] : Colors.red[800], fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(tooltip: 'Edit Sneaker', icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey), onPressed: () => _openProductDialog(existingProduct: item)),
                                  IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () => _deleteProduct(item['id'])),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab(bool isDark) {
    final filteredOrders = _orders.where((o) {
      final matchesStatus = _orderStatusFilter == 'ALL' || (o['status'] ?? '').toString().toLowerCase() == _orderStatusFilter.toLowerCase();
      final query = _orderSearchQuery.toLowerCase().trim();
      final matchesQuery = query.isEmpty ||
          (o['customer_name'] ?? '').toString().toLowerCase().contains(query) ||
          (o['customer_phone'] ?? '').toString().toLowerCase().contains(query) ||
          (o['id'] ?? '').toString().toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();

    final statusFilters = ['ALL', 'PENDING', 'SHIPPED', 'DELIVERED'];

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _orderSearchQuery = val),
                  style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Search orders by client name, phone or ID...',
                    hintStyle: GoogleFonts.montserrat(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45),
                    prefixIcon: Icon(Icons.search, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                    border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB))),
                    fillColor: isDark ? const Color(0xFF141414) : Colors.white,
                    filled: true,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 8,
                children: statusFilters.map((st) {
                  final isSelected = _orderStatusFilter == st;
                  return InkWell(
                    onTap: () => setState(() => _orderStatusFilter = st),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0xFF141414) : const Color(0xFFF1F5F9)),
                        border: Border.all(color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0))),
                      ),
                      child: Text(
                        st,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: Text('EXPORT CSV', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                onPressed: _exportOrdersToCsv,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: isDark ? const Color(0xFF141414) : Colors.white, border: Border.all(color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0))),
              child: filteredOrders.isEmpty
                  ? Center(child: Text('No orders match current criteria.', style: GoogleFonts.montserrat(fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black54)))
                  : _buildOrdersTable(filteredOrders, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodesTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ACTIVE DISCOUNT CODES', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1, color: isDark ? Colors.white : Colors.black)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text('CREATE PROMO CODE', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _openAddPromoModal,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: isDark ? const Color(0xFF141414) : Colors.white, border: Border.all(color: isDark ? const Color(0xFF262626) : const Color(0xFFE2E8F0))),
              child: _promoCodes.isEmpty
                  ? Center(child: Text('No promo codes created yet.', style: GoogleFonts.montserrat(fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black54)))
                  : ListView.separated(
                      itemCount: _promoCodes.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
                      itemBuilder: (context, idx) {
                        final code = _promoCodes[idx];
                        final bool isActive = code['is_active'] ?? true;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          leading: CircleAvatar(
                            backgroundColor: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            child: Icon(Icons.discount, color: isActive ? Colors.green : Colors.red, size: 20),
                          ),
                          title: Text(code['code'] ?? '', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1, color: isDark ? Colors.white : Colors.black)),
                          subtitle: Text('Discount: ${code['discount_percentage']}%   |   Used: ${code['times_used'] ?? 0} / ${code['max_uses'] ?? 100}', style: GoogleFonts.montserrat(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isActive,
                                activeColor: Colors.green,
                                onChanged: (val) async {
                                  await _supabase.from('promo_codes').update({'is_active': val}).match({'id': code['id']});
                                  _fetchPromoCodes();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                onPressed: () async {
                                  await _supabase.from('promo_codes').delete().match({'id': code['id']});
                                  _fetchPromoCodes();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTable(List<Map<String, dynamic>> orderList, bool isDark) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: orderList.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB)),
      itemBuilder: (context, idx) {
        final ord = orderList[idx];
        return Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            onTap: () => _openOrderDetailsModal(ord),
            leading: CircleAvatar(backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6), child: Icon(Icons.receipt_long, color: isDark ? Colors.white70 : Colors.black87, size: 20)),
            title: Text('${ord['customer_name']} — \$${ord['total_amount']}', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Tel: ${ord['customer_phone']} | Location: ${ord['shipping_address']}', style: GoogleFonts.montserrat(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w500)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB))),
                  child: DropdownButton<String>(
                    value: ord['status'] ?? 'pending',
                    underline: const SizedBox(),
                    dropdownColor: isDark ? const Color(0xFF141414) : Colors.white,
                    style: GoogleFonts.montserrat(fontSize: 13, color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                    items: [
                      DropdownMenuItem(value: 'pending', child: Text('Pending', style: TextStyle(color: Colors.orange[800]))),
                      DropdownMenuItem(value: 'shipped', child: Text('Shipped', style: TextStyle(color: Colors.blue[800]))),
                      DropdownMenuItem(value: 'delivered', child: Text('Delivered', style: TextStyle(color: Colors.green[800]))),
                    ],
                    onChanged: (val) async {
                      if (val != null) {
                        await _supabase.from('orders').update({'status': val}).match({'id': ord['id']});
                        _fetchOrders();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.white38 : Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }
}