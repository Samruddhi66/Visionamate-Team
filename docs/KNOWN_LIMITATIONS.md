# VisionMate 2.0 — Known Limitations & Responsible AI Disclaimers

VisionMate 2.0 is an assistive platform engineered to empower visually impaired individuals. In compliance with safety standards and ethical engineering practices, the following boundaries and limitations are explicitly defined.

---

## 1. Safety & Mobility Boundaries

> [!WARNING]
> **VisionMate 2.0 supplements but NEVER replaces a white cane, guide dog, orientation and mobility (O&M) training, or independent physical judgment.**

1. **Road Crossings & Traffic**:
   - The application **cannot** verify when it is safe to cross a road.
   - GPS and camera models cannot guarantee the absence of approaching electric vehicles, bicycles, or quiet motorbikes.
   - Users must always rely on physical auditory cues, accessible pedestrian signals (APS), and cane feedback before stepping into vehicular roadways.

2. **Drop-Offs, Stairs, and Curbs**:
   - Standard single RGB camera sensors cannot accurately compute millimeter-level depth or ground elevation.
   - Do not rely on camera vision to detect descending staircases, open manholes, platform edges, or sudden drop-offs. A white cane must always lead forward motion.

3. **Transparent Glass & Obstacles**:
   - Clean glass walls, automated transparent sliding doors, and mirrors cannot be reliably classified by standard optical models.

---

## 2. Currency Identification Limitations

1. **No Counterfeit Detection**:
   - The currency recognition pipeline identifies note denomination (₹10, ₹20, ₹50, ₹100, ₹200, ₹500) based on optical features of genuine Reserve Bank of India (RBI) banknotes.
   - It **does not** authenticate watermarks, ultraviolet features, or magnetic strips, and cannot guarantee note authenticity.

2. **Damaged, Heavily Soiled, or Folded Notes**:
   - Heavily crumpled, torn, or half-folded notes may return an "uncertain note" status.
   - Users are advised to lay the note flat with adequate overhead lighting.

---

## 3. GPS & Pedestrian Navigation Limitations

1. **Urban Canyons & Indoor Drift**:
   - GPS signal accuracy degrades inside multi-story concrete structures, basements, or between dense high-rise buildings.
   - When GPS accuracy exceeds 20 meters, VisionMate warns that location confidence is low.

2. **Dynamic Obstacles & Roadwork**:
   - Routing services follow mapped pedestrian networks (OSRM / OpenStreetMap). Unmapped temporary construction, scaffolding, or sidewalk closures cannot be forecasted in advance.

---

## 4. Hardware & Offline Operating Constraints

1. **Wake-Word Detection**:
   - VisionMate 2.0 utilizes **Tap-to-Talk** as its primary voice trigger. Continuous background wake-word listening ("Hey VisionMate") requires platform-specific low-power digital signal processor (DSP) hardware and is disabled in background mode to prevent excessive battery drain.

2. **Low-Light Operation**:
   - Both OCR and object recognition accuracy degrade in low-light environments ($< 50\text{ lux}$). The application alerts the user when captured frame luminance is insufficient.
