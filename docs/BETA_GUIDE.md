# PDFOS Beta Testing Guide

Welcome to the PDFOS beta program! This guide will help you get started and provide effective feedback.

## Getting Started

### Installation

1. Download PDFOS Beta from the provided link
2. Open the DMG file
3. Drag PDFOS to your Applications folder
4. On first launch, you may need to right-click → Open to bypass Gatekeeper

### First Launch

PDFOS will guide you through a quick onboarding:

1. **Welcome** - Introduction to PDFOS
2. **Features** - Overview of the three revolutionary features
3. **Adaptive UI** - Enable/disable adaptive interface
4. **Cloud Sync** - Configure iCloud synchronization
5. **Permissions** - Optional camera access for gaze tracking
6. **Complete** - You're ready to go!

## Beta Features

### 1. Semantic Version Control ✅
- **Status**: Production-ready
- **What to Test**:
  - Create/edit documents
  - Make changes and observe semantic tracking
  - Use branching and merging
  - Test conflict resolution

### 2. Time Travel Debugging ✅
- **Status**: Production-ready
- **What to Test**:
  - Open timeline (Cmd+T)
  - Replay document history
  - Generate video replays
  - Export PDF reports

### 3. Adaptive UI ✅
- **Status**: Production-ready
- **What to Test**:
  - Enable adaptive UI (Cmd+Shift+A)
  - Calibrate gaze tracking
  - Observe mode transitions
  - Test manual mode switching (Cmd+1/2/3/4)

### 4. Cloud Synchronization ✅
- **Status**: Beta
- **What to Test**:
  - Enable iCloud sync
  - Test cross-device synchronization
  - Verify offline editing
  - Check conflict resolution

## Known Issues

### Current Limitations

1. **CloudKit Sync**: First sync may take several minutes for large documents
2. **Gaze Tracking**: Works best in good lighting conditions
3. **Performance**: Large documents (500+ pages) may have slower time travel
4. **Video Export**: Limited to documents with <1000 events

### Workarounds

- **Slow sync**: Use smaller documents initially
- **Gaze accuracy**: Ensure good lighting and camera positioning
- **Large documents**: Enable performance optimization in Preferences
- **Video export**: Use date ranges to limit events

## Providing Feedback

### What We Need

1. **Crash Reports** (automatically collected if you opt-in)
2. **Feature requests** (what's missing?)
3. **Usability issues** (what's confusing?)
4. **Performance problems** (what's slow?)
5. **Bug reports** (what's broken?)

### How to Report

**Email**: beta@pdfos.com

Include:
- macOS version
- PDFOS version (Help → About)
- Steps to reproduce
- Screenshots/screen recordings if applicable
- Diagnostics report (Help → Export Diagnostics)

**GitHub**: [github.com/yourusername/PDFOS/issues](https://github.com/yourusername/PDFOS/issues)

Use issue templates for bugs and feature requests.

## Beta Testing Checklist

### Week 1: Basic Features
- [ ] Install and complete onboarding
- [ ] Create a test document
- [ ] Make edits and track changes
- [ ] Test version control (branch/merge)
- [ ] Enable cloud sync
- [ ] Try adaptive UI

### Week 2: Advanced Features
- [ ] Test time travel with 50+ events
- [ ] Generate video replay
- [ ] Export PDF report
- [ ] Calibrate gaze tracking
- [ ] Test all 4 UI modes
- [ ] Use keyboard shortcuts

### Week 3: Real-World Usage
- [ ] Use PDFOS for actual work
- [ ] Test with large documents (100+ pages)
- [ ] Test cross-device sync
- [ ] Try collaboration features
- [ ] Use version control in real workflow

### Week 4: Stress Testing
- [ ] Test with 10+ documents open
- [ ] Create 500+ events in one document
- [ ] Test extended usage (8+ hours)
- [ ] Try edge cases and unusual workflows
- [ ] Report all issues found

## Privacy & Data Collection

### What We Collect (if you opt-in)

- Anonymous usage statistics
- Crash reports (no document content)
- Performance metrics
- Feature usage patterns

### What We DON'T Collect

- Document content
- Personal information
- Video from camera
- Keystrokes

### Opting Out

Preferences → Privacy → Disable Telemetry

## Performance Targets

Help us meet our goals:

| Feature | Target | Your Result |
|---------|--------|-------------|
| Semantic Analysis | <400ms/page | _____ |
| Time Travel | <100ms | _____ |
| Video Generation | <10s for 50 events | _____ |
| Sync | <5s typical document | _____ |
| Memory Usage | <500MB for 100 pages | _____ |

Report if you see significantly worse performance!

## Keyboard Shortcuts

Master these for efficient testing:

| Action | Shortcut |
|--------|----------|
| New Document | `Cmd+N` |
| Timeline | `Cmd+T` |
| Minimal Mode | `Cmd+1` |
| Reading Mode | `Cmd+2` |
| Editing Mode | `Cmd+3` |
| Power Mode | `Cmd+4` |
| Toggle Adaptive UI | `Cmd+Shift+A` |
| Calibrate Gaze | `Cmd+Shift+G` |
| Export Diagnostics | `Cmd+Shift+D` |

## Troubleshooting

### App Won't Launch

1. Check macOS version (requires 14.0+)
2. Right-click → Open to bypass Gatekeeper
3. Check Console.app for error messages

### Poor Performance

1. Enable performance optimization (Preferences → Performance)
2. Disable gaze tracking if not needed
3. Close other applications
4. Check Activity Monitor for resource usage

### Sync Not Working

1. Verify iCloud is enabled (System Settings → iCloud)
2. Check internet connection
3. Try manual sync (File → Sync Now)
4. Check CloudKit status

### Features Not Working

1. Export diagnostics (Help → Export Diagnostics)
2. Include in bug report
3. Try resetting preferences (Preferences → Advanced → Reset)

## Contact

- **Email**: beta@pdfos.com
- **Discord**: [discord.gg/pdfos-beta](https://discord.gg/pdfos-beta) (join for discussions)
- **GitHub**: [github.com/yourusername/PDFOS](https://github.com/yourusername/PDFOS)

## Thank You!

Your participation in the beta program is invaluable. Together, we're building the future of PDF editing!

---

**PDFOS Beta v1.0 - Confidential**
