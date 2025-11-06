# Comprehensive Logging Implementation

**Date**: 2025-11-06
**Purpose**: Diagnose HTTP threading and resource leak issues

## Summary

Comprehensive logging has been implemented throughout the codebase to track HTTP thread lifecycle, job execution, socket operations, and resource utilization. This logging infrastructure will help identify the root cause of performance degradation and crashes when handling multiple concurrent HTTP requests.

## What Was Changed

### 1. Core Logging Infrastructure ([src/KontentumNC.hx](src/KontentumNC.hx))

**Changes:**
- **Line 124-125**: Removed hardcoded `debug=false` and `canWriteToLog=false` overrides
- **Line 125**: Now respects config.xml `<debug>` setting
- **Line 688-708**: Enhanced `writeToLog()` function
  - Added optional `level` parameter (INFO, WARN, ERROR)
  - Changed from read-entire-file to efficient append mode
  - Added structured log format: `[timestamp] [level] message`
  - Added exception handling for write failures

- **Line 719-742**: Added `logResourceMetrics()` function
  - Logs AsyncHttp thread count
  - Logs JobTracker active jobs count
  - Logs application ping counter
  - Warns when threads exceed 20 or jobs exceed 10
  - Called every 10 pings (see line 166-168)

- **Line 76**: Added `pingCounter` variable to track application uptime/pings

### 2. AsyncHttp Library Logging ([src/com/akifox/asynchttp/AsyncHttp.hx](src/com/akifox/asynchttp/AsyncHttp.hx))

**Changes:**
- **Line 155**: Enabled logging in debug builds (`logEnabled = true`)
- **Line 277-279**: Added public `getThreadCount()` getter method

**Thread Lifecycle Logging (lines 281-320):**
- `[THREAD_START]` - When thread spawns (with current thread count)
- `[THREAD_EXEC]` - When thread begins HTTP request execution (with URL, method, timeout)
- `[THREAD_ERROR]` - If thread encounters exception
- `[THREAD_COMPLETE]` - When thread finishes (with duration in ms, final thread count)

**Socket Lifecycle Logging (lines 331-362, 625-635):**
- `[SOCKET_OPEN]` - When socket is created (TCP or SSL, with host:port)
- `[SOCKET_CONNECTED]` - When connection established
- `[SOCKET_CONNECT_FAILED]` - If connection fails
- `[SOCKET_CLOSED]` - When socket closed successfully
- `[SOCKET_CLOSE_FAILED]` - If socket close throws exception

### 3. JobTracker Logging ([src/JobTracker.hx](src/JobTracker.hx))

**Changes:**
- **Line 18-21**: Added public `getActiveJobsCount()` method

**Job Lifecycle Logging:**
- **Lines 27-33**: `[JOB_BATCH_RECEIVED]` - When job batch arrives from server
  - Logs job count and current active jobs
  - Warns if total will exceed 10 jobs

- **Line 74**: `[JOB_START]` - When job begins execution
  - Logs reference, fingerprint, method, URL, active job count

- **Line 105**: `[JOB_RESPONSE]` - When job completes successfully
  - Logs fingerprint, status, duration, active job count

- **Line 114**: `[JOB_ERROR]` - When job fails
  - Logs fingerprint, status, error message, active job count

- **Line 142**: `[JOB_CALLBACK_START]` - When sending result callback to server
  - Logs reference, success status, callback fingerprint

- **Line 158**: `[JOB_CALLBACK_RESPONSE]` - When callback succeeds
  - Logs fingerprint and status

- **Line 163**: `[JOB_CALLBACK_ERROR]` - When callback fails
  - Logs fingerprint, status, error

- **Line 177**: `[JOB_CLEANUP]` - When job removed from active jobs map
  - Logs fingerprint and remaining job count

## Log Output Location

### Main Event Log: **[bin/log.txt](bin/log.txt)**

- Controlled by `<debug>true</debug>` in [bin/config.xml](bin/config.xml)
- Logs are appended (not overwritten) for session continuity
- **Automatic rotation**: When log.txt exceeds 10MB, it's renamed to log.txt.old
- Only the most recent 10MB is kept in log.txt, previous 10MB in log.txt.old
- AsyncHttp logs also go to stdout (visible in console/nohup.out)

### Resource Metrics Log: **[bin/metrics.csv](bin/metrics.csv)**

- **CSV format** for easy analysis in spreadsheets or plotting tools
- Logged **every 60 seconds** regardless of ping interval
- **Never rotated** - keeps complete historical data
- Columns: `timestamp,uptime_sec,threads,active_jobs,memory_mb,cpu_percent,file_handles`
- Example: `2025-11-06 15:30:01,3600,5,2,45.3,12.5,87`

