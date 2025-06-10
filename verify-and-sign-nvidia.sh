#!/bin/bash

# If you have a .crt instead of .der, you'll need to create a .der from the .crt:
# sudo openssl x509 -in MOK.crt -outform der -out MOK.der

# Set key filenames
KEY="MOK.key"
CERT="MOK.der"

# Check if required keys exist in the current directory
if [[ ! -f "$KEY" || ! -f "$CERT" ]]; then
    echo "❌ Error: MOK keys not found in the current directory!"
    echo "Ensure that both $KEY and $CERT are present before running this script."
    exit 1
fi

echo "✅ MOK keys found. Proceeding with signature verification and signing..."

# Function to check if a module belongs to NVIDIA
# This function is now used to filter modules in the main loop
is_nvidia_module() {
    local file=$1
    # Check modinfo output for "nvidia" in relevant fields or description
    # This is a more direct way to determine if it's an NVIDIA module
    modinfo "$file" 2>/dev/null | grep -qiE "author:.*nvidia|description:.*nvidia|alias:.*nvidia"
    if [[ $? -eq 0 ]]; then
        return 0  # NVIDIA module
    else
        return 1  # Not an NVIDIA module
    fi
}

# Function to check if a file is signed and sign if necessary
verify_signature() {
    local file=$1
    if [[ -f "$file" ]]; then
        if ! pesign -S -i "$file" -o /dev/null &>/dev/null; then
            echo "❌ Found unsigned: $file"
            sign_file "$file"
        else
            echo "✅ Found signed: $file"
        fi
    fi
}

# Function to sign a file
sign_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        echo "🔒 Attempting to sign: $file"
        # Execute the sign-file script and check its exit status
        /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 "$KEY" "$CERT" "$file"
        if [[ $? -eq 0 ]]; then
            echo "✅ Successfully signed: $file"
        else
            echo "🔥 Failed to sign: $file. Check permissions or key validity." >&2
        fi
    else
        echo "⚠️ Skipping: $file (not found)"
    fi
}

# Find all kernel modules and then filter for NVIDIA modules in the loop
# This approach is more robust than trying to parse modinfo output directly in find.
ALL_KO_FILES=$(find /lib/modules/$(uname -r) -type f -name "*.ko")

if [[ -z "$ALL_KO_FILES" ]]; then
    echo "⚠️ No kernel modules (.ko files) found for the current kernel."
    exit 0
fi

echo "🔎 Searching for NVIDIA kernel modules to sign..."

for file in $ALL_KO_FILES; do
    if is_nvidia_module "$file"; then
        verify_signature "$file"
    fi
done

echo "✅ Signing process completed. Reboot your system to verify Secure Boot compliance."

exit 0
