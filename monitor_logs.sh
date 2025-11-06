#!/bin/bash
# Monitor KontentumNC logs for resource issues

LOG_FILE="bin/log.txt"

echo "=================================="
echo "KontentumNC Log Monitor"
echo "=================================="
echo ""

# Check if process is running
if pgrep -x "KontentumNC" > /dev/null; then
    echo "✓ KontentumNC is running (PID: $(pgrep -x KontentumNC))"
    echo ""
else
    echo "✗ KontentumNC is not running"
    echo ""
fi

# Show latest metrics
echo "Latest Resource Metrics:"
echo "------------------------"
grep "\[METRICS\]" "$LOG_FILE" | tail -5
echo ""

# Count warnings
echo "Warning Summary:"
echo "----------------"
WARN_COUNT=$(grep -c "\[WARN\]" "$LOG_FILE")
ERROR_COUNT=$(grep -c "\[ERROR\]" "$LOG_FILE")
echo "Warnings: $WARN_COUNT"
echo "Errors: $ERROR_COUNT"
echo ""

# Show recent warnings/errors
if [ $WARN_COUNT -gt 0 ] || [ $ERROR_COUNT -gt 0 ]; then
    echo "Recent Warnings/Errors (last 10):"
    echo "----------------------------------"
    grep -E "\[WARN\]|\[ERROR\]" "$LOG_FILE" | tail -10
    echo ""
fi

# Job statistics
echo "Job Statistics:"
echo "---------------"
BATCH_COUNT=$(grep -c "JOB_BATCH_RECEIVED" "$LOG_FILE")
JOB_START=$(grep -c "JOB_START" "$LOG_FILE")
JOB_COMPLETE=$(grep -c "JOB_CLEANUP" "$LOG_FILE")
JOB_ERROR=$(grep -c "JOB_ERROR" "$LOG_FILE")

echo "Batches received: $BATCH_COUNT"
echo "Jobs started: $JOB_START"
echo "Jobs completed: $JOB_COMPLETE"
echo "Jobs failed: $JOB_ERROR"

if [ $JOB_START -gt $JOB_COMPLETE ]; then
    STUCK=$((JOB_START - JOB_COMPLETE))
    echo "⚠ Potential stuck jobs: $STUCK"
fi
echo ""

# System resources (if running)
if pgrep -x "KontentumNC" > /dev/null; then
    echo "System Resources:"
    echo "-----------------"
    PID=$(pgrep -x KontentumNC)

    # Thread count
    THREADS=$(ps -eLf | grep KontentumNC | grep -v grep | wc -l)
    echo "Threads: $THREADS"

    # Memory usage
    MEM=$(ps aux | grep KontentumNC | grep -v grep | awk '{print $4"%"}')
    echo "Memory: $MEM"

    # File handles
    if command -v lsof > /dev/null 2>&1; then
        FILES=$(lsof -p $PID 2>/dev/null | wc -l)
        echo "File handles: $FILES"
    fi
    echo ""
fi

echo "=================================="
echo "To watch logs in real-time:"
echo "  tail -f $LOG_FILE"
echo ""
echo "To filter for issues:"
echo "  tail -f $LOG_FILE | grep -E 'WARN|ERROR|METRICS'"
echo "=================================="
