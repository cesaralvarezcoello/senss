import 'package:flutter/material.dart';

import '../../data/media/media_store.dart';

/// Muestra una foto a partir de su referencia opaca ([mediaRef]), resolviendo
/// el backend activo (archivo local, navegador…). Cachea el proveedor para no
/// releer los bytes en cada reconstrucción.
class RefImage extends StatefulWidget {
  final String mediaRef;
  final BoxFit fit;
  const RefImage(this.mediaRef, {super.key, this.fit = BoxFit.cover});

  @override
  State<RefImage> createState() => _RefImageState();
}

class _RefImageState extends State<RefImage> {
  late Future<ImageProvider> _future;

  @override
  void initState() {
    super.initState();
    _future = Media.store.imageProvider(widget.mediaRef);
  }

  @override
  void didUpdateWidget(RefImage old) {
    super.didUpdateWidget(old);
    if (old.mediaRef != widget.mediaRef) {
      _future = Media.store.imageProvider(widget.mediaRef);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasData) {
          return Image(
            image: snap.data!,
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: Color(0xFF2C2622)),
          );
        }
        return const ColoredBox(color: Color(0xFF2C2622));
      },
    );
  }
}
