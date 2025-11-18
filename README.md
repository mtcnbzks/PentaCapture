# PentaCapture

**Smile Hair Clinic Hackathon 2025 - Mobil Uygulama Kategorisi**

PentaCapture, saç/kafa derisi bölgelerinin 5 kritik açıdan tutarlı ve profesyonel bir şekilde fotoğraflanmasını sağlayan akıllı bir self-capture iOS uygulamasıdır. Uygulama, ARKit yüz takibi, CoreMotion sensörleri ve gelişmiş validasyon algoritmaları kullanarak kullanıcıya rehberlik eder ve doğru pozisyon yakalandığında otomatik olarak fotoğraf çeker.

> ⚠️ **GEREKSINIM**: Bu uygulama **iOS 17.6+** ve **ARKit Face Tracking**'e tamamen bağımlıdır. **iPhone XR veya daha yeni cihaz gereklidir**. Daha eski iOS sürümleri veya cihazlar desteklenmez.

## 📱 Temel Özellikler

- **5 Açıdan Otomatik Çekim**: Ön yüz, sağ/sol profil (45°), tepe (vertex) ve arka donör bölgesi
- **Akıllı Kılavuz**: Real-time validasyon, ProximityIndicator, ses/haptic feedback, Vertex/Donor için video talimatlar
- **Otomatik Deklanşör**: 0.5s stabilite kontrolü, 2-1 / 3-2-1 countdown, hareket algılandığında iptal
- **Session Management**: Auto-save, kaldığın yerden devam, attempts/timeSpent/validationScores takibi
- **ML-Ready Export**: Validation scores + device pose + session analytics içeren JSON çıktı

## 🏗️ Teknik Mimari

PentaCapture, **MVVM + servis katmanı + SwiftUI** yazılım mimarisi üzerinde kuruludur. Her bileşen tek bir sorumluluğa odaklanır ve Combine/async-await ile birbirine bağlanır.

### Katmanlar & Akış

