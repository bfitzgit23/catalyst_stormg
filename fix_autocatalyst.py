import os
import sys

def patch_autocatalyst():
    print("=== Patching autocatalyst.sh for Docker/WSL Compatibility ===")
    
    script_path = "autocatalyst.sh"
    
    # 1. Safety Check
    if not os.path.exists(script_path):
        print(f"Error: {script_path} not found in the current directory.")
        sys.exit(1)
        
    # 2. Read the script contents
    with open(script_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 3. Identify the problematic remount block
    # We look for the exact string pattern you ran into
    old_block_1 = 'mount -o remount,size=0 /tmp || echo "[!] could not remount /tmp"'
    old_block_2 = 'mount -o remount,size=0 /var/tmp || echo "[!] could not remount /var/tmp"'
    old_block_3 = 'mount -o remount,size=0 /run || echo "[!] could not remount /run"'
    
    # Check if the text matches the exact block shape or a loose variation
    if old_block_1 not in content:
        # Fallback to general replacement if the shell script syntax varies slightly
        old_block_1 = 'mount -o remount,size=0 /tmp || _warn "could not remount /tmp"' # check if already modified
        if "remount,size=0" not in content:
            print("Error: Could not find the tmpfs remount lines in autocatalyst.sh. It might be structured differently.")
            sys.exit(1)

    # 4. Define the safe replacement blocks using the script's internal _warn function
    new_block_1 = 'mount -o remount,size=0 /tmp || _warn "Container context: could not remount /tmp (skipping)"'
    new_block_2 = 'mount -o remount,size=0 /var/tmp || _warn "Container context: could not remount /var/tmp (skipping)"'
    new_block_3 = 'mount -o remount,size=0 /run || _warn "Container context: could not remount /run (skipping)"'

    # Apply substitutions safely
    patched_content = content.replace('mount -o remount,size=0 /tmp || echo "[!] could not remount /tmp"', new_block_1)
    patched_content = patched_content.replace('mount -o remount,size=0 /var/tmp || echo "[!] could not remount /var/tmp"', new_block_2)
    patched_content = patched_content.replace('mount -o remount,size=0 /run || echo "[!] could not remount /run"', new_block_3)

    # 5. Write the file back out preserving Linux LF endings
    with open(script_path, "wb") as f:
        f.write(patched_content.encode("utf-8"))
        
    print("[+] Successfully patched autocatalyst.sh!")
    print("[*] Mount failures are now non-fatal warnings inside your container environments.")

if __name__ == "__main__":
    patch_autocatalyst()
