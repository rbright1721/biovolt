# BioVolt — Personal Bioelectric Dashboard

## Project Overview
A Flutter app that connects via Bluetooth to a DIY ESP32 biofeedback device with 4 sensors (GSR, MAX30102 PPG, DS18B20 temperature, AD8232 ECG). Displays real-time biometric signals, session tracking, and long-term trend analysis for a personal health optimization protocol (intermittent fasting, cold exposure, breathwork, grounding, meditation).

## Tech Stack
- **Framework:** Flutter (Dart)
- **State Management:** BLoC (flutter_bloc)
- **Bluetooth:** flutter_blue_plus (BLE) or flutter_bluetooth_serial (Classic SPP)
- **Charts:** fl_chart (real-time waveforms and trend charts)
- **Local Storage:** Hive or sqflite (session data before Firebase)
- **Firebase:** Added later for cloud sync and historical trends
- **Target Platform:** Android (primary), iOS (future)

## Design Direction
**Aesthetic:** Dark, clinical biometric dashboard — think medical-grade instrument panel meets cyberpunk. Not playful, not corporate. Precise, data-dense, and alive with real-time signal animation.

**Color System:**
- Background: Deep near-black (#0A0E17)
- Surface cards: Dark blue-gray (#111827)
- Primary accent: Electric teal (#00F0B5) — for active signals, healthy readings
- Secondary accent: Warm amber (#F59E0B) — for warnings, attention states
- Alert: Coral red (#EF4444) — for out-of-range values
- Text primary: White (#F9FAFB)
- Text secondary: Muted blue-gray (#6B7280)
- Signal lines: Teal for PPG/ECG, Amber for GSR, Coral for temperature

**Typography:**
- Headers: Bold, monospace-inspired (JetBrains Mono or similar)
- Data values: Large, tabular-aligned numbers
- Labels: Small caps, muted

**Key Design Principles:**
- Real-time data should feel ALIVE — subtle pulse animations on heart rate, flowing waveforms
- Glass morphism card surfaces with subtle border glow matching signal color
- Minimal chrome — data is the interface
- Status indicators use color, not icons
- Dark theme ONLY — this is a lab instrument, not a consumer app

## Architecture

### Directory Structure
```
lib/
├── main.dart
├── app.dart
├── config/
│   ├── theme.dart              # Dark theme, colors, typography
│   ├── constants.dart          # Signal ranges, BLE UUIDs, timing
│   └── routes.dart
├── models/
│   ├── sensor_reading.dart     # Timestamped sensor value
│   ├── session.dart            # Biofeedback session (type, start, end, data)
│   ├── vital_signs.dart        # Processed vitals (HR, HRV, SpO2, temp, GSR)
│   └── device_state.dart       # BLE connection state
├── services/
│   ├── bluetooth_service.dart  # BLE connection, data stream
│   ├── mock_data_service.dart  # Fake sensor data for UI development
│   ├── signal_processor.dart   # Raw ADC → meaningful values
│   ├── hrv_calculator.dart     # R-R intervals → RMSSD, SDNN, LF/HF
│   └── session_storage.dart    # Local persistence
├── bloc/
│   ├── device/
│   │   ├── device_bloc.dart
│   │   ├── device_event.dart
│   │   └── device_state.dart
│   ├── sensors/
│   │   ├── sensors_bloc.dart
│   │   ├── sensors_event.dart
│   │   └── sensors_state.dart
│   └── session/
│       ├── session_bloc.dart
│       ├── session_event.dart
│       └── session_state.dart
├── widgets/
│   ├── live_waveform.dart      # Scrolling ECG/PPG waveform (CustomPainter)
│   ├── signal_card.dart        # Individual sensor metric card
│   ├── radial_gauge.dart       # Circular gauge for SpO2, coherence
│   ├── hrv_spectrum.dart       # LF/HF frequency visualization
│   ├── session_timer.dart      # Active session countdown/stopwatch
│   ├── connection_indicator.dart
│   └── trend_chart.dart        # Historical line chart
├── screens/
│   ├── dashboard_screen.dart   # Main live view — 4 signal cards + waveform
│   ├── session_screen.dart     # Active session with timer and live data
│   ├── trends_screen.dart      # Weekly/monthly charts
│   ├── settings_screen.dart    # BLE pairing, calibration, preferences
│   └── session_history_screen.dart
└── utils/
    ├── filters.dart            # Moving average, bandpass for signal cleanup
    ├── extensions.dart
    └── formatters.dart
```

### Data Flow
```
ESP32 (BLE) → bluetooth_service → raw Stream<List<int>>
  → signal_processor (ADC conversion, filtering)
    → sensors_bloc (state updates at 10-50Hz depending on signal)
      → dashboard_screen (real-time UI)
      → session_bloc (if recording → session_storage)
```

### Mock Data Service (Build First)
Generate realistic fake data so the UI can be built and tested before hardware arrives:
- GSR: Slow sine wave 200-800 with random noise, occasional spikes
- Heart rate: 60-80 BPM with slight variability
- PPG waveform: Synthetic photoplethysmogram wave shape at ~75 BPM
- ECG waveform: Synthetic PQRST complex at ~75 BPM
- Temperature: 96.5-98.2°F with slow drift
- SpO2: 96-99% with minor fluctuation
- HRV (RMSSD): 30-65ms range

## Screen Specifications

### 1. Dashboard Screen (Main View)
The primary screen. Always-on display of all signals.

**Layout (top to bottom):**
- **Top bar:** Device connection status (dot indicator), battery %, app name "BioVolt"
- **Waveform strip:** Full-width scrolling ECG or PPG waveform (toggle between them). ~200px height. Green/teal line on dark background with subtle grid.
- **Vital cards grid (2x2):**
  - Heart Rate: Large BPM number, mini trend sparkline, pulse animation
  - HRV (RMSSD): Current value in ms, status color (green=good, amber=moderate, red=low)
  - GSR: Skin conductance value, stress level indicator (Calm/Alert/Stressed)
  - Temperature: °F value, trend arrow (↑↓→)
- **Secondary metrics row:**
  - SpO2 percentage with radial gauge
  - LF/HF ratio with small bar
  - Coherence score
- **Quick session button:** Floating action button → start session (breathwork, cold, meditation, fasting check)

### 2. Session Screen
Active biofeedback session with focus on one or two key metrics.

**Session types:**
- Breathwork (focus: HRV + GSR)
- Cold Exposure (focus: Temperature + HRV)
- Meditation (focus: GSR + coherence)
- Fasting Check (snapshot: all metrics comparison to baseline)
- Grounding (focus: GSR + temperature before/after)

**Layout:**
- Session type + timer at top
- Large focused waveform for primary signal
- Key metric cards for that session type
- Start/pause/stop controls
- Real-time guidance (e.g., box breathing pacer for breathwork)

### 3. Trends Screen
Historical data visualization.

**Charts:**
- HRV trend (daily average RMSSD over weeks)
- Resting heart rate trend
- GSR baseline trend
- Temperature patterns
- Session history timeline
- Supplement/intervention log overlay (mark when GlyNAC started, etc.)

### 4. Settings Screen
- Bluetooth device scanner and connection
- Sensor calibration offsets
- Alert thresholds
- Data export (CSV)
- About/device info

## Signal Processing Notes

### GSR (Grove Sensor → ESP32 ADC)
- Raw: 0-4095 (12-bit ADC)
- Convert to conductance: V = raw * 3.3/4095, R = (4095-raw) * 10k/raw, conductance = 1/R µS
- Apply 1-second moving average to smooth
- Phasic component: high-pass filter (>0.05Hz) for event responses
- Tonic component: low-pass filter (<0.05Hz) for baseline level

### MAX30102 (PPG → Heart Rate → HRV)
- Red + IR channels at 100Hz sampling
- Band-pass filter 0.5-5Hz for pulse waveform
- Peak detection on filtered signal → R-R intervals
- HR = 60000 / mean(R-R intervals) BPM
- RMSSD = sqrt(mean(diff(R-R)²))
- SDNN = std(R-R intervals)
- SpO2 = ratio of ratios (R/IR AC/DC components)

### AD8232 (ECG)
- Single-lead ECG at 250-500Hz
- The AD8232 has onboard filtering (0.5-40Hz bandpass)
- QRS detection (Pan-Tompkins algorithm or simpler threshold)
- R-R intervals from QRS peaks → gold standard HRV
- Display raw waveform scrolling left-to-right

### DS18B20 (Temperature)
- Digital sensor, 12-bit resolution (0.0625°C)
- OneWire protocol → ESP32 reads directly
- Sample every 1-5 seconds (slow-changing signal)
- Display in °F with one decimal

## BLE Protocol (ESP32 → App)
Use a custom BLE service with one characteristic per signal or a packed data format.

**Option A — Packed binary (recommended for bandwidth):**
Single characteristic, notify at 50Hz:
```
Byte 0-1: GSR raw (uint16)
Byte 2-3: PPG red (uint16)
Byte 4-5: PPG IR (uint16)
Byte 6-7: ECG raw (uint16)
Byte 8-9: Temperature * 100 (int16, e.g., 9762 = 97.62°F)
Byte 10: Packet counter (uint8)
```

**BLE Service UUID:** Custom 128-bit (generate one)
**Characteristic UUID:** Custom 128-bit (generate one)

## Build Order

### Phase 1 — UI with Mock Data (BEFORE hardware arrives)
1. Create Flutter project, add dependencies
2. Build theme (dark, colors, typography)
3. Build mock_data_service generating all fake signals
4. Build live_waveform widget (CustomPainter, scrolling line)
5. Build signal_card widget
6. Build dashboard_screen assembling everything
7. Wire up BLoC for sensor data flow
8. Test: app runs showing animated fake biometric data

### Phase 2 — Session System
1. Build session types and session screen
2. Add breathing pacer widget (animated circle for box breathing)
3. Add session timer and start/stop logic
4. Local session storage (Hive)
5. Session history screen

### Phase 3 — Hardware Integration (when ESP32 arrives)
1. Write ESP32 Arduino firmware (sensor reading + BLE broadcast)
2. Replace mock_data_service with bluetooth_service
3. Calibrate signal processing for real sensor values
4. Test with actual body signals

### Phase 4 — Trends and Analysis
1. Build trend charts from stored session data
2. Add supplement/intervention logging
3. Weekly summary views
4. Firebase integration for cloud backup

### Phase 5 — Mobile Packaging
1. Optimize for battery (reduce BLE polling when idle)
2. Background service for long sessions
3. Notification when session targets are hit
