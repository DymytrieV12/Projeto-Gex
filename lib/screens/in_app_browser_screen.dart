import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Navegador interno para exibir a p\u00e1gina de pagamento diretamente no app.
/// Ao abrir o link do boleto/PIX, o cliente v\u00ea QR Code e c\u00f3digo copia e cola
/// j\u00e1 organizados pelo pr\u00f3prio backend, sem sair do aplicativo.
class InAppBrowserScreen extends StatefulWidget {
  final String url;
  final String title;

  const InAppBrowserScreen({
    super.key,
    required this.url,
    this.title = 'Pagamento',
  });

  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (!mounted) return;
            setState(() {
              _progress = value / 100;
              _loading = value < 100;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _progress = 1;
            });
          },
          onWebResourceError: (err) {
            if (!mounted) return;
            setState(() {
              _hasError = true;
              _loading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiado')),
    );
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Copiar link',
            onPressed: _copyLink,
            icon: const Icon(Icons.copy_rounded),
          ),
          IconButton(
            tooltip: 'Abrir no navegador',
            onPressed: _openExternal,
            icon: const Icon(Icons.open_in_browser_rounded),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () {
              setState(() => _hasError = false);
              _controller.reload();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading)
            LinearProgressIndicator(
              value: _progress > 0 && _progress < 1 ? _progress : null,
              minHeight: 3,
            ),
          Expanded(
            child: _hasError
                ? _errorView()
                : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 12),
            const Text(
              'N\u00e3o foi poss\u00edvel carregar a p\u00e1gina de pagamento.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text('Abrir no navegador'),
            ),
          ],
        ),
      ),
    );
  }
}
