import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../screens/in_app_browser_screen.dart';
import '../services/api_service.dart';

Future<void> showPagamentoSheet(
  BuildContext context,
  Pedido pedido, {
  String? fallbackNumero,
}) async {
  final numero = pedido.numeroPedido?.trim().isNotEmpty == true
      ? pedido.numeroPedido!
      : (fallbackNumero?.trim().isNotEmpty == true ? fallbackNumero! : pedido.id);
  final linkPrincipal = await _resolvePreferredLink(pedido);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).padding.bottom;
      final qrBytes = _decodeImageBytes(pedido.imagemQrCodePix);
      final pixCode = pedido.qrCodePix?.trim();
      final boletoCode = pedido.codigoBarrasBoleto?.trim();
      final boletoPdf = pedido.pdfBoleto?.trim();

      return SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          padding: EdgeInsets.fromLTRB(18, 14, 18, bottom + 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pagamento do pedido',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pedido #$numero',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                if (linkPrincipal != null) ...[
                  _linkCard(linkPrincipal),
                  const SizedBox(height: 10),
                  _actionButton(
                    icon: Icons.open_in_new_rounded,
                    label: 'Abrir pagamento no app',
                    color: const Color(0xFF0E5A35),
                    onPressed: () => openPagamentoNoApp(ctx, linkPrincipal),
                  ),
                  const SizedBox(height: 10),
                  _actionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copiar link',
                    color: const Color(0xFF1B6B43),
                    onPressed: () =>
                        _copyText(ctx, linkPrincipal, 'Link copiado'),
                  ),
                  const SizedBox(height: 18),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF6FFF9), Color(0xFFE8F5EC)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF0E5A35).withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (qrBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.memory(
                            qrBytes,
                            width: 220,
                            height: 220,
                            fit: BoxFit.contain,
                          ),
                        )
                      else if (_isHttpUrl(pedido.imagemQrCodePix))
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            pedido.imagemQrCodePix!,
                            width: 220,
                            height: 220,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _qrFallback(),
                          ),
                        )
                      else
                        _qrFallback(),
                      const SizedBox(height: 14),
                      const Text(
                        'QR Code para pagamento',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Color(0xFF0E5A35),
                        ),
                      ),
                      if ((pixCode ?? '').isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            linkPrincipal != null
                                ? 'Toque em "Abrir pagamento no app" para visualizar QR Code e c\u00f3digo copia e cola direto da p\u00e1gina oficial.'
                                : 'O c\u00f3digo PIX ainda n\u00e3o foi retornado pela API. Use os bot\u00f5es abaixo para acessar o boleto.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if ((pixCode ?? '').isNotEmpty) ...[
                  _codeBox(title: 'C\u00f3digo copia e cola', value: pixCode!),
                  const SizedBox(height: 10),
                  _actionButton(
                    icon: Icons.copy_all_rounded,
                    label: 'Copiar c\u00f3digo',
                    color: const Color(0xFF0E5A35),
                    onPressed: () =>
                        _copyText(ctx, pixCode, 'C\u00f3digo PIX copiado'),
                  ),
                  const SizedBox(height: 12),
                ],
                _actionButton(
                  icon: Icons.qr_code_2_rounded,
                  label: 'Copiar c\u00f3digo de barras do boleto',
                  color: const Color(0xFF1B6B43),
                  onPressed: (boletoCode ?? '').isEmpty
                      ? null
                      : () => _copyText(
                            ctx,
                            boletoCode!,
                            'C\u00f3digo de barras do boleto copiado',
                          ),
                ),
                const SizedBox(height: 12),
                _actionButton(
                  icon: Icons.download_rounded,
                  label: 'Baixar boleto',
                  color: const Color(0xFF0C4D2C),
                  onPressed: (boletoPdf ?? '').isEmpty
                      ? null
                      : () => _openUrlExternal(ctx, boletoPdf!),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> openPagamentoNoApp(BuildContext context, String url) async {
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => InAppBrowserScreen(url: url, title: 'Pagamento do pedido'),
    ),
  );
}

Future<String?> _resolvePreferredLink(Pedido pedido) async {
  final directValues = [pedido.paginaPix, pedido.linkPagamento];
  for (final value in directValues) {
    final text = value?.trim();
    if (text != null && text.isNotEmpty && _isHttpUrl(text)) return text;
  }

  final boletoPdf = pedido.pdfBoleto?.trim();
  if (boletoPdf != null && boletoPdf.isNotEmpty && _isHttpUrl(boletoPdf)) {
    final resolved = await ApiService.resolveBoletoPaymentLink(boletoPdf);
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return boletoPdf;
  }
  return null;
}

Widget _linkCard(String link) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0E5A35), Color(0xFF1B6B43)],
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0E5A35).withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.link_rounded, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text(
              'Link de pagamento',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(
          link,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            height: 1.4,
            fontFamily: 'monospace',
          ),
        ),
      ],
    ),
  );
}

Widget _qrFallback() {
  return Container(
    width: 220,
    height: 220,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.qr_code_2_rounded, size: 74, color: Color(0xFF0E5A35)),
        SizedBox(height: 8),
        Text(
          'QR Code indispon\u00edvel',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

Widget _codeBox({required String title, required String value}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAF8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF0E5A35).withValues(alpha: 0.10)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0E5A35),
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 13,
            height: 1.45,
            fontFamily: 'monospace',
            color: Colors.black87,
          ),
        ),
      ],
    ),
  );
}

Widget _actionButton({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback? onPressed,
}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        disabledForegroundColor: Colors.grey.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

Future<void> _copyText(BuildContext context, String value, String message) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Future<void> _openUrlExternal(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('N\u00e3o foi poss\u00edvel abrir o link.')),
    );
  }
}

Uint8List? _decodeImageBytes(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final text = value.trim();
  if (_isHttpUrl(text)) return null;
  try {
    final base64Part = text.contains(',') ? text.split(',').last : text;
    return base64Decode(base64Part);
  } catch (_) {
    return null;
  }
}

bool _isHttpUrl(String? value) {
  if (value == null) return false;
  return value.startsWith('http://') || value.startsWith('https://');
}
