# VisionMate 2.0 — AI Model Integration Guide

This guide details how to integrate, configure, and benchmark on-device machine learning models within VisionMate 2.0.

---

## 1. Overview of Vision Models

| Feature | Primary Model Architecture | Runtime Format | Input Shape | Supported Classes / Outputs | Target Device Latency |
|---|---|---|---|---|---|
| **Currency Detection** | MobileNetV3-Small (Quantized INT8) | `.tflite` | $224 \times 224 \times 3$ | ₹10, ₹20, ₹50, ₹100, ₹200, ₹500 | $\le 85\text{ ms}$ |
| **Object Recognition** | SSD-MobileNet V2 / ML Kit Object | `.tflite` / ML Kit | $300 \times 300 \times 3$ | People, Vehicles, Chairs, Doors, Tables, Plants | $\le 110\text{ ms}$ |
| **OCR Text Reading** | Google ML Kit Text Recognition V2 | Native SDK | Native buffer | Latin, Devanagari (Hindi/Marathi) text blocks | $\le 150\text{ ms}$ |
| **Scene Understanding** | Mobile VLM / MediaPipe VisionGen | ONNX / API | $512 \times 512 \times 3$ | Concise / Detailed descriptive prose | $\le 1200\text{ ms}$ |

---

## 2. Indian Rupee Note Classifier Integration

### Model File Placement
Place the trained TensorFlow Lite model file into the application assets directory:
```
assets/
  models/
    inr_classifier.tflite
    inr_labels.txt
```

### Label Map (`inr_labels.txt`)
```
0 10_rupees
1 20_rupees
2 50_rupees
3 100_rupees
4 200_rupees
5 500_rupees
```

### Preprocessing & Normalization
```dart
// Preprocessing pipeline for 224x224 RGB input
final resized = copyResize(image, width: 224, height: 224);
// Normalize [0, 255] -> [-1.0, 1.0] for quantized float fallback:
final normalized = Float32List(1 * 224 * 224 * 3);
```

### Confidence Thresholding
Per Section 10 requirements:
- Minimum confidence gating is set to **`0.70` (70%)**.
- If output confidence $< 0.70$, report **uncertain note** and request the user lay the note flat under better light.
- **Never claim counterfeit verification**; this model only estimates denomination.

---

## 3. Object Recognition & Relative Spatial Mapping

When an object bounding box $[x_{\min}, y_{\min}, x_{\max}, y_{\max}]$ is returned:
1. Calculate the horizontal center: $x_{\text{center}} = \frac{x_{\min} + x_{\max}}{2}$.
2. Map to spatial descriptors:
   - $x_{\text{center}} < 0.35 \implies \text{"on your left"}$
   - $0.35 \le x_{\text{center}} \le 0.65 \implies \text{"directly ahead"}$
   - $x_{\text{center}} > 0.65 \implies \text{"on your right"}$

---

## 4. Responsible AI & Safety Guardrails

- **Do Not Fabricate Detections**: If an image is dark, blurry, or inference fails, report diagnostic status rather than guessing.
- **Privacy-Preserving Local Inference**: All camera frames processed on-device remain in temporary volatile RAM and are not uploaded without explicit user consent.
- **Cane & Dog Mobility Disclaimer**: Models must never claim collision prevention or traffic clearance.
