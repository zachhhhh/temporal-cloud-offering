#!/usr/bin/env python3
"""
Aggressive ARM Instance Retry Script
Tries to create an ARM instance every 30 seconds until successful.
Based on hitrov/oci-arm-host-capacity approach.
"""

import subprocess
import json
import time
import os
from datetime import datetime

# Configuration
CONFIG = {
    "compartment_id": "ocid1.tenancy.oc1..aaaaaaaalbigkh7wajpf7ew4h3os6hkf2bif5ttsuql37lfinty6oz6mkokq",
    "availability_domain": "ldIz:AP-SINGAPORE-1-AD-1",
    "subnet_id": "ocid1.subnet.oc1.ap-singapore-1.aaaaaaaazjtikjubfkewtwr2slt6ytfayuuxxkocibvolyb3i2kwoqjmgkcq",
    "image_id": "ocid1.image.oc1.ap-singapore-1.aaaaaaaaggp6h5vvqqrisqfdyqj4irgmqjd5fs56mo2ctqrr5snx3okv7yka",
    "ssh_key_path": os.path.expanduser("~/.ssh/oracle_temporal.pub"),
    "shape": "VM.Standard.A1.Flex",
    "ocpus": 4,
    "memory_gb": 24,
    "display_name": "temporal-cloud-arm",
    "retry_interval": 30,  # seconds
}

os.environ["SUPPRESS_LABEL_WARNING"] = "True"

def log(msg):
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}")

def try_create_instance():
    """Attempt to create ARM instance"""
    cmd = [
        "oci", "compute", "instance", "launch",
        "--compartment-id", CONFIG["compartment_id"],
        "--availability-domain", CONFIG["availability_domain"],
        "--shape", CONFIG["shape"],
        "--shape-config", json.dumps({
            "ocpus": CONFIG["ocpus"],
            "memoryInGBs": CONFIG["memory_gb"]
        }),
        "--image-id", CONFIG["image_id"],
        "--subnet-id", CONFIG["subnet_id"],
        "--display-name", CONFIG["display_name"],
        "--assign-public-ip", "true",
        "--ssh-authorized-keys-file", CONFIG["ssh_key_path"],
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout, result.stderr, result.returncode

def get_instance_ip(instance_id):
    """Get public IP of instance"""
    time.sleep(60)  # Wait for IP assignment
    cmd = [
        "oci", "compute", "instance", "list-vnics",
        "--instance-id", instance_id,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        data = json.loads(result.stdout)
        return data["data"][0]["public-ip"]
    return None

def main():
    print("=" * 60)
    print("  ARM Instance Aggressive Retry Script")
    print("=" * 60)
    print(f"  Shape: {CONFIG['shape']}")
    print(f"  OCPUs: {CONFIG['ocpus']}")
    print(f"  Memory: {CONFIG['memory_gb']}GB")
    print(f"  Retry interval: {CONFIG['retry_interval']}s")
    print()
    print("  This script will keep trying until successful.")
    print("  Press Ctrl+C to stop.")
    print("=" * 60)
    print()
    
    attempt = 0
    while True:
        attempt += 1
        log(f"Attempt {attempt}...")
        
        stdout, stderr, code = try_create_instance()
        
        if "Out of host capacity" in stdout or "Out of host capacity" in stderr:
            log("❌ Out of capacity. Retrying...")
        elif code == 0 and "lifecycle-state" in stdout:
            log("✅ SUCCESS! Instance created!")
            
            data = json.loads(stdout)["data"]
            instance_id = data["id"]
            
            print()
            print("=" * 60)
            print("  🎉 ARM INSTANCE CREATED!")
            print("=" * 60)
            print(f"  Instance ID: {instance_id}")
            print(f"  Shape: {data['shape']}")
            print(f"  OCPUs: {data['shape-config']['ocpus']}")
            print(f"  Memory: {data['shape-config']['memory-in-gbs']}GB")
            print()
            
            log("Waiting for public IP...")
            public_ip = get_instance_ip(instance_id)
            
            if public_ip:
                print(f"  Public IP: {public_ip}")
                print()
                print("  Next steps:")
                print(f"    ssh -i ~/.ssh/oracle_temporal ubuntu@{public_ip}")
                print(f"    ./setup-k3s-arm.sh {public_ip}")
                
                # Save to file
                with open("arm-instance.env", "w") as f:
                    f.write(f"ARM_INSTANCE_OCID={instance_id}\n")
                    f.write(f"ARM_PUBLIC_IP={public_ip}\n")
                    f.write(f"ARM_OCPUS={CONFIG['ocpus']}\n")
                    f.write(f"ARM_MEMORY_GB={CONFIG['memory_gb']}\n")
                
                print()
                print("  Instance info saved to arm-instance.env")
            
            return 0
        else:
            log(f"⚠️ Unexpected response (code={code})")
            if stderr:
                print(f"    stderr: {stderr[:200]}")
        
        time.sleep(CONFIG["retry_interval"])

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nStopped by user.")
