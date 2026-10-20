import 'dart:convert';
import 'dart:typed_data';
import '../models.dart';

/// Processor for handling chat attachments (images, screenshots, code, and documents).
/// Extracts file contents, encodes images to base64, and enriches prompts so that
/// models across Smart Routing, Comparison, and Offline Mode can process them.
class AttachmentProcessor {
  /// Known text-based file extensions that can be decoded as text context for LLMs
  static const Set<String> _textExtensions = {
    'txt', 'md', 'json', 'csv', 'tsv', 'xml', 'yaml', 'yml', 'html', 'css',
    'js', 'jsx', 'ts', 'tsx', 'dart', 'py', 'java', 'c', 'cpp', 'h', 'hpp',
    'cs', 'php', 'rb', 'go', 'rs', 'swift', 'kt', 'kts', 'sh', 'bash',
    'sql', 'env', 'ini', 'cfg', 'conf', 'log', 'toml', 'graphql', 'proto',
  };

  /// Constructs a comprehensive prompt incorporating document/code contents
  /// and explicit attachment references for the model.
  static String buildEnrichedPrompt(String prompt, List<ChatAttachment> attachments) {
    if (attachments.isEmpty) return prompt;

    final buffer = StringBuffer();
    final trimmedPrompt = prompt.trim();

    // 1. Process attachments
    int docCount = 0;
    int imgCount = 0;

    for (final a in attachments) {
      if (a.isImage) {
        imgCount++;
        buffer.writeln('[Attached Image $imgCount: "${a.name}" (${a.formattedSize})]');
      } else {
        docCount++;
        final textContent = tryExtractText(a);
        if (textContent != null && textContent.trim().isNotEmpty) {
          final ext = a.extensionLabel.toLowerCase();
          buffer.writeln('\n==================== [Attached Document: "${a.name}"] ====================');
          buffer.writeln('```$ext');
          buffer.writeln(textContent);
          buffer.writeln('```');
          buffer.writeln('==================== [End of "${a.name}"] ====================\n');
        } else {
          buffer.writeln('[Attached File $docCount: "${a.name}" (${a.formattedSize})]');
        }
      }
    }

    // 2. Add user prompt or natural query
    if (trimmedPrompt.isNotEmpty) {
      buffer.writeln('\nUser Prompt:');
      buffer.writeln(trimmedPrompt);
    } else {
      if (imgCount > 0 && docCount > 0) {
        buffer.writeln('\nPlease thoroughly analyze the attached image(s) and document(s), extract any information or data, and provide a comprehensive overview.');
      } else if (imgCount > 0) {
        buffer.writeln('\nPlease thoroughly analyze the attached image(s), describe what you observe in detail, and extract any text, code, or data visible.');
      } else {
        buffer.writeln('\nPlease thoroughly examine the attached document(s)/code, summarize the contents, and highlight any key insights or findings.');
      }
    }

    return buffer.toString().trim();
  }

  /// Attempts to decode file bytes as UTF-8 or ASCII string
  static String? tryExtractText(ChatAttachment attachment) {
    final bytes = attachment.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    final ext = attachment.name.split('.').last.toLowerCase();

    // If extension is known text extension or no binary null bytes
    if (_textExtensions.contains(ext) || !_containsNullBytes(bytes)) {
      try {
        final text = utf8.decode(bytes, allowMalformed: true);
        // Truncate at 120,000 characters (~30k tokens) to avoid context blowup
        if (text.length > 120000) {
          return '${text.substring(0, 120000)}\n\n[... Remaining content truncated for performance ...]';
        }
        return text;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static bool _containsNullBytes(Uint8List bytes) {
    final checkLen = bytes.length > 512 ? 512 : bytes.length;
    for (int i = 0; i < checkLen; i++) {
      if (bytes[i] == 0) return true;
    }
    return false;
  }

  /// Extract base64 image strings from attachments for multimodal model APIs
  static List<String> extractBase64Images(List<ChatAttachment> attachments) {
    final List<String> images = [];
    for (final a in attachments) {
      if (a.isImage && a.bytes != null && a.bytes!.isNotEmpty) {
        images.add(base64Encode(a.bytes!));
      }
    }
    return images;
  }

  /// Build structured payload for backend REST API
  static List<Map<String, dynamic>> buildAttachmentsPayload(List<ChatAttachment> attachments) {
    final List<Map<String, dynamic>> list = [];
    for (final a in attachments) {
      final b64 = a.bytes != null && a.bytes!.isNotEmpty ? base64Encode(a.bytes!) : null;
      list.add({
        'name': a.name,
        'is_image': a.isImage,
        'file_type': a.fileType ?? (a.isImage ? 'image' : 'document'),
        'size': a.sizeInBytes ?? a.bytes?.length ?? 0,
        if (b64 != null) 'base64': b64,
      });
    }
    return list;
  }
}