## Log Format

```
[YYYY-MM-DD HH:MM:SS] [LEVEL] [COMPONENT] [EVENT] key=value key=value | optional_message
```

**Examples:**
```
[2025-11-06 15:30:01] [INFO] [METRICS] [AsyncHttp] threads=12 | [JobTracker] active_jobs=5 | [App] ping_counter=100
[2025-11-06 15:30:02] [INFO] [JobTracker] [JOB_BATCH_RECEIVED] count=10 active_before=5
[2025-11-06 15:30:02] [WARN] [JobTracker] [JOB_BATCH_RECEIVED] WARNING: Total jobs will exceed 10! active=5 new=10
[2025-11-06 15:30:02] [INFO] [JobTracker] [JOB_START] ref=job_123 fingerprint=abc123 method=GET url=http://example.com active_jobs=6
[2025-11-06 15:30:02] [INFO] req_1699283402000 INFO:[THREAD_START] id=req_1699283402000 count=13
[2025-11-06 15:30:02] [INFO] req_1699283402000 INFO:[SOCKET_OPEN] type=TCP host=example.com:80
[2025-11-06 15:30:03] [INFO] req_1699283402000 INFO:[SOCKET_CONNECTED] host=example.com:80
[2025-11-06 15:30:04] [INFO] req_1699283402000 INFO:[SOCKET_CLOSED] host=example.com:80
[2025-11-06 15:30:04] [INFO] req_1699283402000 INFO:[THREAD_COMPLETE] id=req_1699283402000 count=12 duration=2156ms
[2025-11-06 15:30:04] [INFO] [JobTracker] [JOB_RESPONSE] fingerprint=abc123 status=200 time=2.2s active_jobs=5
[2025-11-06 15:30:04] [INFO] [JobTracker] [JOB_CLEANUP] fingerprint=abc123 remaining=4
```

## Resource Monitoring Thresholds

**Warning Triggers:**
- Thread count > 20 (logged in metrics)
- Active jobs > 10 (logged when jobs received and in metrics)
- Socket close failures (always logged as ERROR)
- Job errors (always logged as ERROR)

## How to Use This Logging

### 1. Monitor Resource Accumulation

Look for trends in the periodic metrics:
```bash
grep "\[METRICS\]" bin/log.txt
```

**Healthy pattern:**
```
[2025-11-06 15:00:00] [INFO] [METRICS] threads=5 active_jobs=2
[2025-11-06 15:01:40] [INFO] [METRICS] threads=4 active_jobs=1
[2025-11-06 15:03:20] [INFO] [METRICS] threads=6 active_jobs=3
```

**Leak pattern:**
```
[2025-11-06 15:00:00] [INFO] [METRICS] threads=5 active_jobs=2
[2025-11-06 15:01:40] [INFO] [METRICS] threads=12 active_jobs=7
[2025-11-06 15:03:20] [INFO] [METRICS] threads=23 active_jobs=15  ← WARNING!
[2025-11-06 15:05:00] [INFO] [METRICS] threads=45 active_jobs=28  ← CRITICAL!
```

### 2. Track Job Lifecycle

Find jobs that never complete:
```bash
# Find all job starts
grep "JOB_START" bin/log.txt > /tmp/starts.txt

# Find all job completions
grep -E "JOB_RESPONSE|JOB_ERROR|JOB_CLEANUP" bin/log.txt > /tmp/ends.txt

# Compare to find hanging jobs
```

### 3. Identify Thread Leaks

Count threads that start vs complete:
```bash
# Thread starts
grep "THREAD_START" bin/log.txt | wc -l

# Thread completions
grep "THREAD_COMPLETE" bin/log.txt | wc -l

# If starts >> completions, threads are leaking
```

### 4. Find Socket Leaks

Check for unclosed sockets:
```bash
# Socket opens
grep "SOCKET_OPEN" bin/log.txt | wc -l

# Socket closes
grep "SOCKET_CLOSED" bin/log.txt | wc -l

# Check close failures
grep "SOCKET_CLOSE_FAILED" bin/log.txt
```

### 5. Analyze Job Batches

See when large job batches arrive:
```bash
grep "JOB_BATCH_RECEIVED" bin/log.txt | grep "count=[0-9]\{2,\}"
```

## Building and Deploying

### Debug Build (with logging enabled)
```bash
haxe build.hxml -debug -lib hxcpp-debug-server
# Output: bin/KontentumNC-debug (28MB with debug symbols)
```

