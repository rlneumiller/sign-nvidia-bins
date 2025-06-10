# **Secure Boot NVIDIA Kernel Module Signing Script**

This script automates the process of signing NVIDIA kernel modules to ensure they can be loaded successfully on systems with Secure Boot enabled.

## **🚀 Purpose**

When Secure Boot is active on a Linux system, unsigned kernel modules are typically blocked from loading. Proprietary NVIDIA drivers often come as unsigned kernel modules, which can prevent the graphics card from functioning correctly. This script addresses this by finding NVIDIA kernel modules and signing them with a user-provided Machine Owner Key (MOK). Once signed and the MOK is enrolled in your UEFI firmware, these modules will be trusted and allowed to load.

## **🛠️ Prerequisites**

Before running this script, ensure you have the following:

1. **MOK Keys:** A private key (MOK.key) and its corresponding DER-encoded public certificate (MOK.der). These files **must be in the same directory** as the script when you run it.  
   * If you only have a .crt file, you can convert it to .der using OpenSSL:  
     sudo openssl x509 \-in MOK.crt \-outform der \-out MOK.der

2. **pesign utility:** This tool is used to verify signatures. Install it if you don't have it (e.g., sudo apt install pesign on Debian/Ubuntu, sudo dnf install pesign on Fedora).  
3. **Kernel Headers:** The kernel headers for your currently running kernel must be installed, as they contain the sign-file script used for signing. The script expects them at /usr/src/linux-headers-$(uname \-r)/scripts/sign-file.  
4. **Root Privileges:** The script modifies files in /lib/modules/ and uses sign-file, both of which require root privileges. You must run the script with sudo.

## **📜 Script Usage**

1. **Place Keys:** Ensure MOK.key and MOK.der are in the same directory as this script.  
2. **Make Executable:**  
   chmod \+x sign\_nvidia\_modules.sh \# Or whatever you name the script

3. **Run the Script:**  
   sudo ./sign\_nvidia\_modules.sh

4. **Enroll MOK (Crucial\!):** If you haven't already, you *must* enroll your MOK.der public key into your UEFI firmware's MOK list. This is typically done using mokutil.  
   sudo mokutil \--import MOK.der

   You will be prompted to set a password. After running this, **reboot your system**, and a Blue screen (MOK management screen) will appear during boot. Follow the instructions to enroll the key using the password you set.  
5. **Reboot:** After the script completes and you've enrolled your MOK (if necessary), reboot your system to allow the signed modules to load.

## **📝 The Script**

Here is the script itself:

\#\!/bin/bash

\# If you have a .crt instead of .der, you'll need to create a .der from the .crt:  
\# sudo openssl x509 \-in MOK.crt \-outform der \-out MOK.der

\# Set key filenames  
KEY="MOK.key"  
CERT="MOK.der"

\# Check if required keys exist in the current directory  
if \[\[ \! \-f "$KEY" || \! \-f "$CERT" \]\]; then  
    echo "❌ Error: MOK keys not found in the current directory\!"  
    echo "Ensure that both $KEY and $CERT are present before running this script."  
    exit 1  
fi

echo "✅ MOK keys found. Proceeding with signature verification and signing..."

\# Function to check if a module belongs to NVIDIA  
\# This function is now used to filter modules in the main loop  
is\_nvidia\_module() {  
    local file=$1  
    \# Check modinfo output for "nvidia" in relevant fields or description  
    \# This is a more direct way to determine if it's an NVIDIA module  
    modinfo "$file" 2\>/dev/null | grep \-qiE "author:.\*nvidia|description:.\*nvidia|alias:.\*nvidia"  
    if \[\[ $? \-eq 0 \]\]; then  
        return 0  \# NVIDIA module  
    else  
        return 1  \# Not an NVIDIA module  
    fi  
}

\# Function to check if a file is signed and sign if necessary  
verify\_signature() {  
    local file=$1  
    if \[\[ \-f "$file" \]\]; then  
        if \! pesign \-S \-i "$file" \-o /dev/null &\>/dev/null; then  
            echo "❌ Found unsigned: $file"  
            sign\_file "$file"  
        else  
            echo "✅ Found signed: $file"  
        fi  
    fi  
}

\# Function to sign a file  
sign\_file() {  
    local file=$1  
    if \[\[ \-f "$file" \]\]; then  
        echo "🔒 Attempting to sign: $file"  
        \# Execute the sign-file script and check its exit status  
        /usr/src/linux-headers-$(uname \-r)/scripts/sign-file sha256 "$KEY" "$CERT" "$file"  
        if \[\[ $? \-eq 0 \]\]; then  
            echo "✅ Successfully signed: $file"  
        else  
            echo "🔥 Failed to sign: $file. Check permissions or key validity." \>&2  
        fi  
    else  
        echo "⚠️ Skipping: $file (not found)"  
    fi  
}

\# Find all kernel modules and then filter for NVIDIA modules in the loop  
\# This approach is more robust than trying to parse modinfo output directly in find.  
ALL\_KO\_FILES=$(find /lib/modules/$(uname \-r) \-type f \-name "\*.ko")

if \[\[ \-z "$ALL\_KO\_FILES" \]\]; then  
    echo "⚠️ No kernel modules (.ko files) found for the current kernel."  
    exit 0  
fi

echo "🔎 Searching for NVIDIA kernel modules to sign..."

for file in $ALL\_KO\_FILES; do  
    if is\_nvidia\_module "$file"; then  
        verify\_signature "$file"  
    fi  
done

echo "✅ Signing process completed. Reboot your system to verify Secure Boot compliance."

exit 0  
