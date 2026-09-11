import '../models.dart';

class DummyResponseGenerator {
  /// Generates realistic, rich Claude-style AI responses for uploaded projects, screenshots, and text prompts.
  static String generate({
    required String prompt,
    List<ChatAttachment>? attachments,
    String? modelName,
    String? modeName,
  }) {
    final model = modelName ?? 'Claude 3.5 Sonnet';
    final cleanPrompt = prompt.trim();
    final lowerPrompt = cleanPrompt.toLowerCase();

    // ─── Case 1: Attachments (Project Codebase or Screenshot/Images) ───
    if (attachments != null && attachments.isNotEmpty) {
      final projectFiles = attachments.where((a) => !a.isImage || a.fileType == 'project').toList();
      final screenshots = attachments.where((a) => a.isImage || a.fileType == 'screenshot' || a.fileType == 'camera').toList();

      if (projectFiles.isNotEmpty) {
        final firstFile = projectFiles.first;
        final name = firstFile.name;
        final size = firstFile.formattedSize;
        final ext = firstFile.extensionLabel;
        final isDart = ext == 'DART';
        final isPython = ext == 'PY';
        final isJs = ext == 'JS' || ext == 'TS';

        final codeSnippet = isDart
            ? '''```dart
// Optimized implementation for $name
import 'package:flutter/material.dart';

class DataStreamManager {
  Future<void> processDataStream() async {
    try {
      final result = await fetchValidatedPayload();
      debugPrint('Payload processed successfully: \$result');
    } catch (e) {
      debugPrint('Error executing stream: \$e');
    }
  }

  Future<Map<String, dynamic>> fetchValidatedPayload() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {'status': 'success', 'timestamp': DateTime.now().toIso8601String()};
  }
}
```'''
            : isPython
                ? '''```python
# Optimized implementation for $name
import asyncio

async def process_data_stream():
    """Asynchronously processes incoming file payload with error handling."""
    try:
        result = await fetch_validated_payload()
        print(f"Payload processed successfully: {result}")
        return result
    except Exception as exc:
        print(f"Error executing stream: {exc}")
        raise

async def fetch_validated_payload():
    await asyncio.sleep(0.3)
    return {"status": "success", "file": "$name"}
```'''
                : '''```javascript
// Optimized implementation for $name
async function processDataStream() {
  try {
    const response = await fetchValidatedPayload();
    console.log(`[Stream] Processed successfully for $name:`, response);
    return response;
  } catch (error) {
    console.error(`[Stream] Execution failure:`, error);
    throw error;
  }
}
```''';

        return '''📁 **Project & Codebase Analysis Report**
*Analyzed by $model • File: `$name` ($size • $ext)*

${cleanPrompt.isNotEmpty ? '> **User Request:** "$cleanPrompt"\n' : ''}
### 📊 Code Structure & Architecture Overview
- **Analyzed Source:** `$name` (${projectFiles.length} file${projectFiles.length > 1 ? 's' : ''} in context)
- **Detected Language/Framework:** ${isDart ? 'Dart / Flutter Framework' : isPython ? 'Python 3.x' : isJs ? 'Node.js / TypeScript' : '$ext Architecture'}
- **Component Breakdown:** Modular UI layers, reactive state hooks, async pipelines, type-safe models.
- **Code Health Score:** 98/100 (Clean separation of concerns, strong type validation).

### 🔍 Key Findings & Architectural Review
1. **Separation of Concerns:** Component dependencies are well-isolated with clear input/output contracts.
2. **State Management:** Reactive update listeners are properly disposed, preventing memory leaks.
3. **Async Handling:** Futures and Streams implement proper error boundaries and timeout policies.

### ⚡ Recommended Refactored Snippet
$codeSnippet

### 📋 Actionable Next Steps
- Consider adding automated unit tests for edge case coverage.
- Cache repetitive network and disk I/O calls where applicable.
- All structural and security sanity checks for `$name` passed successfully.''';
      }

      if (screenshots.isNotEmpty) {
        final firstImg = screenshots.first;
        final name = firstImg.name;
        final size = firstImg.formattedSize;

        return '''📸 **Screenshot & Vision Analysis Report**
*Analyzed by $model • Target: `$name` ($size)*

${cleanPrompt.isNotEmpty ? '> **User Request:** "$cleanPrompt"\n' : ''}
### 🎨 Visual Layout & Interface Breakdown
- **Target Surface:** Application User Interface / Dashboard
- **Identified Color Palette:**
  - Primary Accent: `#DA7756` (Claude Terracotta) / `#8B5CF6` (Vibrant Violet)
  - Dark Surface Background: `#18181B` (Zinc Charcoal)
  - Elevated Cards: `#27272A` with subtle glassmorphism borders
- **Typography & Scale:** Clear heading hierarchy with WCAG AA compliant contrast ratio (6.1:1).

### 💡 UX & Component Insights
1. **Layout Hierarchy:** Balanced visual weight with well-defined content containers and breathing room.
2. **Interactive Elements:** Action buttons have clear visual affordances and distinct active states.
3. **Responsiveness:** Fluid grid layout adapts gracefully across desktop, tablet, and mobile viewports.

### 🛠️ Generated Component Snippet
```dart
// Auto-generated UI structure corresponding to $name
Widget buildClaudeCard(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(16.0),
    decoration: BoxDecoration(
      color: const Color(0xFF232220),
      borderRadius: BorderRadius.circular(14.0),
      border: Border.all(color: const Color(0xFFDA7756).withOpacity(0.3)),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Visual Layout Verified',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        SizedBox(height: 6),
        Text(
          'Detected layout elements match design guidelines perfectly.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );
}
```

✅ **Summary:** Visual analysis complete. The layout is clean, modern, and production-ready.''';
      }
    }

    // ─── Case 2: Urdu / Roman Urdu Prompts ───
    if (lowerPrompt.contains('kese ho') ||
        lowerPrompt.contains('kaise ho') ||
        lowerPrompt.contains('kya haal') ||
        lowerPrompt.contains('salam') ||
        lowerPrompt.contains('assalam') ||
        lowerPrompt.contains('btao') ||
        lowerPrompt.contains('sahi kro') ||
        lowerPrompt.contains('urdu')) {
      return '''Assalam-o-Alaikum! Main **$model** hoon, aapka neutral AI assistant.

Aapka prompt: **"$cleanPrompt"**

### 💡 Main aapki kis tarah madad kar sakta hoon:
- **Code & Projects:** Kisi bhi programming language ka code likhna, debug karna, ya review karna.
- **Files & Projects Upload:** Aap koi bhi zip, dart, python, ya text file upload kar ke analysis karwa sakte hain.
- **Screenshots & Vision:** UI design ya application screenshots ka detailed visual review.
- **Smart Routing & Comparison:** Multiple AI models (Claude, GPT-4o, Gemini) ke darmiyan responses compare karna.

Aap apna sawal ya project attach karein, main fauran tafseel se answer doonga!''';
    }

    // ─── Case 3: Coding Prompts ───
    if (lowerPrompt.contains('python') ||
        lowerPrompt.contains('code') ||
        lowerPrompt.contains('function') ||
        lowerPrompt.contains('sort') ||
        lowerPrompt.contains('dart') ||
        lowerPrompt.contains('flutter') ||
        lowerPrompt.contains('javascript')) {
      final isFlutter = lowerPrompt.contains('flutter') || lowerPrompt.contains('dart');

      if (isFlutter) {
        return '''💻 **Flutter / Dart Implementation**
*Generated by $model*

Here is the clean, efficient solution for your request:

```dart
/// Processes and sorts unique elements while preserving performance.
List<T> processAndSort<T extends Comparable<T>>(List<T> items) {
  if (items.isEmpty) return [];
  
  // Remove duplicates via Set and sort in O(N log N)
  final uniqueList = items.toSet().toList();
  uniqueList.sort();
  return uniqueList;
}

// Example usage:
void main() {
  final numbers = [42, 12, 88, 12, 7, 88, 3];
  final sorted = processAndSort(numbers);
  print('Sorted unique items: \$sorted');
}
```

### 📌 Implementation Highlights
- **Generics (`<T>`):** Supports integers, strings, dates, or custom objects implementing `Comparable`.
- **Deduplication:** Uses a `Set` for `O(N)` average duplicate filtering.
- **Clean Architecture:** Pure function with no side effects or hidden dependencies.''';
      }

      return '''💻 **Python Code Implementation**
*Generated by $model*

Here is an optimal and clean implementation:

```python
def process_data(items: list) -> list:
    """
    Deduplicates and returns a sorted list of comparable elements.
    Time Complexity: O(N log N)
    Space Complexity: O(N)
    """
    if not items:
        return []
    return sorted(list(set(items)))

# Example Demonstration
if __name__ == "__main__":
    sample_data = [42, 17, 88, 17, 5, 88, 23]
    result = process_data(sample_data)
    print(f"Processed Result: {result}")
    # Output: [5, 17, 23, 42, 88]
```

### 📌 Key Features
- **Efficiency:** Utilizes Python's native Timsort (`O(N log N)`).
- **Robustness:** Handles empty inputs and duplicate values cleanly.
- **Type Hints:** Fully annotated for modern IDE autocomplete and static type checkers.''';
    }

    // ─── Case 4: Math Equations ───
    if (lowerPrompt.contains('solve') || lowerPrompt.contains('2x²') || lowerPrompt.contains('equation') || lowerPrompt.contains('math')) {
      return '''📐 **Mathematical Solution & Derivation**
*Solved by $model*

Let's solve the quadratic equation:
> **2x² + 5x - 3 = 0**

### 1. Identify Coefficients
For the standard form `ax² + bx + c = 0`:
- **a = 2**
- **b = 5**
- **c = -3**

### 2. Quadratic Formula
`x = (-b ± √(b² - 4ac)) / (2a)`

Calculate discriminant `Δ`:
- `b² - 4ac = (5)² - 4(2)(-3)`
- `Δ = 25 - (-24) = 49`
- `√Δ = √49 = 7`

### 3. Compute Roots
- **x₁ = (-5 + 7) / (2 × 2) = 2 / 4 = 1/2 (0.5)**
- **x₂ = (-5 - 7) / (2 × 2) = -12 / 4 = -3**

### ✅ Final Result
The roots of the equation are:
- **`x = 1/2`**
- **`x = -3`**''';
    }

    // ─── Case 5: Science / Explanations / Quantum ───
    if (lowerPrompt.contains('explain') || lowerPrompt.contains('quantum') || lowerPrompt.contains('entanglement') || lowerPrompt.contains('how')) {
      return '''🧠 **Conceptual Explanation**
*Generated by $model*

### 🌌 Quantum Entanglement Overview
**Quantum entanglement** is a phenomenon where two or more particles become intimately connected such that the quantum state of each particle cannot be described independently of the state of the others, regardless of the distance separating them.

### 🔑 Core Principles
1. **Superposition:** Before measurement, particles exist in a linear combination of all possible states simultaneously.
2. **Instant Correlation:** Measuring the spin or polarization of particle A immediately collapses and dictates the measured state of entangled particle B.
3. **Non-Locality:** Albert Einstein famously referred to this as *"spooky action at a distance"* (*spukhafte Fernwirkung*).

### 🚀 Real-World Applications
- **Quantum Cryptography:** Quantum Key Distribution (QKD) creates theoretically unbreakable encryption keys.
- **Quantum Computing:** Qubits leverage entanglement to evaluate exponential computational spaces in parallel.
- **Quantum Teleportation:** Secure quantum state transfer across optical fiber and satellite networks.''';
    }

    // ─── Case 6: Creative / Poetry ───
    if (lowerPrompt.contains('poem') || lowerPrompt.contains('poetry') || lowerPrompt.contains('sea') || lowerPrompt.contains('write')) {
      return '''🌊 **Whispers of the Cobalt Sea**
*Crafted by $model*

The silver tides breathe upon the sand,  
A timeless rhythm sculpted by no hand.  
Beneath the crests of rolling foam and blue,  
Ancient currents whisper secrets new.  

Through sunlit shallows and the silent deep,  
Where sunbeams fade and quiet shadows sleep,  
The endless ocean carries memory's crest,  
A cradle of eternity, at rest.''';
    }

    // ─── Case 7: General Default Response ───
    return '''🤖 **Response from $model**

Thank you for your prompt: **"$cleanPrompt"**

### 💡 Analysis & Insights
- **Context Processing:** Your query has been successfully routed and evaluated.
- **Execution Plan:** Synthesized key concepts and structured the outcome for immediate application.
- **Model Confidence:** High confidence output generated across neural routing layers.

### 📌 Summary
Everything is properly configured and operational. You can continue our conversation, ask follow-up questions, or attach project code files and screenshots anytime!''';
  }
}
