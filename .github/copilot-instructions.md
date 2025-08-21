# Kontentum Network Client

Kontentum Network Client is a Haxe-based native application that manages network-connected devices like projectors and smart plugs. It's designed to run continuously on Raspberry Pi systems and communicates with the Kontentum cloud service.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Bootstrap and Build Repository
Run these commands in exact order. **NEVER CANCEL any build commands** - they may take several minutes:

```bash
# Install system dependencies
sudo apt-get update && sudo apt-get install -y haxe neko build-essential

# Setup haxelib repository (one-time setup)
mkdir -p /tmp/haxelib && echo "/tmp/haxelib" | haxelib setup

# Install hxcpp from source (one-time setup, takes ~3 minutes)
cd /tmp && rm -rf hxcpp
git clone https://github.com/HaxeFoundation/hxcpp && haxelib dev hxcpp /tmp/hxcpp
cd /tmp/hxcpp/tools/hxcpp && haxe compile.hxml
```

**CRITICAL BUILD COMMANDS** - Set timeouts and never cancel:

```bash
# Build release version - NEVER CANCEL, takes ~60 seconds, set timeout to 120+ seconds
time haxe build.hxml

# Build debug version - NEVER CANCEL, takes ~25 seconds, set timeout to 60+ seconds  
time haxe build.hxml -debug
```

### Run the Application

```bash
# Test the built application
cd bin && ./KontentumNC
```

Expected output on successful startup:
```
Kontentum Client :: Logic Interactive | [IP_ADDRESS] | Build: [DATE]
ping: [GATEWAY_IP]
[NETWORK SCANNING OUTPUT]
Connecting to Kontentum....
```

The application will attempt to connect to kontentum.link and scan the local network. Press Ctrl+C to stop.

## Validation

### Manual Validation Requirements
**ALWAYS** run through these complete scenarios after making changes:

1. **Build Validation**:
   ```bash
   # Clean build from scratch - NEVER CANCEL, set timeout to 180+ seconds
   rm -rf bin/KontentumNC* && time haxe build.hxml
   
   # Verify executable created and is correct type
   ls -la bin/KontentumNC && file bin/KontentumNC
   ```

2. **Application Functionality Test**:
   ```bash
   # Run application for 10 seconds and capture output
   timeout 10 ./bin/KontentumNC || echo "Application ran successfully"
   ```
   
   Verify you see:
   - Application version and IP address in startup message
   - Network scanning activity 
   - Connection attempts to Kontentum service
   - No crash errors or exceptions

3. **Build Both Versions**:
   ```bash
   # Build and test both release and debug versions
   haxe build.hxml && ./bin/KontentumNC --version 2>/dev/null || echo "Release OK"
   haxe build.hxml -debug && ./bin/KontentumNC-debug --version 2>/dev/null || echo "Debug OK"
   ```

### VSCode Integration
Use VSCode tasks for development:
- **Build (Debug)**: Ctrl+Shift+P → "Tasks: Run Task" → "Build (Debug)"  
- **Build (Release)**: Ctrl+Shift+P → "Tasks: Run Task" → "Build (Release)"

Debug configurations are pre-configured in `.vscode/launch.json`.

## Common Tasks

### Key File Locations
Always check these locations when working with the codebase:

```
/src/KontentumNC.hx          # Main application entry point
/src/JobTracker.hx           # HTTP job management 
/src/OfflineTracker.hx       # Offline mode handling
/src/Projector.hx            # Projector device control
/src/fox/                    # Utility libraries (networking, hardware)
/src/com/akifox/asynchttp/   # HTTP client library (bundled)
/build.hxml                  # Main build configuration
/.vscode/tasks.json          # Build task definitions
/runKNC.sh                   # Production startup script
```

### Common Build Issues and Solutions

**Issue**: `Error: This is the first time you are running haxelib. Please run 'haxelib setup' first`
**Solution**: Run the haxelib setup command from the bootstrap section above

**Issue**: `Can't continue without hxcpp.n` or hxcpp compilation errors  
**Solution**: Re-run the hxcpp installation from bootstrap section

**Issue**: `Module not found` errors
**Solution**: Verify all dependencies are installed and haxelib is properly configured

### Development Workflow
1. **Always** build and test both release and debug versions
2. **Always** run the application manually to verify functionality 
3. **Always** check that network scanning and connection attempts work
4. **Never** commit without validating the build works end-to-end
5. **Always** use appropriate timeouts (60+ seconds for debug builds, 120+ seconds for release builds)

### Project Architecture
- **Target Platform**: Native Linux executable (intended for Raspberry Pi)
- **Language**: Haxe 4.3+ compiling to C++ via hxcpp
- **Network Communication**: HTTP (via akifox-asynchttp) + UDP for device discovery
- **Device Support**: Projectors (PJLink protocol), TP-Link Kasa smart plugs
- **Configuration**: XML-based settings in `bin/config.xml`
- **Deployment**: Runs as system service via `runKNC.sh` wrapper script

### Time Expectations - CRITICAL
Set these timeout values and **NEVER CANCEL** operations:

| Operation | Expected Time | Minimum Timeout |
|-----------|---------------|-----------------|
| hxcpp setup (one-time) | 3 minutes | 300 seconds |
| Release build | 60 seconds | 120 seconds |
| Debug build | 25 seconds | 60 seconds |
| Application startup | 1 second | 10 seconds |

### Debugging
- Debug builds include full stack traces and symbols
- Use `haxe build.hxml -debug --times` for detailed compilation timing
- Application logs to console - redirect with `./bin/KontentumNC > app.log 2>&1`
- VSCode debugger is configured for both release and debug builds

## Repository Structure Quick Reference
```
ls -la /home/runner/work/KontentumNC/KontentumNC/
total 31672
-rw-r--r-- 1 runner docker     1318 InstallHaxeOnDebian.md
-rwxr-xr-x 1 runner docker  3424548 KontentumNC
-rwxr-xr-x 1 runner docker 28937808 KontentumNC-debug  
-rw-r--r-- 1 runner docker     1615 KontentumNC.hxproj
-rw-r--r-- 1 runner docker       63 README.md
-rw-r--r-- 1 runner docker      126 Run.bat
drwxr-xr-x 3 runner docker     4096 bin
-rw-r--r-- 1 runner docker      108 build.hxml
-rwxr-xr-x 1 runner docker       94 install.sh
-rw-r--r-- 1 runner docker      556 runKNC.sh
drwxr-xr-x 5 runner docker     4096 src
```

Important files:
- `build.hxml`: Build configuration
- `src/KontentumNC.hx`: Application main class  
- `bin/KontentumNC`: Release executable
- `bin/KontentumNC-debug`: Debug executable
- `runKNC.sh`: Production runner with auto-restart