1. **ViewModels/**

   - `CaptureViewModel`: Oturum state'ini (`CaptureSession`), güncel validasyonu (`PoseValidation`), countdown akışını ve UI flag'lerini yönetir.
   - Servisleri dependency injection ile alır ve yaşam döngülerini yönetir (`startSession`, `pause`, `resume`, `end`).
   - `performValidation()` metodunda ARKit + CoreMotion verilerini her 67 ms'de bir birleştirir, Combine ile UI'ı günceller, uygun durumda `triggerAutoCapture()` çağırır.

2. **Services/**

   - `FaceTrackingService` (ARKit): TrueDepth camera + `ARSession` yönetir, `currentHeadPose`, tracking state, high-res AR frame üretir.
   - `MotionService` (CoreMotion): `CMMotionManager` ile pitch/roll/yaw, gravity, tilt hesaplar; vertex/donor validasyonu için kritik.
   - `CameraService` (AVFoundation): Capture pipeline'ı kurar, ARKit high-res frame → JPEG dönüşümünü yönetir, iOS 17 performans özelliklerini açar.
   - `AudioFeedbackService`: Ses + haptic pattern'larını yönetir; proximity, countdown, success, error tonlarını tetikler.
   - `StorageService`: Photos framework entegrasyonu, albüm oluşturma, paylaşım.
   - `SessionPersistenceService`: Session auto-save/restore, `Application Support` klasöründe metadata JSON saklar.

3. **Models/**

   - `CaptureAngle`: Her açı için hedef pitch/yaw/roll, toleranslar, talimat metinleri, SF Symbol id'leri.
   - `CaptureSession`: Aktif açı, çekilen foto listesi, skorlar, zaman/deneme istatistikleri, device info, ML metadata.
   - `PoseValidation`: Orientation/detection/stability durumlarını ayrı ayrı tutar, `ValidationStatus` üretir (`invalid`, `adjusting`, `valid`, `locked`).

4. **Views/**
   - `CaptureFlowView`: Kamera önizleme + overlay bileşenlerini (ProximityIndicator, Countdown, ValidationFeedback, SuccessFlash) kompozit eder.
   - `VideoInstructionView`: Vertex/Donor için otomatik video rehberi (AVPlayer + Lottie benzeri overlay).
   - `ProximityIndicator`, `CountdownView`, `AudioToggle`, `AngleTransition` gibi component'ler SwiftUI ile reusable şekilde yazılmıştır.

### Veri Akışı

1. Kamera açıldığında FaceTrackingService ve MotionService eşzamanlı başlar.
2. Servislerden gelen veriler Combine ile CaptureViewModel'e akar, `performValidation` ile normalize edilir.
3. `PoseValidation` durumu SwiftUI view'larına publish edilir; kullanıcı doğru açıya yaklaştığında audio/haptic feedback artar.
4. `locked` state'i yakalandığında countdown tetiklenir, CameraService ARKit high-res frame'i yakalar, StorageService kaydeder, SessionPersistence günceller.

## 🎯 Zorlu Açılardaki Kılavuzlama Mekanizması

Vertex (tepe) ve Donor Area (arka donör) açıları, kullanıcı telefonu başının üstüne/arkasına taşıdığı için hem UX hem de teknik açıdan en kritik kısımdır. PentaCapture bu süreci aşağıdaki bileşenlerle yönetir:

### 1. Video Talimat Katmanı

- `VideoInstructionView`, Vertex için `instruction_short.mov`, Donor için `instruction_long.mov` kliplerini otomatik oynatır.
- `CaptureViewModel`, açı değiştiğinde `videoFileNameForAngle()` ile video gereksinimini kontrol eder; gerekiyorsa validasyon döngüsünü duraklatır, kamera preview'u aktif tutar (pre-warm).
- Kullanıcı videoyu tekrar oynatabilir, 2 saniye sonra “Atla” butonu çıkar, böylece uzman kullanıcılar gecikme yaşamaz.

### 2. Multi-Sensor Fusion (ARKit + CoreMotion)

```swift
if let headPose = faceTracking.currentHeadPose {
    // Vertex: pitch ≈ 0°, Donor: yaw devre dışı
    validate(headPose: headPose)
} else if let device = motion.currentOrientation {
    // Yüz frame'de değilse CoreMotion'a geç
    validate(devicePitch: device.pitchDegrees, deviceRoll: device.rollDegrees)
}
```

- **Vertex**: Yüz görünüyorsa ARKit pitch 0° ± 10°; yüz görünmüyorsa CoreMotion pitch 90° ± 20°, roll toleransı geniş.
- **Donor Area**: CoreMotion pitch 165° ± 40°, roll ±180° ± 40°. Yüzün görünmemesi normal kabul edilip sadece IMU verisi kullanılır.
- **Fusion Mantığı**: ARKit önceliklidir; tracking kaybedildiğinde otomatik CoreMotion'a düşer, kullanıcı bunu fark etmez.

### 3. Adaptif Tolerance Tablosu

| Açı              | Pitch Toleransı | Yaw Toleransı | Roll Toleransı       | Not                             |
| ---------------- | --------------- | ------------- | -------------------- | ------------------------------- |
| Front/Right/Left | ±15°            | ±15°          | Serbest              | Kamera önündeki klasik çekim    |
| Vertex           | ±20°            | —             | Serbest              | Telefon dik, yüz görünmeyebilir |
| Donor            | ±40°            | —             | ±40° (±180° çevresi) | Başın arkası, en esnek senaryo  |

Toleranslar `CaptureAngle` enum'u içinde saklanır, metadata'da gerçek hata payı kaydedilir (ML için kalibrasyon verisi).

### 4. Görsel Rehberlik: ProximityIndicator

- SwiftUI tabanlı circular progress ring; pitch/roll/centering skorlarının ortalamasıyla beslenir.
- Renk Kodları:
  - **0-30% (Kırmızı)**: “Pozisyon ayarla”
  - **30-60% (Turuncu)**: “Yaklaşıyorsun”
  - **60-85% (Sarı)**: “Neredeyse hazır”
  - **85-100% (Yeşil)**: “Mükemmel, sabit kal”
- Vertex/Donor sırasında yüz merkezde olmayabileceği için centering faktörü otomatik devre dışı bırakılır.

### 5. Ses + Haptic Feedback

- **Proximity Sound**: 250-700 Hz arasında sinyal üretir; pitch hata payı azaldıkça frekans yükselir, radar benzeri hissiyat verir.
- **Countdown Sesleri**: 3-2-1 için farklı tonlar + haptic intensities (`soft`, `medium`, `rigid`).
- **Haptic Escalation**: >70% soft, >85% medium, >95% rigid pattern; kullanıcı ekranı görmüyorsa bile doğru açıya yaklaştığını hisseder.

### 6. Stabilite ve Hareket Algılama

- `PoseValidation` “valid” olduktan sonra en az 0.5 saniye stabil olma şartı aranır; `stabilityDuration` Combine ile izlenir.
- Countdown sırasında `lockedPose` kaydedilir, her 100 ms'de bir güncel head pose ile karşılaştırılır; yaw/pitch farkı 8°'yi aşarsa countdown iptal edilir ve kullanıcı uyarılır.
- Bu mekanizma bulanık fotoğraf riskini azaltır, kullanıcıya ikinci şans sunar.

### 7. Hızlandırılmış Akış (Scenario-Based Countdown)

- Front/Right/Left açılarında countdown 2-1 (0.7 s interval) çalışır, toplam ~2.5 s; kullanıcı hızlıca ilerler.
- Vertex/Donor açılarında 3-2-1 (1.0 s interval) uygulanır, toplam ~3.5 s; kullanıcıya cihazı stabilize etmesi için daha uzun pencere verilir.
- Başarılı çekim sonrasında success flash + triple haptic ile kullanıcı bilgilendirilir, `CaptureSession` bir sonraki açıya geçer.

## 📊 Validation Algoritması

**Multi-Sensor Fusion** yaklaşımı ile 15 FPS (67ms) validasyon döngüsü:

**1. Data Collection**

- ARKit: Head pose (pitch, yaw, roll), face position, tracking state
- CoreMotion: Device orientation (pitch, roll, yaw), gravity, tilt angle

**2. Validation Steps**

- **Orientation Check**: Yüz/telefon açısı hedef değere uygun mu? (tolerans dahilinde)
- **Detection Check**: Yüz merkezde mi? (ilk 3 açı için, offset < 0.5)
- **Stability Check**: 0.5 saniye boyunca stabil mi?

**3. Status Determination**

- `invalid`: Kriterler karşılanmıyor
- `adjusting(progress)`: İlerleme var, henüz tamamlanmadı
- `valid`: Tüm kriterler karşılandı
- `locked`: Stabil ve otomatik çekim için hazır

**4. Auto-Capture Trigger**

- Status `locked` olduğunda 3 saniyelik geri sayım başlar
- Kullanıcı hareket ederse geri sayım iptal olur

## 🔧 Teknolojiler

**Frameworks**: SwiftUI, ARKit (Face Tracking), CoreMotion (IMU), AVFoundation, Photos, Combine, CoreImage

**Gereksinimler**:

- iOS 17.6+ (ZORUNLU)
- iPhone XR+ (TrueDepth/Face ID gerekli)
- Desteklenmeyen: iPhone X (iOS 17.6 yok), iPhone 8-, iPad (Face ID yok), iPhone SE

**Dependencies**: Hiçbir 3rd party dependency yok, tamamen native iOS frameworks

## 📁 Proje Yapısı

MVVM mimarisi ile modüler organizasyon:

- **ViewModels/** - CaptureViewModel (main orchestrator)
- **Models/** - CaptureAngle, CaptureSession, PoseValidation
- **Services/** - Camera, FaceTracking, Motion, AudioFeedback, Storage, SessionPersistence
- **Views/** - Onboarding, Capture (CaptureFlow, ARKitPreview, Overlays), Components (Countdown, ProximityIndicator, VideoInstruction), Review
- **Helpers/** - Utility functions, coordinate transforms
- **Assets/** - Video tutorials (instruction_short.mov, instruction_long.mov)

## 🎨 UI/UX Tasarım

**Modern & Minimal**: Glassmorphism, dark theme, SF Symbols, spring animations

**Accessible**: 44x44pt touch targets, high contrast, multi-modal feedback

**Performant**: 60 FPS, lazy loading, background processing, memory safe

## 📊 Metadata & ML Integration

Her fotoğraf için detaylı metadata toplanır:

- **Session Info**: session_id, device_info, timestamp
- **Validation Scores**: pitch_accuracy, yaw_accuracy, centering_accuracy, stability_score, overall_score
- **Device Pose**: device_pitch/roll/yaw/tilt, head_pitch/yaw/roll
- **Capture Stats**: attempt_count, time_spent_seconds, image dimensions

Export: `session.exportMetadataJSON()` veya `session.exportAsJSON(includeImages: true)` ile JSON formatında çıktı alınabilir.

## 🧪 Test & Debug

**Debug Overlay**: Settings'den açılabilir - ARKit tracking state, face pose values, FPS counter

**Common Issues**:

- ⚠️ **ARKit hatası**: iPhone XR+ cihaz, iOS 17.6+, Face ID aktif, fiziksel cihaz gerekli
- **Fotoğraf çekilmiyor**: Kamera izni, ARKit tracking "Normal", yüz tespit kontrolü
- **Validation başarısız**: Telefon açısı, yüz merkezde, 0.5s stabil tutma
- **Yavaş performance**: iOS 17.6+, background apps kapatma, iPhone 11 Pro+ optimal

## 🎯 Hackathon Kriterleri

✅ **Temel Özellikler**: 5 açıdan otomatik çekim, ARKit+CoreMotion fusion, otomatik deklanşör, tutarlı çekimler

✅ **Zorlu Açılar Çözümü**: Video talimatlar, multi-sensor fusion, geniş tolerance (±40°), görsel rehberlik, ses/haptic feedback

✅ **UX/UI**: Minimal modern tasarım, hızlı akış, session auto-save, onboarding, review screen

✅ **Teknik Stabilite**: MVVM modüler mimari, memory management, error handling, 60 FPS, iOS 17.6+ optimizations, offline support

✅ **Tutarlılık Algoritması**: Precise targets, metadata tracking, ML-ready export

---

**PentaCapture** - Saç/Kafa Derisi Fotoğrafı için Profesyonel Self-Capture Çözümü 📸