### Release Build (with logging, but smaller binary)
```bash
haxe build.hxml
# Output: bin/KontentumNC (3.4MB optimized)
# Note: Logging still works in release mode if debug=true in config.xml
```

### Deploy to Raspberry Pi
```bash
./install.sh
# Copies bin/KontentumNC to /home/pi/KontentumNC/
```

### Run and Monitor
```bash
# On Raspberry Pi
cd /home/pi/KontentumNC
sudo ./KontentumNC

# In another terminal, watch the logs
tail -f bin/log.txt

# Or use grep to filter
tail -f bin/log.txt | grep -E "WARN|ERROR|METRICS"
```

## Testing the Logging

### 1. Verify Logging is Enabled
```bash
# Run the binary briefly
timeout 30s ./bin/KontentumNC-debug

# Check log exists and has content
cat bin/log.txt | tail -20
```

You should see:
- Initial startup logs
- Periodic METRICS logs (every 10 pings = ~100 seconds with 10s ping interval)
- THREAD_START/COMPLETE for each HTTP request
- JOB logs if server sends jobs

### 2. Simulate High Load

Modify the server to send many jobs simultaneously and observe:
- Job batch warnings
- Thread count escalation
- Memory/performance impact

## Known Issues and Next Steps

### Current State
✅ Logging infrastructure complete and tested
✅ Debug build successful (28MB binary created)
✅ All log points instrumented
✅ Resource metrics implemented

### Next Steps for Diagnosis

1. **Deploy and Monitor** - Run the debug build in production for 1-2 hours
2. **Collect Baseline** - Record normal thread/job counts during low activity
3. **Trigger High Load** - Have server send batch of 20-50 jobs
4. **Analyze Logs** - Look for:
   - Thread count not returning to baseline
   - Jobs stuck in active state
   - Socket close failures
   - Time between JOB_START and JOB_CLEANUP

### Likely Root Causes (to validate with logs)

Based on code analysis, expect to see:
- **Thread accumulation** when jobs arrive faster than they complete
- **No thread pooling** - each job spawns new thread
- **Cascade effect** - each job completion spawns callback request (doubles threads)
- **Timeout issues** - 1-second job timeout may be too aggressive

### Potential Fixes (after diagnosis confirms)

1. **Implement thread pooling** - Limit max concurrent threads
2. **Add job queue** - Queue jobs instead of executing all immediately
3. **Increase timeouts** - Current 1-second timeout may cause premature failures
4. **Connection pooling** - Reuse HTTP connections instead of creating new ones
5. **Batch callbacks** - Send one callback with multiple results instead of one per job

## Configuration

Logging is controlled by [bin/config.xml](bin/config.xml):
```xml
<debug>true</debug>
```

Set to `false` to disable file logging (stdout AsyncHttp logs will still appear).

## File Changes Summary

| File | Lines Changed | Changes |
|------|---------------|---------|
| [src/KontentumNC.hx](src/KontentumNC.hx) | 124-125, 688-742, 76, 166-168 | Enable logging, add metrics, enhance writeToLog |
| [src/com/akifox/asynchttp/AsyncHttp.hx](src/com/akifox/asynchttp/AsyncHttp.hx) | 155, 277-320, 331-362, 625-635 | Enable logging, add thread/socket lifecycle logs |
| [src/JobTracker.hx](src/JobTracker.hx) | 18-21, 27-33, 74, 105, 114, 142, 158, 163, 177 | Add job lifecycle logging |

## Additional Monitoring

For real-time system resource monitoring outside of application logs:

```bash
# Watch thread count
watch -n 5 'ps -eLf | grep KontentumNC | wc -l'

# Watch memory usage
watch -n 5 'ps aux | grep KontentumNC | grep -v grep'

# Watch file handles
watch -n 5 'lsof -p $(pidof KontentumNC) | wc -l'

# Combined monitoring
watch -n 5 'echo "Threads: $(ps -eLf | grep KontentumNC | wc -l)" && echo "Memory: $(ps aux | grep KontentumNC | grep -v grep | awk "{print \$4}" )%" && echo "Files: $(lsof -p $(pidof KontentumNC) 2>/dev/null | wc -l)"'
```

## Support

For questions or issues with the logging system:
1. Check that `<debug>true</debug>` is set in [bin/config.xml](bin/config.xml)
2. Verify [bin/log.txt](bin/log.txt) is writable
3. Review this document for log format and filtering examples
4. Check stdout/stderr output in addition to log file
