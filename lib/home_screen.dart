import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ionicons/ionicons.dart';

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

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  String _searchFilter = '';
  String _genderFilter = 'ALL';
  String _selectedCategory = 'HOME';
  bool _isArabic = false;

  // نظام محوّل العملة
  bool _isEgp = false;
  static const double _usdToEgpRate = 50.0;

  String _formatPrice(num? usdPrice) {
    if (usdPrice == null) return _isEgp ? '0 EGP' : '\$0';
    if (_isEgp) {
      final egpVal = (usdPrice * _usdToEgpRate).round();
      return _isArabic ? '$egpVal ج.م' : '$egpVal EGP';
    }
    return '\$${usdPrice.toStringAsFixed(usdPrice % 1 == 0 ? 0 : 2)}';
  }

  String _sortBy = 'NEWEST';
  String _selectedSizeFilter = 'ALL';

  int _currentPage = 1;
  final int _itemsPerPage = 16;
  int _currentHeroIndex = 0;
  Timer? _heroTimer;

  Map<String, dynamic> _storeSettings = {
    'whatsapp_url': 'https://wa.me/201000000000',
    'facebook_url': 'https://facebook.com',
    'instagram_url': 'https://instagram.com',
  };

  final List<Map<String, String>> _heroSlides = [
    {
      'title': 'WALK\nBEYOND\nLIMITS',
      'title_ar': 'تخطَّ\nكل\nالحدود',
      'desc': 'Premium sneakers crafted for comfort, style and everyday performance.',
      'desc_ar':
          'أحذية رياضية فاخرة صُممت لتجمع بين الراحة والأناقة والأداء اليومي.',
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
    _fetchStoreSettings();
    _startHeroAutoPlay();
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
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

  Future<void> _fetchStoreSettings() async {
    try {
      final data = await _supabase
          .from('store_settings')
          .select()
          .eq('id', 'default')
          .maybeSingle();
      if (data != null) {
        setState(() {
          _storeSettings = Map<String, dynamic>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('products')
          .select('*, product_variants(*)')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
        response ?? [],
      );

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
        temp = temp
            .where(
              (p) =>
                  (p['category']?.toString().toLowerCase() ?? 'men') ==
                  _genderFilter.toLowerCase(),
            )
            .toList();
      }

      if (_selectedCategory == 'NEW ARRIVALS') {
        temp = temp.where((p) => p['is_new_arrival'] == true).toList();
      } else if (_selectedCategory == 'BEST SELLERS') {
        temp = temp.where((p) => p['is_best_seller'] == true).toList();
      }
    }

    if (_selectedSizeFilter != 'ALL') {
      temp = temp.where((p) {
        final variants = p['product_variants'] as List<dynamic>?;
        if (variants == null) return false;
        return variants.any(
          (v) =>
              v['size'] == _selectedSizeFilter &&
              ((v['stock_quantity'] ?? 0) as int) > 0,
        );
      }).toList();
    }

    if (_sortBy == 'PRICE_ASC') {
      temp.sort(
        (a, b) => ((a['base_price'] ?? 0) as num).compareTo(
          (b['base_price'] ?? 0) as num,
        ),
      );
    } else if (_sortBy == 'PRICE_DESC') {
      temp.sort(
        (a, b) => ((b['base_price'] ?? 0) as num).compareTo(
          (a['base_price'] ?? 0) as num,
        ),
      );
    } else {
      temp.sort(
        (a, b) => (b['created_at'] ?? '').toString().compareTo(
          (a['created_at'] ?? '').toString(),
        ),
      );
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
      _selectedSizeFilter = 'ALL';
      _searchFilter = '';
      _searchCtrl.clear();
      _currentPage = 1;
      _applyFilters();
    });
  }

  Future<void> _openSocialUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.parse(url.trim());
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch url: $e');
    }
  }

  List<String> _extractImages(Map<String, dynamic> product) {
    final variants = product['product_variants'] as List<dynamic>?;
    final firstVariant = (variants != null && variants.isNotEmpty)
        ? variants[0]
        : null;
    List<String> images = [];
    if (firstVariant != null) {
      final dynamic urls = firstVariant['image_urls'];
      if (urls != null && urls is List && urls.isNotEmpty) {
        images = urls
            .map((e) {
              String s = e.toString();
              s = s
                  .replaceAll('[', '')
                  .replaceAll(']', '')
                  .replaceAll('"', '')
                  .trim();
              return s;
            })
            .where((s) => s.startsWith('http'))
            .toList();
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

  Future<void> _exportPdfInvoice({
    required String orderId,
    required String customerName,
    required String address,
    required double totalAmount,
    required List<CartItem> purchasedItems,
    required double discountAmount,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'EL DOC',
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      pw.Text(
                        'PREMIUM SNEAKERS & ATELIER',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'OFFICIAL INVOICE',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Order: #${_safeId(orderId)}',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Date: ${DateTime.now().toString().substring(0, 10)}',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 16),
              pw.Text(
                'CUSTOMER DETAILS',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Client: $customerName',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Shipping Destination: $address',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.Text(
                'Payment Method: Cash On Delivery (COD)',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'ITEMIZED BREAKDOWN',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Item Description',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Size',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Price (${_isEgp ? "EGP" : "USD"})',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  ...purchasedItems.map((it) {
                    final totalLinePrice = _isEgp
                        ? (it.price * it.quantity * _usdToEgpRate).round()
                        : (it.price * it.quantity);
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            it.name,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'EU ${it.size}',
                            style: const pw.TextStyle(fontSize: 10),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            '${it.quantity}',
                            style: const pw.TextStyle(fontSize: 10),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            _isEgp
                                ? '$totalLinePrice EGP'
                                : '\$${totalLinePrice.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 10),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.SizedBox(
                  width: 220,
                  child: pw.Column(
                    children: [
                      if (discountAmount > 0) ...[
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Applied Discount:',
                              style: const pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.green,
                              ),
                            ),
                            pw.Text(
                              _isEgp
                                  ? '-${(discountAmount * _usdToEgpRate).round()} EGP'
                                  : '-\$${discountAmount.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                      ],
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Payable (COD):',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            _isEgp
                                ? '${(totalAmount * _usdToEgpRate).round()} EGP'
                                : '\$${totalAmount.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.Spacer(),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.Center(
                child: pw.Text(
                  'Thank you for shopping with EL DOC. For inquiries, contact support via WhatsApp or Instagram.',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'EL_DOC_Invoice_${_safeId(orderId)}.pdf',
    );
  }

  void _showProductDetailsModal(Map<String, dynamic> product) {
    List<String> images = _extractImages(product);
    final variants = product['product_variants'] as List<dynamic>?;
    final firstVariant = (variants != null && variants.isNotEmpty)
        ? variants[0]
        : null;
    final variantId = firstVariant?['id'];
    final stock = firstVariant != null
        ? (firstVariant['stock_quantity'] ?? 10)
        : 10;

    final sizes = ['40', '41', '42', '43', '44', '45'];
    String selectedSize = '42';
    int selectedImageIndex = 0;

    List<Map<String, dynamic>> reviews = [];
    bool isLoadingReviews = true;
    int inputRating = 5;
    final reviewerNameCtrl = TextEditingController();
    final reviewCommentCtrl = TextEditingController();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          if (isLoadingReviews) {
            _supabase
                .from('product_reviews')
                .select()
                .eq('product_id', product['id'])
                .order('created_at', ascending: false)
                .then((data) {
                  setModalState(() {
                    reviews = List<Map<String, dynamic>>.from(data ?? []);
                    isLoadingReviews = false;
                  });
                })
                .catchError((_) {
                  setModalState(() => isLoadingReviews = false);
                });
          }

          double avgRating = 5.0;
          if (reviews.isNotEmpty) {
            final sum = reviews.fold<int>(
              0,
              (acc, r) => acc + ((r['rating'] ?? 5) as int),
            );
            avgRating = sum / reviews.length;
          }

          Widget imagesSection = Container(
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: isMobile ? 260 : 420),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Image.network(
                        images[selectedImageIndex],
                        key: ValueKey<String>(images[selectedImageIndex]),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 60,
                            color: isDark ? Colors.white24 : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (images.length > 1) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 60,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(images.length, (index) {
                        final isSelected = selectedImageIndex == index;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedImageIndex = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF262626)
                                  : Colors.white,
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.transparent,
                                width: 2,
                              ),
                              image: DecorationImage(
                                image: NetworkImage(images[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ],
            ),
          );

          Widget detailsSection = SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 24 : 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stock > 0
                          ? (_isArabic
                                ? 'متوفر ($stock قطعة)'
                                : 'IN STOCK ($stock UNITS)')
                          : (_isArabic ? 'نفذت الكمية' : 'SOLD OUT'),
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: stock > 0
                            ? (isDark ? Colors.greenAccent : Colors.green[700])
                            : (isDark ? Colors.redAccent : Colors.red[700]),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      color: isDark ? Colors.white12 : Colors.black12,
                      child: Text(
                        (product['category'] ?? 'Men').toString().toUpperCase(),
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  product['name'] ?? '',
                  style: GoogleFonts.montserrat(
                    fontSize: isMobile ? 24 : 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < avgRating.round()
                            ? Icons.star
                            : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      '${avgRating.toStringAsFixed(1)} (${reviews.length} ${_isArabic ? "تقييم" : "reviews"})',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _formatPrice(product['base_price']),
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  product['description'] != null &&
                          product['description'].toString().trim().isNotEmpty
                      ? product['description']
                      : (_isArabic
                            ? 'حذاء فاخر مصنوع يدوياً مصمم لضمان أقصى درجات التحمل والأناقة اليومية.'
                            : 'Handcrafted luxury silhouette built for high-performance durability and effortless daily styling.'),
                  style: GoogleFonts.montserrat(
                    color: isDark ? Colors.white54 : Colors.black54,
                    height: 1.6,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isArabic ? 'اختر المقاس (EU)' : 'SELECT SIZE (EU)',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sizes.map((s) {
                    final isSelected = s == selectedSize;
                    return InkWell(
                      onTap: () => setModalState(() => selectedSize = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark
                                    ? const Color(0xFF141414)
                                    : Colors.white),
                          border: Border.all(
                            color: isSelected
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark
                                      ? const Color(0xFF333333)
                                      : const Color(0xFFD1D5DB)),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          s,
                          style: GoogleFonts.montserrat(
                            color: isSelected
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? Colors.white : Colors.black),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: stock <= 0
                        ? null
                        : () {
                            _cart.addItem(
                              productId: product['id'],
                              variantId: variantId,
                              name: product['name'],
                              price:
                                  double.tryParse('${product['base_price']}') ??
                                  0.0,
                              imageUrl: images[0],
                              size: selectedSize,
                            );
                            Navigator.pop(ctx);
                            _openCartDrawer();
                          },
                    child: Text(
                      stock > 0
                          ? (_isArabic ? 'إضافة إلى الحقيبة' : 'ADD TO BAG')
                          : (_isArabic ? 'غير متوفر' : 'OUT OF STOCK'),
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Divider(
                  color: isDark
                      ? const Color(0xFF262626)
                      : const Color(0xFFE5E7EB),
                ),
                const SizedBox(height: 20),
                Text(
                  _isArabic ? 'تقييمات وآراء العملاء' : 'CUSTOMER REVIEWS',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.5,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFF9FAFB),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF262626)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isArabic ? 'أضف تقييمك الخاص:' : 'LEAVE A REVIEW:',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(5, (index) {
                          final starValue = index + 1;
                          return InkWell(
                            onTap: () =>
                                setModalState(() => inputRating = starValue),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                starValue <= inputRating
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 20,
                                color: Colors.amber,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reviewerNameCtrl,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: _isArabic ? 'اسمك الكريم' : 'Your Name',
                          hintStyle: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF141414)
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF333333)
                                  : const Color(0xFFD1D5DB),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reviewCommentCtrl,
                        maxLines: 2,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: _isArabic
                              ? 'اكتب رأيك وتجربتك...'
                              : 'Your feedback on comfort and quality...',
                          hintStyle: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF141414)
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF333333)
                                  : const Color(0xFFD1D5DB),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white
                                : Colors.black,
                            foregroundColor: isDark
                                ? Colors.black
                                : Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          onPressed: () async {
                            if (reviewerNameCtrl.text.isEmpty ||
                                reviewCommentCtrl.text.isEmpty)
                              return;

                            final newReview = {
                              'product_id': product['id'],
                              'author_name': reviewerNameCtrl.text.trim(),
                              'rating': inputRating,
                              'comment': reviewCommentCtrl.text.trim(),
                            };

                            await _supabase
                                .from('product_reviews')
                                .insert(newReview);

                            final updatedData = await _supabase
                                .from('product_reviews')
                                .select()
                                .eq('product_id', product['id'])
                                .order('created_at', ascending: false);

                            setModalState(() {
                              reviews = List<Map<String, dynamic>>.from(
                                updatedData ?? [],
                              );
                              reviewerNameCtrl.clear();
                              reviewCommentCtrl.clear();
                            });
                          },
                          child: Text(
                            _isArabic ? 'نشر التقييم' : 'POST REVIEW',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (reviews.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _isArabic
                          ? 'كن أول من يقيم هذا الحذاء!'
                          : 'No reviews yet. Be the first to review!',
                      style: GoogleFonts.montserrat(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 20,
                      color: isDark
                          ? const Color(0xFF262626)
                          : const Color(0xFFE5E7EB),
                    ),
                    itemBuilder: (context, i) {
                      final rev = reviews[i];
                      final revRating = (rev['rating'] ?? 5) as int;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                rev['author_name'] ?? 'Verified Buyer',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              Row(
                                children: List.generate(5, (sIdx) {
                                  return Icon(
                                    sIdx < revRating
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 12,
                                    color: Colors.amber,
                                  );
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rev['comment'] ?? '',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              height: 1.5,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          );

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: isMobile ? 16 : 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1000,
                maxHeight: isMobile
                    ? MediaQuery.of(context).size.height * 0.9
                    : 800,
              ),
              child: Stack(
                children: [
                  isMobile
                      ? SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [imagesSection, detailsSection],
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 5, child: imagesSection),
                            Expanded(flex: 5, child: detailsSection),
                          ],
                        ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 24,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showOrderSuccessReceiptModal({
    required String orderId,
    required String customerName,
    required String address,
    required double totalAmount,
    required List<CartItem> purchasedItems,
    required double discountAmount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    final itemsSummary = purchasedItems
        .map((it) {
          final linePrice = _formatPrice(it.price * it.quantity);
          return '• ${it.name} (EU ${it.size}) x${it.quantity} - $linePrice';
        })
        .join('\n');

    final waMessage =
        '''
*طلب جديد من متجر EL DOC* 👟
--------------------------------
*رقم الفاتورة:* #${_safeId(orderId)}
*العميل:* $customerName
*عنوان الشحن:* $address

*المنتجات المطلوبة:*
$itemsSummary
${discountAmount > 0 ? '\n*الخصم المطبق:* -${_formatPrice(discountAmount)}' : ''}
*الإجمالي المستحق (COD):* ${_formatPrice(totalAmount)}
--------------------------------
يرجى تأكيد موعد الشحن والتوصيل. شكراً لكم!
''';

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenWidth < 600 ? 16 : 24,
          vertical: 24,
        ),
        child: Container(
          width: 580,
          padding: EdgeInsets.all(screenWidth < 600 ? 24 : 40),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EL DOC',
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          'OFFICIAL DIGITAL RECEIPT',
                          style: GoogleFonts.montserrat(
                            fontSize: 8,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        _isArabic ? 'تم التسجيل' : 'CONFIRMED',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  color: isDark
                      ? const Color(0xFF262626)
                      : const Color(0xFFE5E7EB),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_isArabic ? "رقم الطلب" : "ORDER ID"}: #${_safeId(orderId)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    Text(
                      '${_isArabic ? "التاريخ" : "DATE"}: ${DateTime.now().toString().substring(0, 10)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${_isArabic ? "العميل" : "Client"}: $customerName',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_isArabic ? "العنوان" : "Shipping Destination"}: $address',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isArabic ? 'تفاصيل المشتريات' : 'ITEMS PURCHASED',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFF9FAFB),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF262626)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: purchasedItems.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 10,
                      color: isDark
                          ? const Color(0xFF262626)
                          : const Color(0xFFE5E7EB),
                    ),
                    itemBuilder: (context, i) {
                      final item = purchasedItems[i];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.name} (EU ${item.size}) x${item.quantity}',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          Text(
                            _formatPrice(item.price * item.quantity),
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (discountAmount > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isArabic ? 'الخصم المطبق:' : 'PROMO DISCOUNT:',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '-${_formatPrice(discountAmount)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isArabic ? 'المبلغ المستحق:' : 'TOTAL PAYABLE:',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      _formatPrice(totalAmount),
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    icon: const Icon(Ionicons.logoWhatsapp, size: 18),
                    label: Text(
                      _isArabic
                          ? 'تأكيد الطلب الفوري عبر واتساب'
                          : 'CONFIRM ORDER VIA WHATSAPP',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        fontSize: 11,
                      ),
                    ),
                    onPressed: () {
                      String baseWa =
                          _storeSettings['whatsapp_url'] ??
                          'https://wa.me/201000000000';
                      baseWa = baseWa.split('?').first;
                      final targetUrl =
                          '$baseWa?text=${Uri.encodeComponent(waMessage)}';
                      _openSocialUrl(targetUrl);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Colors.black,
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF333333)
                                : const Color(0xFFD1D5DB),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 16,
                        ),
                        label: Text(
                          _isArabic ? 'تحميل الفاتورة' : 'PDF INVOICE',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                        onPressed: () {
                          _exportPdfInvoice(
                            orderId: orderId,
                            customerName: customerName,
                            address: address,
                            totalAmount: totalAmount,
                            purchasedItems: purchasedItems,
                            discountAmount: discountAmount,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          _isArabic ? 'متابعة التسوق' : 'CONTINUE',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            fontSize: 10,
                          ),
                        ),
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

  void _openCartDrawer() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final promoCtrl = TextEditingController();

    double discountMultiplier = 0.0;
    String promoStatus = '';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth > 500 ? 500.0 : screenWidth;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cart',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(_isArabic ? -1 : 1, 0),
            end: Offset.zero,
          ).animate(CurveTween(curve: Curves.easeOutQuart).animate(anim1)),
          child: Align(
            alignment: _isArabic ? Alignment.centerLeft : Alignment.centerRight,
            child: Material(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              child: SizedBox(
                width: drawerWidth,
                height: double.infinity,
                child: StatefulBuilder(
                  builder: (context, setDrawerState) {
                    final subtotal = _cart.totalPrice;
                    final discountAmount = subtotal * discountMultiplier;
                    final finalTotal = subtotal - discountAmount;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 36, 28, 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isArabic
                                    ? 'حقيبة التسوق (${_cart.totalCount})'
                                    : 'SHOPPING BAG (${_cart.totalCount})',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 1.5,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 22,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: isDark
                              ? const Color(0xFF262626)
                              : const Color(0xFFF3F4F6),
                        ),
                        Expanded(
                          child: _cart.items.isEmpty
                              ? _buildPremiumEmptyCartState(isDark)
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 20,
                                  ),
                                  itemCount: _cart.items.length,
                                  separatorBuilder: (_, __) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Divider(
                                      height: 1,
                                      color: isDark
                                          ? const Color(0xFF262626)
                                          : const Color(0xFFF3F4F6),
                                    ),
                                  ),
                                  itemBuilder: (context, idx) {
                                    final item = _cart.items[idx];
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF1A1A1A)
                                                : const Color(0xFFF9FAFB),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: Image.network(
                                              item.imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(
                                                    Icons.image,
                                                    color: isDark
                                                        ? Colors.white12
                                                        : Colors.black12,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                style: GoogleFonts.montserrat(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${_isArabic ? "المقاس" : "Size"}: EU ${item.size}',
                                                style: GoogleFonts.montserrat(
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.black54,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Container(
                                                width: 90,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF333333,
                                                          )
                                                        : const Color(
                                                            0xFFE5E7EB,
                                                          ),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    InkWell(
                                                      onTap: () {
                                                        _cart.updateQuantity(
                                                          idx,
                                                          -1,
                                                        );
                                                        setDrawerState(() {});
                                                      },
                                                      child: SizedBox(
                                                        width: 28,
                                                        child: Center(
                                                          child: Icon(
                                                            Icons.remove,
                                                            size: 12,
                                                            color: isDark
                                                                ? Colors.white70
                                                                : Colors
                                                                      .black87,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      '${item.quantity}',
                                                      style:
                                                          GoogleFonts.montserrat(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                            color: isDark
                                                                ? Colors.white
                                                                : Colors.black,
                                                          ),
                                                    ),
                                                    InkWell(
                                                      onTap: () {
                                                        _cart.updateQuantity(
                                                          idx,
                                                          1,
                                                        );
                                                        setDrawerState(() {});
                                                      },
                                                      child: SizedBox(
                                                        width: 28,
                                                        child: Center(
                                                          child: Icon(
                                                            Icons.add,
                                                            size: 12,
                                                            color: isDark
                                                                ? Colors.white70
                                                                : Colors
                                                                      .black87,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _formatPrice(
                                            item.price * item.quantity,
                                          ),
                                          style: GoogleFonts.montserrat(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                        if (_cart.items.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1A1A1A)
                                  : const Color(0xFFF9FAFB),
                              border: Border(
                                top: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF262626)
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: promoCtrl,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: _isArabic
                                              ? 'كود الخصم (ELDOC10 / VIP20)'
                                              : 'PROMO CODE',
                                          hintStyle: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                          filled: true,
                                          fillColor: isDark
                                              ? const Color(0xFF141414)
                                              : Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.zero,
                                            borderSide: BorderSide(
                                              color: isDark
                                                  ? const Color(0xFF333333)
                                                  : const Color(0xFFD1D5DB),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        foregroundColor: isDark
                                            ? Colors.black
                                            : Colors.white,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.zero,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final inputCode = promoCtrl.text
                                            .trim()
                                            .toUpperCase();
                                        if (inputCode.isEmpty) return;

                                        try {
                                          final res = await _supabase
                                              .from('promo_codes')
                                              .select()
                                              .eq('code', inputCode)
                                              .eq('is_active', true)
                                              .maybeSingle();

                                          if (res != null) {
                                            final double percent =
                                                (res['discount_percentage']
                                                        as num)
                                                    .toDouble();
                                            final int maxUses =
                                                res['max_uses'] ?? 100;
                                            final int timesUsed =
                                                res['times_used'] ?? 0;

                                            if (timesUsed >= maxUses) {
                                              setDrawerState(() {
                                                discountMultiplier = 0.0;
                                                promoStatus = _isArabic
                                                    ? 'انتهت صلاحية هذا الكود'
                                                    : 'CODE EXPIRED';
                                              });
                                              return;
                                            }

                                            setDrawerState(() {
                                              discountMultiplier =
                                                  percent / 100.0;
                                              promoStatus = _isArabic
                                                  ? 'تم تطبيق خصم ${percent.toInt()}% بنجاح!'
                                                  : '${percent.toInt()}% DISCOUNT APPLIED!';
                                            });
                                          } else {
                                            setDrawerState(() {
                                              discountMultiplier = 0.0;
                                              promoStatus = _isArabic
                                                  ? 'كود الخصم غير صالح'
                                                  : 'INVALID PROMO CODE';
                                            });
                                          }
                                        } catch (e) {
                                          setDrawerState(() {
                                            discountMultiplier = 0.0;
                                            promoStatus = _isArabic
                                                ? 'خطأ في فحص الكود'
                                                : 'ERROR VERIFYING CODE';
                                          });
                                        }
                                      },
                                      child: Text(
                                        _isArabic ? 'تطبيق' : 'APPLY',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (promoStatus.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    promoStatus,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: discountMultiplier > 0
                                          ? Colors.green
                                          : Colors.redAccent,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCartTextField(
                                        nameCtrl,
                                        _isArabic
                                            ? 'الاسم بالكامل'
                                            : 'Full Name',
                                        isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildCartTextField(
                                        phoneCtrl,
                                        _isArabic
                                            ? 'رقم الهاتف'
                                            : 'Contact Phone',
                                        isDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildCartTextField(
                                  addressCtrl,
                                  _isArabic
                                      ? 'العنوان بالتفصيل'
                                      : 'Shipping Address',
                                  isDark,
                                ),
                                const SizedBox(height: 16),
                                if (discountMultiplier > 0) ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _isArabic ? 'قيمة الخصم:' : 'DISCOUNT:',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: Colors.green,
                                        ),
                                      ),
                                      Text(
                                        '-${_formatPrice(discountAmount)}',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _isArabic
                                          ? 'الإجمالي النهائي:'
                                          : 'FINAL TOTAL:',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    Text(
                                      _formatPrice(finalTotal),
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      foregroundColor: isDark
                                          ? Colors.black
                                          : Colors.white,
                                      elevation: 0,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero,
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (nameCtrl.text.isEmpty ||
                                          phoneCtrl.text.isEmpty ||
                                          addressCtrl.text.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  _isArabic
                                                      ? 'يرجى إكمال جميع بيانات الشحن'
                                                      : 'Please complete all shipping address fields',
                                                  style: GoogleFonts.montserrat(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            );
                                        return;
                                      }

                                      final appliedPromo = promoCtrl.text
                                          .trim()
                                          .toUpperCase();

                                      // 1. تسجيل الطلب في جدول orders
                                      final orderRes = await _supabase
                                          .from('orders')
                                          .insert({
                                            'customer_name': nameCtrl.text
                                                .trim(),
                                            'customer_phone': phoneCtrl.text
                                                .trim(),
                                            'shipping_address': addressCtrl.text
                                                .trim(),
                                            'total_amount': finalTotal,
                                            'status': 'pending',
                                            'payment_method':
                                                'cash_on_delivery',
                                          })
                                          .select()
                                          .single();

                                      // 2. تحديث عداد استخدام الكوبون إن وُجد
                                      if (discountMultiplier > 0 &&
                                          appliedPromo.isNotEmpty) {
                                        try {
                                          final promoData = await _supabase
                                              .from('promo_codes')
                                              .select('times_used, max_uses')
                                              .eq('code', appliedPromo)
                                              .maybeSingle();

                                          if (promoData != null) {
                                            final currentUsed =
                                                (promoData['times_used'] ?? 0)
                                                    as int;
                                            final maxUses =
                                                (promoData['max_uses'] ?? 100)
                                                    as int;
                                            final newUsed = currentUsed + 1;

                                            await _supabase
                                                .from('promo_codes')
                                                .update({
                                                  'times_used': newUsed,
                                                  'is_active':
                                                      newUsed < maxUses,
                                                })
                                                .eq('code', appliedPromo);
                                          }
                                        } catch (e) {
                                          debugPrint(
                                            'Error updating promo code stats: $e',
                                          );
                                        }
                                      }

                                      // 3. خصم كميات المخزون وتسجيل المنتجات
                                      final List<CartItem> orderedItemsCopy =
                                          List.from(_cart.items);

                                      for (var item in orderedItemsCopy) {
                                        await _supabase
                                            .from('order_items')
                                            .insert({
                                              'order_id': orderRes['id'],
                                              'product_variant_id':
                                                  item.variantId,
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

                                          int currentStock =
                                              variantData['stock_quantity'] ??
                                              0;
                                          int newStock =
                                              currentStock - item.quantity;
                                          if (newStock < 0) newStock = 0;

                                          await _supabase
                                              .from('product_variants')
                                              .update({
                                                'stock_quantity': newStock,
                                              })
                                              .eq('id', vId);
                                        }
                                      }

                                      _cart.clearCart();
                                      Navigator.pop(context);
                                      _fetchProducts();

                                      _showOrderSuccessReceiptModal(
                                        orderId: orderRes['id'].toString(),
                                        customerName: nameCtrl.text.trim(),
                                        address: addressCtrl.text.trim(),
                                        totalAmount: finalTotal,
                                        purchasedItems: orderedItemsCopy,
                                        discountAmount: discountAmount,
                                      );
                                    },
                                    child: Text(
                                      _isArabic
                                          ? 'تأكيد الطلب (الدفع عند الاستلام)'
                                          : 'CONFIRM ORDER (CASH)',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openWishlistDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth > 500 ? 500.0 : screenWidth;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Wishlist',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(_isArabic ? -1 : 1, 0),
            end: Offset.zero,
          ).animate(CurveTween(curve: Curves.easeOutQuart).animate(anim1)),
          child: Align(
            alignment: _isArabic ? Alignment.centerLeft : Alignment.centerRight,
            child: Material(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              child: SizedBox(
                width: drawerWidth,
                height: double.infinity,
                child: StatefulBuilder(
                  builder: (context, setWishState) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isArabic
                                  ? 'قائمة المفضلة (${_wishlist.totalCount})'
                                  : 'WISHLIST (${_wishlist.totalCount})',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 1.5,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 22,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: isDark
                            ? const Color(0xFF262626)
                            : const Color(0xFFF3F4F6),
                      ),
                      Expanded(
                        child: _wishlist.items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.favorite_border,
                                      size: 70,
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.black12,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      _isArabic
                                          ? 'قائمة المفضلة فارغة'
                                          : 'YOUR WISHLIST IS EMPTY',
                                      style: GoogleFonts.montserrat(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _isArabic
                                          ? 'احفظ الكوتشيات المميزة للرجوع إليها لاحقاً.'
                                          : 'Save luxury sneakers you love for later.',
                                      style: GoogleFonts.montserrat(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 36),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        side: BorderSide(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          width: 1.5,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.zero,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _changeCategory('SHOP');
                                      },
                                      child: Text(
                                        _isArabic
                                            ? 'تصفح المتجر'
                                            : 'EXPLORE COLLECTION',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 20,
                                ),
                                itemCount: _wishlist.items.length,
                                separatorBuilder: (_, __) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Divider(
                                    height: 1,
                                    color: isDark
                                        ? const Color(0xFF262626)
                                        : const Color(0xFFF3F4F6),
                                  ),
                                ),
                                itemBuilder: (context, idx) {
                                  final item = _wishlist.items[idx];
                                  final images = _extractImages(item);
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1A1A1A)
                                              : const Color(0xFFF9FAFB),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: Image.network(
                                            images[0],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Icon(
                                              Icons.image,
                                              color: isDark
                                                  ? Colors.white12
                                                  : Colors.black12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'] ?? '',
                                              style: GoogleFonts.montserrat(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatPrice(item['base_price']),
                                              style: GoogleFonts.montserrat(
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: isDark
                                                        ? Colors.white
                                                        : Colors.black,
                                                    foregroundColor: isDark
                                                        ? Colors.black
                                                        : Colors.white,
                                                    elevation: 0,
                                                    shape:
                                                        const RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.zero,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 8,
                                                        ),
                                                  ),
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    _showProductDetailsModal(
                                                      item,
                                                    );
                                                  },
                                                  child: Text(
                                                    _isArabic
                                                        ? 'عرض الخيارات'
                                                        : 'SELECT SIZE',
                                                    style:
                                                        GoogleFonts.montserrat(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 18,
                                                    color: Colors.redAccent,
                                                  ),
                                                  onPressed: () {
                                                    _wishlist.removeItem(
                                                      item['id'],
                                                    );
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
          Icon(
            Icons.shopping_bag_outlined,
            size: 70,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          const SizedBox(height: 24),
          Text(
            _isArabic ? 'حقيبة التسوق فارغة' : 'YOUR BAG IS EMPTY',
            style: GoogleFonts.montserrat(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isArabic
                ? 'لم تقم بإضافة أي كوتشيات بعد.'
                : 'Looks like you haven\'t added any items yet.',
            style: GoogleFonts.montserrat(
              color: isDark ? Colors.white54 : Colors.black54,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 36),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : Colors.black,
              side: BorderSide(
                color: isDark ? Colors.white : Colors.black,
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _changeCategory('SHOP');
            },
            child: Text(
              _isArabic ? 'ابدأ التسوق' : 'START SHOPPING',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartTextField(
    TextEditingController controller,
    String label,
    bool isDark,
  ) {
    return TextField(
      controller: controller,
      style: GoogleFonts.montserrat(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.montserrat(
          color: isDark ? Colors.white54 : Colors.black54,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF141414) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFD1D5DB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: isDark ? Colors.white : Colors.black,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTimeline(String status, bool isDark) {
    final currentStatus = status.toLowerCase();
    int currentStep = 0;
    if (currentStatus == 'shipped') currentStep = 1;
    if (currentStatus == 'delivered') currentStep = 2;

    final steps = [
      {
        'title': _isArabic ? 'تم التأكيد' : 'Confirmed',
        'icon': Icons.check_circle_outline,
      },
      {
        'title': _isArabic ? 'في الشحن' : 'On The Way',
        'icon': Icons.local_shipping_outlined,
      },
      {
        'title': _isArabic ? 'تم التسليم' : 'Delivered',
        'icon': Icons.home_outlined,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isCompleted = index <= currentStep;
          final isCurrent = index == currentStep;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isCompleted
                          ? Colors.green
                          : (isDark
                                ? const Color(0xFF262626)
                                : Colors.grey[300]),
                      child: Icon(
                        steps[index]['icon'] as IconData,
                        size: 14,
                        color: isCompleted
                            ? Colors.white
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[index]['title'] as String,
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isCompleted
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ],
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: index < currentStep
                          ? Colors.green
                          : (isDark
                                ? const Color(0xFF262626)
                                : Colors.grey[300]),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _showCustomerAccountModal() {
    final searchPhoneCtrl = TextEditingController();
    List<Map<String, dynamic>> customerOrders = [];
    bool isSearching = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setAccState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth < 600 ? 16 : 24,
            vertical: 24,
          ),
          title: Text(
            _isArabic
                ? 'بوابة العميل ومتابعة الشحنات'
                : 'CUSTOMER TRACKING PORTAL',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isArabic
                      ? 'أدخل رقم هاتفك المسجل لمتابعة شحناتك الحالية لحظة بلحظة:'
                      : 'Track your sneakers in real-time by entering your phone number:',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchPhoneCtrl,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          labelText: _isArabic ? 'رقم الهاتف' : 'Phone Number',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 12,
                          ),
                          border: const OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF333333)
                                  : Colors.grey,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () async {
                          if (searchPhoneCtrl.text.isEmpty) return;
                          setAccState(() => isSearching = true);
                          final data = await _supabase
                              .from('orders')
                              .select()
                              .eq(
                                'customer_phone',
                                searchPhoneCtrl.text.trim(),
                              );
                          setAccState(() {
                            customerOrders = List<Map<String, dynamic>>.from(
                              data ?? [],
                            );
                            isSearching = false;
                          });
                        },
                        child: Text(
                          _isArabic ? 'بحث' : 'TRACK',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (isSearching)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  )
                else if (customerOrders.isNotEmpty)
                  SizedBox(
                    height: 260,
                    child: ListView.separated(
                      itemCount: customerOrders.length,
                      separatorBuilder: (_, __) => Divider(
                        color: isDark
                            ? const Color(0xFF262626)
                            : Colors.grey[300],
                      ),
                      itemBuilder: (context, i) {
                        final ord = customerOrders[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_isArabic ? "طلب رقم" : "Order"} #${_safeId(ord['id'])}',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    _formatPrice(ord['total_amount']),
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _buildOrderTimeline(
                                ord['status'] ?? 'pending',
                                isDark,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                else if (searchPhoneCtrl.text.isNotEmpty)
                  Text(
                    _isArabic
                        ? 'لم يتم العثور على طلبات مرتبطة بهذا الرقم.'
                        : 'No orders found with this phone number.',
                    style: GoogleFonts.montserrat(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                _isArabic ? 'إغلاق' : 'CLOSE',
                style: GoogleFonts.montserrat(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPolicyModal(String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenWidth < 600 ? 16 : 24,
          vertical: 24,
        ),
        child: Container(
          width: 600,
          padding: EdgeInsets.all(screenWidth < 600 ? 24 : 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: screenWidth < 600 ? 18 : 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(
                color: isDark
                    ? const Color(0xFF333333)
                    : const Color(0xFFE5E7EB),
              ),
              const SizedBox(height: 18),
              Text(
                content,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  height: 1.8,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              Align(
                alignment: _isArabic
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: isDark ? Colors.white : Colors.black,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    _isArabic ? 'إغلاق' : 'CLOSE',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
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
              height: 360,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 48),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(width: 200, height: 28, color: bgColor),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width < 650
                    ? 2
                    : (MediaQuery.of(context).size.width < 1050 ? 3 : 4),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.68,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Container(color: baseColor)),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 12,
                              color: baseColor,
                            ),
                            const SizedBox(height: 8),
                            Container(width: 60, height: 12, color: baseColor),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 850;

    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        endDrawer: isMobile ? _buildMobileNavigationDrawer(isDark) : null,
        body: Column(
          children: [
            _buildTopBanner(isDark),
            _buildSlimHeader(isDark, isMobile),
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
                                    _buildHeroSection(isDark, isMobile),
                                    SizedBox(height: isMobile ? 36 : 60),
                                    _buildFeaturesBar(isDark, isMobile),
                                    SizedBox(height: isMobile ? 48 : 80),
                                    _buildHomePreviewSection(
                                      title: _isArabic
                                          ? 'وصل حديثاً'
                                          : 'NEW ARRIVALS',
                                      isNew: true,
                                      isDark: isDark,
                                      isMobile: isMobile,
                                    ),
                                    SizedBox(height: isMobile ? 48 : 80),
                                    _buildHomePreviewSection(
                                      title: _isArabic
                                          ? 'الأكثر مبيعاً'
                                          : 'BEST SELLERS',
                                      isNew: false,
                                      isDark: isDark,
                                      isMobile: isMobile,
                                    ),
                                    SizedBox(height: isMobile ? 60 : 100),
                                  ] else ...[
                                    const SizedBox(height: 32),
                                    _buildFullShopCatalog(isDark, isMobile),
                                    SizedBox(height: isMobile ? 60 : 120),
                                  ],
                                ],
                              ),
                      ),
                    ),
                    _buildFooter(context, isDark, isMobile),
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      width: double.infinity,
      child: Center(
        child: Text(
          _isArabic
              ? 'شحن مجاني للطلبات فوق 100\$ | إرجاع مجاني خلال 14 يوماً'
              : 'FREE SHIPPING OVER \$100 | FREE 14-DAY RETURNS',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 9.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSlimHeader(bool isDark, bool isMobile) {
    final links = [
      {'en': 'HOME', 'ar': 'الرئيسية', 'key': 'HOME'},
      {'en': 'SHOP', 'ar': 'المتجر', 'key': 'SHOP'},
      {'en': 'NEW ARRIVALS', 'ar': 'وصل حديثاً', 'key': 'NEW ARRIVALS'},
      {'en': 'BEST SELLERS', 'ar': 'الأكثر طلباً', 'key': 'BEST SELLERS'},
    ];

    final searchSuggestions = _searchFilter.trim().isEmpty
        ? <Map<String, dynamic>>[]
        : _allProducts
              .where((p) {
                final name = (p['name'] ?? '').toString().toLowerCase();
                return name.contains(_searchFilter.toLowerCase().trim());
              })
              .take(5)
              .toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: 12,
      ),
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
                Text(
                  'EL DOC',
                  style: GoogleFonts.montserrat(
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    height: 1,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  'PREMIUM SNEAKERS',
                  style: GoogleFonts.montserrat(
                    fontSize: 7.5,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile)
            Row(
              children: links.map((link) {
                final isSelected = _selectedCategory == link['key'];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: () => _changeCategory(link['key']!),
                    child: Text(
                      _isArabic ? link['ar']! : link['en']!,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w600,
                        letterSpacing: 1.2,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white54 : Colors.black54),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => setState(() => _isEgp = !_isEgp),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF1F5F9),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF333333)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    _isEgp ? 'EGP' : 'USD',
                    style: GoogleFonts.montserrat(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!isMobile) ...[
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      width: 170,
                      height: 36,
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocusNode,
                        onChanged: (val) {
                          setState(() {
                            _searchFilter = val;
                            _applyFilters();
                          });
                        },
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: _isArabic ? 'بحث...' : 'Search...',
                          hintStyle: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          suffixIcon: _searchFilter.isNotEmpty
                              ? InkWell(
                                  onTap: () {
                                    setState(() {
                                      _searchCtrl.clear();
                                      _searchFilter = '';
                                      _applyFilters();
                                    });
                                  },
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                  ),
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFFF3F4F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    if (searchSuggestions.isNotEmpty &&
                        _searchFocusNode.hasFocus)
                      Positioned(
                        top: 44,
                        left: _isArabic ? null : 0,
                        right: _isArabic ? 0 : null,
                        child: Container(
                          width: 300,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1A1A1A)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF262626)
                                  : const Color(0xFFE5E7EB),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: searchSuggestions.map((prod) {
                              final images = _extractImages(prod);
                              return InkWell(
                                onTap: () {
                                  _searchFocusNode.unfocus();
                                  _showProductDetailsModal(prod);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      Image.network(
                                        images[0],
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          prod['name'] ?? '',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                                      Text(
                                        _formatPrice(prod['base_price']),
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
              InkWell(
                onTap: _openWishlistDrawer,
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.favorite_border,
                        size: 21,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (_wishlist.totalCount > 0)
                      Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_wishlist.totalCount}',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              InkWell(
                onTap: _openCartDrawer,
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 21,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (_cart.totalCount > 0)
                      Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white : Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_cart.totalCount}',
                          style: GoogleFonts.montserrat(
                            color: isDark ? Colors.black : Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isMobile)
                Builder(
                  builder: (scaffoldCtx) => IconButton(
                    icon: Icon(
                      Icons.menu,
                      size: 24,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onPressed: () => Scaffold.of(scaffoldCtx).openEndDrawer(),
                  ),
                )
              else ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.person_outline,
                    size: 22,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: _showCustomerAccountModal,
                ),
                IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode : Icons.dark_mode,
                    size: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  onPressed: () => themeNotifier.value = isDark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                ),
                InkWell(
                  onTap: () => setState(() => _isArabic = !_isArabic),
                  child: Text(
                    _isArabic ? 'EN' : 'عربي',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNavigationDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'EL DOC',
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                onChanged: (val) {
                  setState(() {
                    _searchFilter = val;
                    _applyFilters();
                  });
                },
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: _isArabic
                      ? 'بحث عن موديل...'
                      : 'Search sneakers...',
                  prefixIcon: Icon(
                    Icons.search,
                    size: 16,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  filled: true,
                  isDense: true,
                  fillColor: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildDrawerItem(
                'HOME',
                _isArabic ? 'الرئيسية' : 'HOME',
                () => _changeCategory('HOME'),
                isDark,
              ),
              _buildDrawerItem(
                'SHOP',
                _isArabic ? 'المتجر' : 'SHOP',
                () => _changeCategory('SHOP'),
                isDark,
              ),
              _buildDrawerItem(
                'NEW ARRIVALS',
                _isArabic ? 'وصل حديثاً' : 'NEW ARRIVALS',
                () => _changeCategory('NEW ARRIVALS'),
                isDark,
              ),
              _buildDrawerItem(
                'BEST SELLERS',
                _isArabic ? 'الأكثر طلباً' : 'BEST SELLERS',
                () => _changeCategory('BEST SELLERS'),
                isDark,
              ),
              const Spacer(),
              Divider(
                color: isDark
                    ? const Color(0xFF262626)
                    : const Color(0xFFE5E7EB),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.person_outline,
                  color: isDark ? Colors.white : Colors.black,
                ),
                title: Text(
                  _isArabic ? 'بوابة العميل وتتبع الشحنات' : 'Customer Portal',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomerAccountModal();
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _isArabic = !_isArabic),
                    icon: const Icon(Icons.language, size: 16),
                    label: Text(
                      _isArabic ? 'English' : 'عربي',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                      size: 18,
                    ),
                    onPressed: () => themeNotifier.value = isDark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    String key,
    String title,
    VoidCallback onTap,
    bool isDark,
  ) {
    final isSelected = _selectedCategory == key;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          color: isSelected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.white60 : Colors.black54),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildHeroSection(bool isDark, bool isMobile) {
    final slide = _heroSlides[_currentHeroIndex];

    Widget textContent = Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _isArabic ? slide['title_ar']! : slide['title']!,
            key: ValueKey<String>('${_currentHeroIndex}_title'),
            textAlign: isMobile ? TextAlign.center : TextAlign.start,
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 36 : 56,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: isMobile ? -1 : -2,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _isArabic ? slide['desc_ar']! : slide['desc']!,
            key: ValueKey<String>('${_currentHeroIndex}_desc'),
            textAlign: isMobile ? TextAlign.center : TextAlign.start,
            style: GoogleFonts.montserrat(
              fontSize: isMobile ? 13 : 15,
              color: isDark ? Colors.white70 : Colors.black54,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: isMobile
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 5,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 36,
                  vertical: isMobile ? 14 : 20,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: () => _changeCategory('SHOP'),
              child: Text(
                _isArabic ? 'تسوق الآن' : 'SHOP NOW',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black,
                side: BorderSide(
                  color: isDark ? Colors.white : Colors.black87,
                  width: 1.5,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 36,
                  vertical: isMobile ? 14 : 20,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: () => _changeCategory('NEW ARRIVALS'),
              child: Text(
                _isArabic ? 'استكشف' : 'EXPLORE',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    Widget imageContent = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: Container(
              key: ValueKey<String>(slide['image']!),
              height: isMobile ? 240 : 480,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(slide['image']!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(width: 32),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_heroSlides.length, (idx) {
              final isCurrent = _currentHeroIndex == idx;
              return InkWell(
                onTap: () => setState(() => _currentHeroIndex = idx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '0${idx + 1}',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                      color: isCurrent
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.white30 : Colors.black26),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF111111) : const Color(0xFFF9FAFB),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 48,
        vertical: isMobile ? 32 : 48,
      ),
      child: isMobile
          ? Column(
              children: [imageContent, const SizedBox(height: 24), textContent],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 5, child: textContent),
                Expanded(flex: 6, child: imageContent),
              ],
            ),
    );
  }

  Widget _buildFeaturesBar(bool isDark, bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48),
      child: Wrap(
        spacing: 24,
        runSpacing: 20,
        alignment: isMobile ? WrapAlignment.center : WrapAlignment.spaceBetween,
        children: [
          _buildFeatureItem(
            Icons.local_shipping_outlined,
            _isArabic ? 'شحن مجاني' : 'FREE SHIPPING',
            _isArabic ? 'للطلبات فوق 100\$' : 'On orders over \$100',
            isDark,
          ),
          _buildFeatureItem(
            Icons.refresh_outlined,
            _isArabic ? 'إرجاع واستبدال' : 'EASY RETURNS',
            _isArabic ? 'خلال 14 يوماً' : '14 days return policy',
            isDark,
          ),
          _buildFeatureItem(
            Icons.verified_user_outlined,
            _isArabic ? 'دفع آمن' : 'SECURE PAYMENT',
            _isArabic ? 'دفع آمن 100%' : '100% secure checkout',
            isDark,
          ),
          _buildFeatureItem(
            Icons.headset_mic_outlined,
            _isArabic ? 'دعم مستمر' : '24/7 SUPPORT',
            _isArabic ? 'فريقنا في خدمتك' : "We're here to help",
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
    String subtitle,
    bool isDark,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 26, color: isDark ? Colors.white : Colors.black87),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                letterSpacing: 0.5,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: GoogleFonts.montserrat(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHomePreviewSection({
    required String title,
    required bool isNew,
    required bool isDark,
    required bool isMobile,
  }) {
    List<Map<String, dynamic>> previewList = isNew
        ? _filteredProducts
              .where((p) => p['is_new_arrival'] == true)
              .take(4)
              .toList()
        : _filteredProducts
              .where((p) => p['is_best_seller'] == true)
              .take(4)
              .toList();

    if (previewList.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth < 650 ? 2 : (screenWidth < 1050 ? 3 : 4);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: isMobile ? 18 : 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              TextButton(
                onPressed: () =>
                    _changeCategory(isNew ? 'NEW ARRIVALS' : 'BEST SELLERS'),
                child: Row(
                  children: [
                    Text(
                      _isArabic ? 'عرض الكل' : 'VIEW ALL',
                      style: GoogleFonts.montserrat(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _isArabic ? Icons.arrow_back : Icons.arrow_forward,
                      size: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: isMobile ? 14 : 24,
              crossAxisSpacing: isMobile ? 14 : 24,
              childAspectRatio: isMobile ? 0.65 : 0.72,
            ),
            itemCount: previewList.length,
            itemBuilder: (context, index) {
              return PremiumProductCard(
                item: previewList[index],
                isNewBadge: isNew,
                isArabic: _isArabic,
                priceFormatted: _formatPrice(previewList[index]['base_price']),
                onTap: () => _showProductDetailsModal(previewList[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFullShopCatalog(bool isDark, bool isMobile) {
    int totalProducts = _filteredProducts.length;
    int totalPages = totalProducts == 0
        ? 1
        : (totalProducts / _itemsPerPage).ceil();
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = (startIndex + _itemsPerPage > totalProducts)
        ? totalProducts
        : startIndex + _itemsPerPage;

    List<Map<String, dynamic>> pageItems = startIndex < totalProducts
        ? _filteredProducts.sublist(startIndex, endIndex)
        : [];
    String pageTitle = _selectedCategory == 'SHOP'
        ? (_isArabic ? 'كل المنتجات' : 'ALL COLLECTION')
        : (_selectedCategory == 'NEW ARRIVALS'
              ? (_isArabic ? 'وصل حديثاً' : 'NEW ARRIVALS')
              : (_isArabic ? 'الأكثر طلباً' : 'BEST SELLERS'));

    final sizeOptions = ['ALL', '40', '41', '42', '43', '44', '45'];
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth < 650 ? 2 : (screenWidth < 1050 ? 3 : 4);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                pageTitle,
                style: GoogleFonts.montserrat(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                _isArabic
                    ? 'عرض $totalProducts منتج'
                    : 'SHOWING $totalProducts RESULTS',
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? const Color(0xFF262626)
                      : const Color(0xFFE5E7EB),
                ),
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF262626)
                      : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isArabic ? 'المقاس:' : 'SIZE:',
                      style: GoogleFonts.montserrat(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 6,
                      children: sizeOptions.map((s) {
                        final isSelected = _selectedSizeFilter == s;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedSizeFilter = s;
                              _currentPage = 1;
                              _applyFilters();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? Colors.white : Colors.black)
                                  : (isDark
                                        ? const Color(0xFF1A1A1A)
                                        : const Color(0xFFF3F4F6)),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark
                                          ? const Color(0xFF333333)
                                          : const Color(0xFFE5E7EB)),
                              ),
                            ),
                            child: Text(
                              s,
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? (isDark ? Colors.black : Colors.white)
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isArabic ? 'ترتيب:' : 'SORT:',
                      style: GoogleFonts.montserrat(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox(),
                      dropdownColor: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'NEWEST',
                          child: Text(_isArabic ? 'الأحدث' : 'Newest'),
                        ),
                        DropdownMenuItem(
                          value: 'PRICE_ASC',
                          child: Text(
                            _isArabic ? 'السعر (الأقل)' : 'Price: Low',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'PRICE_DESC',
                          child: Text(
                            _isArabic ? 'السعر (الأعلى)' : 'Price: High',
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _sortBy = val;
                            _currentPage = 1;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (pageItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(60),
                child: Text(
                  _isArabic
                      ? 'لم يتم العثور على منتجات مطابقة.'
                      : 'No products found matching criteria.',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: isMobile ? 14 : 24,
                crossAxisSpacing: isMobile ? 14 : 24,
                childAspectRatio: isMobile ? 0.65 : 0.72,
              ),
              itemCount: pageItems.length,
              itemBuilder: (context, index) {
                return PremiumProductCard(
                  item: pageItems[index],
                  isNewBadge:
                      _selectedCategory == 'NEW ARRIVALS' ||
                      pageItems[index]['is_new_arrival'] == true,
                  isArabic: _isArabic,
                  priceFormatted: _formatPrice(pageItems[index]['base_price']),
                  onTap: () => _showProductDetailsModal(pageItems[index]),
                );
              },
            ),
            if (totalPages > 1) ...[
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _isArabic
                          ? Icons.arrow_forward_ios
                          : Icons.arrow_back_ios,
                      size: 12,
                    ),
                    color: _currentPage > 1
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white24 : Colors.black26),
                    onPressed: _currentPage > 1
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(totalPages, (index) {
                    int pageNum = index + 1;
                    bool isCurrent = _currentPage == pageNum;
                    return GestureDetector(
                      onTap: () => setState(() => _currentPage = pageNum),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.transparent,
                          border: Border.all(
                            color: isCurrent
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark
                                      ? const Color(0xFF333333)
                                      : const Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Text(
                          pageNum.toString(),
                          style: GoogleFonts.montserrat(
                            color: isCurrent
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _isArabic
                          ? Icons.arrow_back_ios
                          : Icons.arrow_forward_ios,
                      size: 12,
                    ),
                    color: _currentPage < totalPages
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white24 : Colors.black26),
                    onPressed: _currentPage < totalPages
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark, bool isMobile) {
    return Container(
      color: isDark ? const Color(0xFF111111) : const Color(0xFFF9FAFB),
      width: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 48,
              vertical: isMobile ? 40 : 60,
            ),
            child: Column(
              children: [
                if (isMobile) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'EL DOC',
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PREMIUM SNEAKERS & ATELIER',
                        style: GoogleFonts.montserrat(
                          fontSize: 8.5,
                          letterSpacing: 2,
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _SocialBrandButton(
                            icon: Ionicons.logoWhatsapp,
                            brandColor: const Color(0xFF25D366),
                            tooltip: 'WhatsApp',
                            isDark: isDark,
                            onTap: () =>
                                _openSocialUrl(_storeSettings['whatsapp_url']),
                          ),
                          const SizedBox(width: 12),
                          _SocialBrandButton(
                            icon: Ionicons.logoFacebook,
                            brandColor: const Color(0xFF1877F2),
                            tooltip: 'Facebook',
                            isDark: isDark,
                            onTap: () =>
                                _openSocialUrl(_storeSettings['facebook_url']),
                          ),
                          const SizedBox(width: 12),
                          _SocialBrandButton(
                            icon: Ionicons.logoInstagram,
                            brandColor: const Color(0xFFE4405F),
                            tooltip: 'Instagram',
                            isDark: isDark,
                            onTap: () =>
                                _openSocialUrl(_storeSettings['instagram_url']),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EL DOC',
                            style: GoogleFonts.montserrat(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'PREMIUM SNEAKERS & ATELIER',
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              letterSpacing: 2,
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              _SocialBrandButton(
                                icon: Ionicons.logoWhatsapp,
                                brandColor: const Color(0xFF25D366),
                                tooltip: 'WhatsApp Direct Chat',
                                isDark: isDark,
                                onTap: () => _openSocialUrl(
                                  _storeSettings['whatsapp_url'],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _SocialBrandButton(
                                icon: Ionicons.logoFacebook,
                                brandColor: const Color(0xFF1877F2),
                                tooltip: 'Official Facebook Page',
                                isDark: isDark,
                                onTap: () => _openSocialUrl(
                                  _storeSettings['facebook_url'],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _SocialBrandButton(
                                icon: Ionicons.logoInstagram,
                                brandColor: const Color(0xFFE4405F),
                                tooltip: 'Official Instagram Atelier',
                                isDark: isDark,
                                onTap: () => _openSocialUrl(
                                  _storeSettings['instagram_url'],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _buildFooterCol(_isArabic ? 'المتجر' : 'SHOP', [
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
                              _searchCtrl.clear();
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
                              _searchCtrl.clear();
                              _currentPage = 1;
                              _applyFilters();
                            });
                          },
                        },
                        {
                          'label': _isArabic ? 'وصل حديثاً' : 'New Arrivals',
                          'onTap': () => _changeCategory('NEW ARRIVALS'),
                        },
                      ], isDark),
                      _buildFooterCol(
                        _isArabic ? 'خدمة العملاء' : 'CUSTOMER CARE',
                        [
                          {
                            'label': _isArabic ? 'الشحن والتوصيل' : 'Shipping',
                            'onTap': () => _showPolicyModal(
                              _isArabic
                                  ? 'سياسة الشحن والتوصيل'
                                  : 'SHIPPING POLICY',
                              _isArabic
                                  ? 'نقدم شحن قياسي مجاني لجميع الطلبات التي تتجاوز قيمتها 100 دولار. تستغرق عمليات التوصيل عادةً من 3 إلى 5 أيام عمل داخل المدن الرئيسية.'
                                  : 'Enjoy complimentary standard shipping on all orders exceeding \$100. Deliveries are typically completed within 3-5 business days.',
                            ),
                          },
                          {
                            'label': _isArabic ? 'الإرجاع' : 'Returns',
                            'onTap': () => _showPolicyModal(
                              _isArabic ? 'سياسة الإرجاع' : 'RETURN POLICY',
                              _isArabic
                                  ? 'يسعدنا قبول المرتجعات للأحذية غير المستخدمة وبحالتها الأصلية خلال 14 يوماً من تاريخ الاستلام.'
                                  : 'We gladly accept returns of unworn merchandise in its original condition within 14 days of delivery.',
                            ),
                          },
                          {
                            'label': _isArabic
                                ? 'طرق الدفع'
                                : 'Payment Methods',
                            'onTap': () => _showPolicyModal(
                              _isArabic ? 'طرق الدفع' : 'PAYMENT METHODS',
                              _isArabic
                                  ? 'لضمان راحتكم وثقتكم، نقبل حالياً الدفع نقداً عند الاستلام (COD) فقط.'
                                  : 'To ensure your absolute comfort and trust, we currently accept Cash on Delivery (COD) exclusively.',
                            ),
                          },
                        ],
                        isDark,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 36),
                Divider(
                  color: isDark ? const Color(0xFF262626) : Colors.black12,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '© 2026 EL DOC. ALL RIGHTS RESERVED.',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.black38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminDashboard(),
                        ),
                      ),
                      child: Text(
                        'Portal Login',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black26,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildFooterCol(
    String title,
    List<Map<String, dynamic>> items,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.5,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        ...items.map(
          (item) => _FooterLink(
            text: item['label'],
            onTap: item['onTap'],
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _SocialBrandButton extends StatefulWidget {
  final IconData icon;
  final Color brandColor;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  const _SocialBrandButton({
    required this.icon,
    required this.brandColor,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SocialBrandButton> createState() => _SocialBrandButtonState();
}

class _SocialBrandButtonState extends State<_SocialBrandButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color normalBg = widget.isDark
        ? const Color(0xFF1A1A1A)
        : Colors.white;
    final Color normalBorder = widget.isDark
        ? const Color(0xFF2E2E2E)
        : const Color(0xFFE5E7EB);
    final Color normalIconColor = widget.isDark
        ? Colors.white70
        : Colors.black87;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: _isHovered ? widget.brandColor : normalBg,
              border: Border.all(
                color: _isHovered ? widget.brandColor : normalBorder,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.brandColor.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: 19,
                color: _isHovered ? Colors.white : normalIconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumProductCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isNewBadge;
  final bool isArabic;
  final String priceFormatted;
  final VoidCallback onTap;

  const PremiumProductCard({
    super.key,
    required this.item,
    required this.isNewBadge,
    required this.isArabic,
    required this.priceFormatted,
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
    final firstVariant = (variants != null && variants.isNotEmpty)
        ? variants[0]
        : null;

    String? imgUrl;
    if (firstVariant != null) {
      final dynamic urls = firstVariant['image_urls'];
      if (urls != null && urls is List && urls.isNotEmpty) {
        imgUrl = urls[0].toString();
      } else if (firstVariant['image_url'] != null) {
        imgUrl = firstVariant['image_url'].toString();
      }
    }
    imgUrl ??=
        'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600&q=80';

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
          transform: Matrix4.translationValues(0, _isHovered ? -6 : 0, 0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
            borderRadius: BorderRadius.circular(2),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: isDark ? Colors.white12 : Colors.black12,
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
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
                        color: isDark
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFFF9FAFB),
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
                              child: Icon(
                                Icons.broken_image,
                                color: isDark ? Colors.white24 : Colors.black26,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.isNewBadge)
                      Positioned(
                        top: 8,
                        left: widget.isArabic ? null : 8,
                        right: widget.isArabic ? 8 : null,
                        child: Container(
                          color: isDark ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          child: Text(
                            widget.isArabic ? 'جديد' : 'NEW',
                            style: GoogleFonts.montserrat(
                              color: isDark ? Colors.black : Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: widget.isArabic ? null : 4,
                      left: widget.isArabic ? 4 : null,
                      child: IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isFav
                              ? Colors.redAccent
                              : (isDark ? Colors.white60 : Colors.black45),
                        ),
                        onPressed: () {
                          _wishlist.toggleFavorite(widget.item);
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item['name'] ?? '',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.priceFormatted,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
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

  const _FooterLink({
    required this.text,
    required this.onTap,
    required this.isDark,
  });

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
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: _isHovered
                  ? (widget.isDark ? Colors.white : Colors.black)
                  : (widget.isDark ? Colors.white54 : Colors.black54),
              fontWeight: _isHovered ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(widget.text),
          ),
        ),
      ),
    );
  }
}
