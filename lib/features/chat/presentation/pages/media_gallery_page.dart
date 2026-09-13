import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:seyra/core/errors/result.dart';
import 'package:seyra/core/theme/app_colors.dart';
import 'package:seyra/features/chat/domain/entities/social_models.dart';
import 'package:seyra/features/chat/domain/repositories/chat_social_repository.dart';

class MediaGalleryPage extends StatefulWidget {
  const MediaGalleryPage({
    super.key,
    required this.conversationId,
    required this.social,
  });

  final String conversationId;
  final ChatSocialRepository social;

  @override
  State<MediaGalleryPage> createState() => _MediaGalleryPageState();
}

class _MediaGalleryPageState extends State<MediaGalleryPage> {
  var _loading = true;
  String? _error;
  var _items = const <RoomAttachment>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await widget.social.listAttachments(widget.conversationId);
    if (!mounted) {
      return;
    }
    switch (result) {
      case FailureResult(:final failure):
        setState(() {
          _loading = false;
          _error = failure.message;
        });
      case Success(:final value):
        setState(() {
          _loading = false;
          _items = value;
        });
    }
  }

  Future<void> _open(RoomAttachment item) async {
    if (item.e2e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This file is end-to-end encrypted. Open it from the message in the chat to decrypt on this device.',
          ),
        ),
      );
      return;
    }
    final result = await widget.social.downloadAttachment(item.id);
    if (!mounted) {
      return;
    }
    if (result is! Success<List<int>>) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not download file')),
      );
      return;
    }
    if (item.contentType.startsWith('image/')) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            child: Image.memory(Uint8List.fromList(result.value)),
          );
        },
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloaded ${item.filename} (${item.byteSize} bytes)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media')),
      backgroundColor: AppColors.scaffoldOf(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _items.isEmpty
          ? const Center(child: Text('No files in this chat yet'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  leading: Icon(
                    item.e2e
                        ? Icons.lock_outline
                        : item.contentType.startsWith('image/')
                        ? Icons.image_outlined
                        : Icons.insert_drive_file_outlined,
                  ),
                  title: Text(item.e2e ? 'Encrypted file' : item.filename),
                  subtitle: Text(
                    item.e2e
                        ? 'Ciphertext in object storage'
                        : '${item.contentType} · ${item.byteSize} bytes',
                  ),
                  onTap: () => _open(item),
                );
              },
            ),
    );
  }
}
