#!/bin/bash

# --- 1. Global Variables ---
# Use an environment variable to store the core count globally
# This avoids running 'nproc' repeatedly.
CORE_COUNT=0
# Variables to hold OS info
OS_NAME="Unknown"
OS_VERSION="Unknown"

# --- 2. Check Function ---
# Called by Netdata once to see if the plugin should run.
system_core_count_check() {
    # Get core count once
    CORE_COUNT=$(nproc 2>/dev/null)
    
    # Check if CORE_COUNT is a positive integer
    if ! [[ "$CORE_COUNT" =~ ^[0-9]+$ ]] || [ "$CORE_COUNT" -le 0 ]; then
        # If check fails, return 1 to disable the plugin
        return 1
    fi

    # --- Fetch OS Information ---
    # The /etc/os-release file is a shell-compatible fragment, 
    # so we can 'source' it in a subshell to load its variables (like NAME and VERSION).
    if [ -f /etc/os-release ]; then
        # Source the file in a subshell, then extract and store the variables.
        # We use a subshell to avoid polluting the main script's environment 
        # with all variables from /etc/os-release, though for a Netdata plugin it's less critical.
        OS_NAME=$(source /etc/os-release >/dev/null 2>&1 && echo "$NAME")
        
        # Using PRETTY_NAME is usually more descriptive than VERSION
        OS_VERSION=$(source /etc/os-release >/dev/null 2>&1 && echo "$PRETTY_NAME")

        # Fallback to VERSION if PRETTY_NAME is empty
        if [ -z "$OS_VERSION" ]; then
            OS_VERSION=$(source /etc/os-release >/dev/null 2>&1 && echo "$VERSION")
        fi

        # Use the NAME or PRETTY_NAME directly if variables are still empty
        [ -z "$OS_NAME" ] && OS_NAME="Unknown OS"
        [ -z "$OS_VERSION" ] && OS_VERSION="Unknown Version"
    fi
    
    # If check passes, return 0 to enable the plugin
    return 0
}

# --- 3. Create Function ---
# Called once to define the chart structure.
system_core_count_create() {
    cat <<EOF
CHART system.total_cores '' "Total CPU Cores" "Cores" system.capacity total_cores 1000 1
CLABEL os.name "$OS_NAME" OS_Name
CLABEL os.version "$OS_VERSION" OS_Version
DIMENSION static_cores cores absolute 1 1
EOF
    # Note: We use DIMENSION 'cores' as the name, and a divisor of 1 
    # since CORE_COUNT is already an integer in Cores.
    return 0
}

# --- 4. Update Function ---
# Called repeatedly by the Netdata daemon to get the new value.
# Since this value is static, it just outputs the stored CORE_COUNT.
system_core_count_update() {
    cat <<EOF
BEGIN system.total_cores
SET static_cores $CORE_COUNT
END
EOF
    return 0
}
