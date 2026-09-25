#!/bin/sh
set -eu

/iris-main &
IRIS_MAIN_PID=$!

shutdown() {
    kill -TERM "$IRIS_MAIN_PID" 2>/dev/null || true
    wait "$IRIS_MAIN_PID" 2>/dev/null || true
}

trap shutdown TERM INT

echo "Waiting for IRIS to become ready..."

READY=0
i=0

while [ "$i" -lt 90 ]; do
    if printf 'Halt\n' | iris session IRIS -U USER >/dev/null 2>&1; then
        READY=1
        break
    fi

    if ! kill -0 "$IRIS_MAIN_PID" 2>/dev/null; then
        echo "IRIS main process exited during startup."
        wait "$IRIS_MAIN_PID" || true
        exit 1
    fi

    i=$((i + 1))
    sleep 1
done

if [ "$READY" -ne 1 ]; then
    echo "IRIS did not become ready within 90 seconds."
    shutdown
    exit 1
fi

echo "IRIS is ready."
echo "Bootstrapping IRIS Incident Memory..."

if ! iris session IRIS -U USER < /app/iris.script; then
    echo "IRIS Incident Memory bootstrap failed."
    shutdown
    exit 1
fi

echo "IRIS Incident Memory bootstrap complete."

wait "$IRIS_MAIN_PID"
