# PentaCapture - iOS Hair Photography Application

An iOS app developed for the Smile Hair Clinic Hackathon that automatically captures hair/scalp photos from 5 different angles.

## 🎯 Project Goal

An intelligent, fully automatic, and guided mobile application that enables users to capture their own photos from 5 critical angles (especially covering hair/scalp areas) without assistance and with consistent positioning.

## ✨ Features

### 5 Critical Angles

1. **Full Face Front** - Front view of the face
2. **45° Right Profile** - Front and right side of the face
3. **45° Left Profile** - Front and left side of the face
4. **Vertex (Top)** - Crown area of the scalp
5. **Donor Area (Back)** - Upper nape and back side areas

### Main Features

#### 🤖 Automatic Shutter

- Automatic capture when phone angle and face/head position are correct
- Countdown timer for user preparation
- Manual capture option available

#### 📐 Smart Position Guide

- **Phone Angle Detection**: Real-time angle measurement with CoreMotion
- **Face/Head Detection**: Face and head region recognition with Vision Framework
- **Distance Control**: Distance validation for optimal photo size
- **Center Alignment**: Center position control with bounding box

#### 🎨 Visual Feedback

- Color-coded status indicators (Red → Yellow → Green)
- Semi-transparent silhouette guides
- Progress indicators and metrics
- Real-time validation messages

#### 🔊 Audio and Haptic Feedback

- Proximity sound (tone increases as you approach target position)
- Countdown beep sounds
- Success sounds
- Haptic feedback

#### 📱 User Experience

- Turkish interface and guidance
- Onboarding/Tutorial screen
- Photo review and retake
- Save to gallery
- Progress tracking (how many of 5 photos captured)

## 🏗️ Architecture

### MVVM Pattern

```
PentaCapture/
├── Models/                    # Data models
│   ├── CaptureAngle.swift    # 5 angle definitions and requirements
│   ├── CaptureSession.swift  # Session management
│   └── PoseValidation.swift  # Validation metrics
│
├── Services/                  # Business logic services
│   ├── CameraService.swift   # AVFoundation camera control
│   ├── MotionService.swift   # CoreMotion motion tracking
│   ├── VisionService.swift   # Vision Framework face/head detection
│   ├── AudioFeedbackService.swift  # Audio feedback
│   └── StorageService.swift  # Photo storage
│
├── ViewModels/               # Presentation logic
│   └── CaptureViewModel.swift # Main coordinator
│
└── Views/                    # SwiftUI views
    ├── Capture/             # Capture screens
    ├── Review/              # Review screens
    ├── Onboarding/          # Onboarding screens
    └── Components/          # Reusable components
```

### Technology Stack

- **SwiftUI**: Modern UI framework
- **AVFoundation**: Camera control and photo capture
- **Vision**: Face and head detection
- **CoreMotion**: Device orientation tracking
- **Combine**: Reactive data flow
- **Photos**: Gallery integration

## 🔧 Setup

### Requirements

- Xcode 15.0+
- iOS 16.0+
- iPhone (real device recommended - for camera and sensors)

### Steps

1. Clone the project:

```bash
git clone <repository-url>
cd PentaCapture
```

2. Open with Xcode:

```bash
open PentaCapture.xcodeproj
```

3. Select your development team (Signing & Capabilities)

4. Run on a real iOS device (simulator has limited camera access)

## 📋 Permissions

The app requires the following permissions:

- **Camera Access**: For taking photos
- **Photo Library**: For saving photos
- **Motion Sensors**: For detecting phone angle

All permissions are defined with descriptions in the `Info.plist` file.

## 🎯 Usage Flow

1. **Onboarding**: First launch shows 5 angles and usage instructions
2. **Angle 1-5 Loop**: For each angle:
   - Angle instructions are displayed
   - User positions the phone correctly
   - Visual and audio feedback provides guidance
   - Automatic capture starts when position is correct
   - Photo is taken after countdown
3. **Review**: Review screen opens when all photos are captured
4. **Save**: User can save photos to gallery or share

## 🔑 Critical Features and Algorithm

### Automatic Capture Logic

For automatic photo capture, **all** criteria must be met simultaneously:

1. ✅ **Device Angle**: Within ±5-10° of target pitch angle
2. ✅ **Face/Head Detection**: Detected by Vision Framework
3. ✅ **Size**: Detection covers 30-50% of frame
4. ✅ **Center**: Bounding box center is within 15% of frame center
5. ✅ **Stability**: Motionless for 0.5 seconds

### Validation States

- **Invalid** (Red): Criteria not met
- **Adjusting** (Orange/Yellow): Getting close but not yet
- **Valid** (Yellow): Correct position, waiting for stability
- **Locked** (Green): All criteria met, capture starting

## 🎨 UI/UX Best Practices

### Visual Design

- ✅ Minimalist interface - camera first
- ✅ High contrast - visible in all lighting
- ✅ Dark mode support
- ✅ Accessibility (VoiceOver, Dynamic Type)

### User Experience

- ✅ Clear and understandable guidance (Turkish)
- ✅ Real-time feedback
- ✅ Error tolerance (manual capture option)
- ✅ Progress indicators
- ✅ Easy retake

### Performance

- ✅ Frame processing throttling (15 fps)
- ✅ Heavy processing on background threads
- ✅ Memory management
- ✅ Battery optimization

## 🧪 Test Scenarios

### Functional Tests

- [ ] Photo capture from all 5 angles
- [ ] Automatic shutter functionality
- [ ] Manual capture
- [ ] Photo review and retake
- [ ] Save to gallery

### Edge Cases

- [ ] Low light conditions
- [ ] Fast movement
- [ ] Face detection failure
- [ ] Too far/close distance
- [ ] Permission denial

## 📊 Performance Metrics

- **Validation Latency**: <100ms
- **Frame Processing**: ~15 fps
- **Stability Duration**: 0.5 seconds
- **Photo Quality**: High-resolution HEVC

## 🚀 Future Enhancements

- [ ] Backend integration (photo upload)
- [ ] AI-powered hair analysis
- [ ] Multi-language support
- [ ] iPad support
- [ ] Automatic dark mode switching
- [ ] Cloud backup

## 👥 Developer Notes

### Debug Mode

Useful debug information during development:

- Camera angle values logged to console
- Vision detection confidence displayed
- Validation metrics visible in UI

### Customization

- `CaptureAngle.swift`: Angle requirements can be adjusted
- `ValidationMetrics.swift`: Threshold values can be modified
- `AudioFeedbackService.swift`: Audio tones can be customized

## 📄 License

This project was developed for the Smile Hair Clinic Hackathon.

## 🏆 Hackathon Criteria

### User Experience (UX/UI) ✅

- Self-capture of Vertex and Donor areas made easier
- Intuitive usage with visual guides and audio feedback

### Guidance Mechanism ✅

- Real-time visual feedback (color-coded)
- Silhouette and bounding box guides
- Progress percentage display

### Technical Stability ✅

- Fast and reliable position detection with gyroscope/accelerometer
- High accuracy face/head detection with Vision Framework
- Optimized performance with throttling

### Consistency ✅

- Defined target metrics for each angle
- Standardized validation criteria
- Repeatable photo quality

---

**Note**: This application is a real hackathon project and may require additional security, testing, and optimization for production use.
