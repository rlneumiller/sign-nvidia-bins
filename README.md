# **Secure Boot NVIDIA Kernel Module Signing Script**

This script automates the process of signing NVIDIA kernel modules to ensure they can be loaded successfully on systems with Secure Boot enabled.

## **🚀 Purpose**

When Secure Boot is active on a Linux system, unsigned kernel modules are typically blocked from loading. Proprietary NVIDIA drivers often come as unsigned kernel modules, especially if you build them yourself, as I do, which can prevent the graphics card from functioning correctly. This script addresses this by finding NVIDIA kernel modules and signing them with a user-provided Machine Owner Key (MOK). Once signed and the MOK is enrolled in your UEFI firmware, these modules will be trusted and allowed to load.

## **🛠️ Prerequisites**

Before running this script, ensure you have the following:

1. **MOK Keys:** A private key (MOK.key) and its corresponding DER-encoded public certificate (MOK.der). This script expects the *.key & *.der files **to be in the same directory** as the script when you run it.  
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

   You will be prompted to set a password. After running this, **reboot your system**, and a Blue screen (MOK management screen) will appear during boot. Follow the (often challenging to understand) instructions to enroll the key using the password you set.  In my case the mok utility appears to only support the fat32 filesytem, so I copy the signing keys under the /boot/efi path, which is mapped to a fat32 partition during the debian install.

6. **Reboot:** After the script completes and you've enrolled your MOK (if necessary), reboot your system to allow the signed modules to load.

## **📚 Notes & References**

* [Signing Kernel Modules for Secure Boot](https://www.guyrutenberg.com/2022/09/29/signing-kernel-modules-for-secure-boot/) - A detailed guide on kernel module signing by Guy Rutenberg

