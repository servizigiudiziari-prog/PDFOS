# Adaptive UI Guide for PDFOS

A comprehensive guide to PDFOS's revolutionary adaptive user interface that changes based on your behavior and gaze patterns.

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [UI Complexity Modes](#ui-complexity-modes)
4. [Gaze Tracking](#gaze-tracking)
5. [Behavior Detection](#behavior-detection)
6. [Configuration](#configuration)
7. [Privacy & Security](#privacy--security)
8. [Troubleshooting](#troubleshooting)

---

## Overview

### What is Adaptive UI?

PDFOS features a revolutionary **adaptive user interface** that automatically adjusts its complexity based on what you're doing:

- **Minimal Mode** - Clean, distraction-free reading
- **Reading Mode** - Basic navigation tools
- **Editing Mode** - Common editing features
- **Power Mode** - All features for advanced users

The interface learns from your behavior and **transitions automatically** between modes, showing you exactly what you need, when you need it.

### How It Works

PDFOS uses three advanced technologies:

1. **Gaze Tracking** - Uses your webcam to understand where you're looking
2. **Behavior Analysis** - Detects patterns in your mouse, keyboard, and document interactions
3. **Machine Learning** - Predicts your intent and adapts the interface accordingly

```
┌─────────────────────────────────────────────────────┐
│                 Your Actions                        │
│  (Mouse, Keyboard, Gaze, Document Interactions)     │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│            Behavior Analysis                        │
│  • Detects patterns (reading, editing, etc.)        │
│  • Analyzes gaze fixations                          │
│  • Tracks tool usage                                │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│           Intent Prediction                         │
│  • ML model predicts what you want to do            │
│  • Calculates confidence scores                     │
│  • Suggests appropriate UI mode                     │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│          UI Adaptation                              │
│  • Smoothly transitions to appropriate mode         │
│  • Shows/hides interface elements                   │
│  • Maintains user preferences                       │
└─────────────────────────────────────────────────────┘
```

### Key Benefits

- **Less Clutter** - Only see what you need
- **Faster Workflow** - Interface adapts to your speed
- **Natural Interaction** - No manual mode switching required
- **Personalized** - Learns your preferences over time
- **Accessible** - Reduces cognitive load

---

## Getting Started

### First-Time Setup

When you first open PDFOS, you'll be guided through setup:

1. **Camera Permission**
   - PDFOS requests access to your webcam for gaze tracking
   - This is **entirely optional** - adaptive UI works without it
   - Click **Allow** to enable full gaze tracking features

2. **Calibration**
   - If you enabled gaze tracking, you'll calibrate it
   - Look at each target point as it appears (takes ~30 seconds)
   - You can skip and calibrate later from Preferences

3. **Enable Adaptive UI**
   - Choose whether to enable automatic mode switching
   - You can always toggle this on/off from the View menu

### Quick Start

**Enable/Disable Adaptive UI:**
```
View → Adaptive UI → Enable  (or press Cmd+Shift+A)
```

**Manual Mode Switching:**
- **Minimal**: `Cmd+1` or View → UI Mode → Minimal
- **Reading**: `Cmd+2` or View → UI Mode → Reading
- **Editing**: `Cmd+3` or View → UI Mode → Editing
- **Power**: `Cmd+4` or View → UI Mode → Power

**Calibrate Gaze Tracking:**
```
Preferences → Adaptive UI → Calibrate Gaze Tracking
```

---

## UI Complexity Modes

### 1. Minimal Mode

**When It Activates:**
- You haven't interacted with the document for 30+ seconds
- You're in full-screen reading mode
- You pressed `Cmd+1`

**What's Visible:**
- ✅ Document content only
- ❌ All toolbars and panels hidden

**Best For:**
- Distraction-free reading
- Presentations
- Focused study sessions

**Example:**
```
┌─────────────────────────────────────┐
│                                     │
│       Document Content              │
│                                     │
│       • Clean layout                │
│       • No distractions             │
│       • Full screen space           │
│                                     │
└─────────────────────────────────────┘
```

### 2. Reading Mode

**When It Activates:**
- Continuous scrolling detected
- Flipping through pages
- Sustained eye focus on document
- You pressed `Cmd+2`

**What's Visible:**
- ✅ Document content
- ✅ Navigation bar
- ✅ Page indicator
- ✅ Search box
- ✅ Zoom controls
- ❌ Editing tools
- ❌ Advanced features

**Best For:**
- Reading documents
- Navigating between pages
- Searching for content
- Quick document review

**Example:**
```
┌──────────┬──────────────────────┬────┐
│ [◀] [▶] │    Page 15 of 42     │ 🔍 │
└──────────┴──────────────────────┴────┘
┌─────────────────────────────────────┐
│                                     │
│       Document Content              │
│                                     │
│       • Basic navigation            │
│       • Search available            │
│       • Zoom controls               │
│                                     │
└─────────────────────────────────────┘
```

### 3. Editing Mode

**When It Activates:**
- Text selection detected
- Annotation tools used
- Text input occurring
- You pressed `Cmd+3`

**What's Visible:**
- ✅ Everything from Reading Mode
- ✅ Toolbar with editing tools
- ✅ Properties panel
- ✅ Annotation tools
- ✅ Text formatting
- ✅ Version badge
- ❌ Advanced semantic features

**Best For:**
- Making annotations
- Editing document content
- Adding comments
- Basic document modifications

**Example:**
```
┌──────────────────────────────────────┐
│ [T] [✎] [🖼] [📝] [↩] [↪]           │  ← Toolbar
└──────────────────────────────────────┘
┌─────────────────┬────────────────────┐
│    Document     │   Properties       │
│                 │   • Font: Arial    │
│    • Editing    │   • Size: 12pt     │
│    • Tools      │   • Color: Black   │
│    • Active     │                    │
└─────────────────┴────────────────────┘
```

### 4. Power Mode

**When It Activates:**
- Keyboard shortcuts used frequently
- Rapid tool switching detected
- Version control actions performed
- Working with multiple documents
- You pressed `Cmd+4`

**What's Visible:**
- ✅ **All features and panels**
- ✅ Timeline
- ✅ Version history
- ✅ Semantic panel
- ✅ Analytics
- ✅ All advanced features

**Best For:**
- Professional workflows
- Advanced document manipulation
- Version control operations
- Power users who need all features

**Example:**
```
┌────────────────────────────────────────────────────┐
│ [Full Toolbar with All Tools]                     │
└────────────────────────────────────────────────────┘
┌──────┬──────────────────┬───────────┬─────────────┐
│ Out- │    Document      │ Version   │ Analytics   │
│ line │                  │ History   │             │
│      │    • All         │           │ • Stats     │
│      │    • Features    │ • Full    │ • Metrics   │
│      │    • Visible     │ • Timeline│ • Insights  │
└──────┴──────────────────┴───────────┴─────────────┘
```

---

## Gaze Tracking

### Setup and Calibration

**Initial Calibration:**

1. Go to **Preferences** → **Adaptive UI** → **Calibrate Gaze Tracking**
2. Follow the on-screen instructions:
   - Position yourself comfortably in front of your camera
   - Look at each target point as it appears
   - Keep your head still during calibration
   - The process takes about 30 seconds

3. After calibration, you'll see your accuracy score:
   - **90-100%**: Excellent - Gaze tracking will work great
   - **70-89%**: Good - Should work well for most tasks
   - **Below 70%**: Fair - Consider recalibrating

**Recalibration:**

Recalibrate if:
- You changed your seating position
- You got a new webcam
- Gaze tracking seems inaccurate
- Lighting conditions changed significantly

**Tips for Best Results:**
- Ensure good lighting on your face
- Position camera at eye level
- Sit 50-70cm from the screen
- Avoid wearing glasses with strong reflections
- Keep the camera lens clean

### How Gaze Tracking Works

PDFOS uses your webcam and macOS's Vision framework to:

1. **Detect your face** in the camera feed
2. **Track your eye positions** using facial landmarks
3. **Calculate gaze point** on the screen
4. **Detect fixations** where your gaze stays focused
5. **Analyze patterns** to understand your behavior

**What It Detects:**

- **Reading**: Sustained focus on document text
- **Scanning**: Rapid eye movement across page
- **Searching**: Eyes moving to toolbar/search areas
- **Editing**: Focus on specific document regions
- **Idle**: No focused gaze pattern

### Privacy

- **All processing is on-device** - no video leaves your Mac
- **No video is recorded** - only gaze coordinates are calculated
- **Can be disabled** completely while keeping other adaptive features
- **Camera indicator** shows when camera is in use

---

## Behavior Detection

### Types of Behavior Patterns

PDFOS detects these patterns:

#### Reading Patterns

**Continuous Scrolling**
- Confidence: 85%
- Detection: 3+ scroll events in 2 seconds
- Suggests: Reading Mode

**Page Flipping**
- Confidence: 90%
- Detection: 2+ page changes in 3 seconds
- Suggests: Reading Mode

**Sustained Reading**
- Confidence: 88%
- Detection: Stable gaze on document for 5+ seconds
- Suggests: Reading Mode

**Skimming**
- Confidence: 75%
- Detection: Rapid gaze movement across pages
- Suggests: Reading Mode

#### Editing Patterns

**Text Selection**
- Confidence: 85%
- Detection: Text selection or highlighting
- Suggests: Editing Mode

**Tool Hovering**
- Confidence: 80%
- Detection: Mouse hovering over editing tools
- Suggests: Editing Mode

**Annotation Drawing**
- Confidence: 90%
- Detection: Using annotation tools
- Suggests: Editing Mode

**Frequent Undo**
- Confidence: 80%
- Detection: 2+ undo actions in 10 seconds
- Suggests: Editing Mode

#### Power User Patterns

**Keyboard Shortcuts**
- Confidence: 95%
- Detection: 2+ shortcuts in 5 seconds
- Suggests: Power Mode

**Rapid Tool Switching**
- Confidence: 82%
- Detection: 3+ tool changes in 10 seconds
- Suggests: Power Mode

**Version Control Usage**
- Confidence: 90%
- Detection: Using version control features
- Suggests: Power Mode

**Multiple Documents**
- Confidence: 85%
- Detection: Switching between documents
- Suggests: Power Mode

#### Idle Patterns

**No Input**
- Confidence: 95%
- Detection: 30+ seconds without keyboard/mouse
- Suggests: Minimal Mode

**Gaze Wandering**
- Confidence: 85%
- Detection: Unfocused gaze patterns
- Suggests: Minimal Mode

### Confidence Thresholds

For automatic mode switching, behaviors must meet the confidence threshold (default: 70%):

- **High Confidence** (>90%): Transition immediately
- **Good Confidence** (70-90%): Wait for consensus from multiple patterns
- **Low Confidence** (<70%): No automatic transition

---

## Configuration

### Preferences

Access via: **Preferences** → **Adaptive UI**

### Auto-Transition Settings

**Enable/Disable Auto-Transition:**
- ✓ **Enabled**: Interface changes automatically based on behavior
- ☐ **Disabled**: You manually switch modes with `Cmd+1/2/3/4`

**Transition Confidence Threshold:**
```
Low (50%) ←──────●──────→ High (90%)
             [70%]
```
- **Lower** (50-60%): More frequent transitions, less accuracy
- **Default** (70%): Balanced - recommended for most users
- **Higher** (80-90%): More accurate, less frequent transitions

**Inactivity Timeout:**
```
30 seconds ←───●───→ 5 minutes
              [2 min]
```
- Time of inactivity before returning to Minimal Mode
- Set to 0 to disable automatic return to Minimal

### Animation Settings

**Transition Speed:**
- **Instant**: No animation
- **Fast**: 0.2s transitions
- **Normal**: 0.4s transitions (default)
- **Slow**: 0.6s transitions

**Animation Style:**
- **Fade**: Elements fade in/out
- **Scale**: Elements scale while fading
- **Slide**: Elements slide and fade

### Component Overrides

**Always Show:**
Select components that should always be visible, regardless of mode:
- ☐ Timeline
- ☐ Version Badge
- ☐ Page Numbers
- ☐ Zoom Controls

**Never Show:**
Select components you never want to see:
- ☐ Analytics Panel
- ☐ Semantic Panel
- ☐ Outline View

### Gaze Tracking Settings

**Enable Gaze Tracking:**
- ✓ Enabled
- ☐ Disabled

**Calibrate:**
- Button: **Calibrate Now**
- Last calibrated: *Date/Time*
- Accuracy: *90%*

**Advanced:**
- Calibration Points: 9-point (default) / 5-point
- Recalibrate on Wake: ✓ Enabled
- Use for Analytics: ✓ Enabled (anonymous)

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Toggle Adaptive UI | `Cmd+Shift+A` |
| Minimal Mode | `Cmd+1` |
| Reading Mode | `Cmd+2` |
| Editing Mode | `Cmd+3` |
| Power Mode | `Cmd+4` |
| Calibrate Gaze | `Cmd+Shift+G` |
| Show Current Mode | `Cmd+/` |

---

## Privacy & Security

### Data Collection

**What PDFOS Tracks:**
- ✓ Gaze coordinates (local only)
- ✓ Behavior patterns (local only)
- ✓ UI mode transitions (local only)
- ✓ Anonymous usage statistics (opt-in)

**What PDFOS Does NOT Track:**
- ❌ Camera video/images
- ❌ Document content
- ❌ Personal information
- ❌ Keystroke logging
- ❌ Browsing history

### On-Device Processing

- **All gaze tracking** happens on your Mac using Vision framework
- **No video** ever leaves your device
- **No cloud processing** - everything runs locally
- **ML models** run on-device with Core ML

### Camera Usage

- **Only active** when PDFOS is in foreground
- **Camera indicator** visible when active
- **Can be disabled** completely in Preferences
- **No recording** - only real-time processing

### Opt-Out

You can disable all adaptive features:

1. Go to **Preferences** → **Adaptive UI**
2. Uncheck **Enable Adaptive UI**
3. Uncheck **Enable Gaze Tracking**
4. The interface will work like a traditional static UI

---

## Troubleshooting

### Gaze Tracking Issues

**Problem: Gaze tracking not accurate**

Solutions:
1. Recalibrate: Preferences → Adaptive UI → Calibrate
2. Check lighting - ensure your face is well-lit
3. Position camera at eye level
4. Sit 50-70cm from screen
5. Clean camera lens

**Problem: Camera permission denied**

Solutions:
1. Go to System Settings → Privacy & Security → Camera
2. Enable camera access for PDFOS
3. Restart PDFOS

**Problem: Gaze tracking stops working**

Solutions:
1. Check camera indicator - should be active
2. Restart PDFOS
3. Reset camera permissions and recalibrate
4. Update macOS (requires macOS 14.0+)

### Mode Switching Issues

**Problem: Modes switching too frequently**

Solutions:
1. Increase confidence threshold: Preferences → Adaptive UI → Threshold → 80%
2. Increase minimum duration between transitions
3. Disable auto-transition and use manual shortcuts

**Problem: Modes not switching automatically**

Solutions:
1. Check that Auto-Transition is enabled
2. Lower confidence threshold to 60-65%
3. Verify gaze tracking is calibrated and working
4. Check that behaviors are being detected (View → Adaptive UI → Show Statistics)

**Problem: Wrong mode activates**

Solutions:
1. The ML model is still learning your patterns
2. Use manual shortcuts to override
3. The system will improve accuracy over time
4. Check Component Overrides aren't interfering

### Performance Issues

**Problem: High CPU usage**

Solutions:
1. Disable gaze tracking if not needed
2. Reduce video quality: Preferences → Adaptive UI → Performance → Low
3. Close other camera-using applications
4. Update to latest macOS version

**Problem: Lag when switching modes**

Solutions:
1. Change transition speed to Instant or Fast
2. Disable animations: Preferences → Adaptive UI → Animations → Off
3. Check system performance in Activity Monitor

### General Issues

**Problem: Adaptive UI not working at all**

Solutions:
1. Check it's enabled: View → Adaptive UI → Enable
2. Grant camera permissions
3. Restart PDFOS
4. Check macOS version (requires 14.0+)
5. Reset preferences: Preferences → Advanced → Reset Adaptive UI

**Problem: Components not showing/hiding correctly**

Solutions:
1. Check Component Overrides in Preferences
2. Manually switch modes to force UI update
3. Reset UI: View → Reset Interface (Cmd+Opt+R)
4. Clear cached preferences

---

## Advanced Features

### Statistics Dashboard

View detailed adaptive UI statistics:

**View → Adaptive UI → Show Statistics**

Shows:
- Current mode and time in mode
- Total mode transitions today/week/all-time
- Most common mode
- Behavior detection accuracy
- Gaze tracking performance
- Prediction accuracy

### Manual Training

Help improve accuracy by providing feedback:

1. When UI switches modes, you'll see a small notification
2. If the mode is **correct**, do nothing
3. If the mode is **wrong**, immediately press your preferred mode shortcut
4. The system learns from this feedback

### Export Usage Data

For debugging or analysis:

1. **File → Export → Adaptive UI Data**
2. Select date range
3. Data exported as JSON
4. Includes transitions, behaviors, and statistics (no video/personal data)

---

## Keyboard Shortcuts Reference

### Mode Switching
- `Cmd+1` - Minimal Mode
- `Cmd+2` - Reading Mode
- `Cmd+3` - Editing Mode
- `Cmd+4` - Power Mode
- `Cmd+Shift+A` - Toggle Adaptive UI
- `Cmd+/` - Show Current Mode Info

### Gaze Tracking
- `Cmd+Shift+G` - Open Calibration
- `Cmd+Shift+C` - Toggle Gaze Tracking
- `Cmd+Opt+G` - Show Gaze Point (Debug)

### Preferences
- `Cmd+,` - Open Preferences
- `Cmd+Alt+R` - Reset Interface
- `Cmd+Opt+A` - Open Adaptive UI Stats

---

## FAQ

**Q: Does adaptive UI work without a camera?**
A: Yes! It still detects patterns from keyboard and mouse, just without gaze tracking.

**Q: Can I use it with an external webcam?**
A: Yes, PDFOS works with any macOS-compatible camera.

**Q: Does it work in full screen mode?**
A: Yes, but gaze tracking requires camera access even in full screen.

**Q: How much battery does it use?**
A: Gaze tracking uses ~5-10% additional CPU. Disable when on battery if needed.

**Q: Can I train it for my specific workflow?**
A: Yes, it learns over time. Use manual overrides to teach it your preferences.

**Q: Is it accessible for users with disabilities?**
A: Yes, all features have manual alternatives and work with VoiceOver.

**Q: Can multiple users share one Mac?**
A: Yes, each macOS user account has separate calibration and preferences.

---

## Support

### Need Help?

- **Documentation**: [docs.pdfos.com](https://docs.pdfos.com)
- **Video Tutorials**: [youtube.com/pdfos](https://youtube.com/pdfos)
- **Email**: support@pdfos.com
- **GitHub**: [github.com/yourusername/PDFOS/issues](https://github.com/yourusername/PDFOS/issues)

### Feedback

We're constantly improving adaptive UI:
- **Feature requests**: feedback@pdfos.com
- **Bug reports**: Use GitHub Issues
- **General feedback**: Twitter [@PDFOS](https://twitter.com/pdfos)

---

## Changelog

### Version 1.0 (Sprint 5)

- ✅ Gaze tracking with Vision framework
- ✅ 4 UI complexity modes (Minimal, Reading, Editing, Power)
- ✅ Behavior pattern detection (10+ patterns)
- ✅ ML-based intent prediction
- ✅ Smooth animated transitions
- ✅ 9-point gaze calibration
- ✅ Comprehensive configuration options
- ✅ Privacy-first on-device processing

---

**Made with ❤️ by the PDFOS Team**
