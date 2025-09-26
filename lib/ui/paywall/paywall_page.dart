import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../services/iap_service.dart';
import '../../widgets/boutons/bouton_universel.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await IapService.instance.init();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final products = IapService.instance.products;
    final isAvail = IapService.instance.isAvailable;
    final err = IapService.instance.lastQueryError;
    final p1 = IapService.instance.pickVariantFirstNotOwned(IapService.sku1M);
    final p6 = IapService.instance.pickVariantFirstNotOwned(IapService.sku6M);
    final p12 = IapService.instance.pickVariantFirstNotOwned(IapService.sku12M);

    return Scaffold(
      appBar: AppBar(title: const Text('Abonnement Premium')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (!isAvail)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Billing non disponible (isAvailable=false). Installe depuis le track tests internes avec un compte testeur).'),
                    ),
                  if (err != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: const Color(0xFFFFE2E2), borderRadius: BorderRadius.circular(8)),
                      child: Text('queryProductDetails error: ${err.message} (${err.code})'),
                    ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: const Color(0xFFE7F3FF), borderRadius: BorderRadius.circular(8)),
                    child: Text('Produits: ${products.length} → ${products.map((e) => e.id).join(', ')}'),
                  ),
                  _OfferTile(title: '1 mois', product: p1),
                  const SizedBox(height: 12),
                  _OfferTile(title: '6 mois', product: p6),
                  const SizedBox(height: 12),
                  _OfferTile(title: '12 mois', product: p12),
                  const Spacer(),
                  Text('Produits chargés: ${products.length}')
                ],
              ),
            ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  final String title;
  final ProductDetails? product;
  const _OfferTile({required this.title, required this.product});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: BoutonUniversel(
        onPressed: product == null ? null : () => IapService.instance.buy(product!),
        size: BoutonUniverselTaille.small,
        borderRadius: 10,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 18)),
            Text(product?.price ?? 'Indisponible'),
          ],
        ),
      ),
    );
  }
}


