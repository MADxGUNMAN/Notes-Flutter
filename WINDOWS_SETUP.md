# Windows Setup Guide

## Prerequisites for Windows Development

To build and run the Notes App on Windows, you need to enable Developer Mode and install Visual Studio.

### 1. Enable Developer Mode

**Option A: Via Settings UI**
1. Press `Win + I` to open Windows Settings
2. Go to **Settings** > **Privacy & Security** > **For developers**
3. Toggle **Developer Mode** to **On**
4. Confirm the prompt that appears

**Option B: Via Command Line**
```powershell
start ms-settings:developers
```

Then toggle Developer Mode to On in the settings window that opens.

### 2. Install Visual Studio 2022

1. Download **Visual Studio 2022 Community** (free) from:
   https://visualstudio.microsoft.com/downloads/

2. During installation, select the **"Desktop development with C++"** workload

3. Make sure the following components are included:
   - MSVC v143 - VS 2022 C++ x64/x86 build tools
   - Windows 10/11 SDK
   - C++ CMake tools for Windows

4. Complete the installation and restart your computer if prompted

### 3. Verify Setup

After completing the above steps, verify your setup:

```bash
flutter doctor -v
```

You should see checkmarks for:
- Flutter
- Windows Version
- Visual Studio

### 4. Run the App

Once setup is complete, you can build and run the app:

```bash
# For debug mode
flutter run -d windows

# For release build
flutter build windows --release
```

## Alternative: Run on Web (No Visual Studio Required)

If you don't want to install Visual Studio, you can run the app in a web browser:

### Using Edge (Already Available)

```bash
flutter run -d edge
```

### Using Chrome (If Installed)

```bash
flutter run -d chrome
```

The web version has full functionality and doesn't require Developer Mode or Visual Studio.

## Troubleshooting

### Issue: "Building with plugins requires symlink support"

**Solution**: Enable Developer Mode as described in step 1 above.

### Issue: "Visual Studio not installed"

**Solution**: Install Visual Studio 2022 with C++ desktop development workload as described in step 2.

### Issue: Can't enable Developer Mode

**Solution**: 
- Make sure you're logged in as an administrator
- Check if your organization has disabled Developer Mode via Group Policy
- Try enabling it from Windows Settings instead of the command line

## Contact

For more help, refer to:
- Flutter Windows Setup: https://docs.flutter.dev/get-started/install/windows
- Visual Studio Installation: https://docs.microsoft.com/visualstudio/install/
