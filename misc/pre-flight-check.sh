#!/bin/bash

# If your kernel does not have the /proc/config.gz file, kubeadm will fail
# on pre-flight-check as it thinks important features are missing
# This script checks them for you, so you might ignore kubeadm warnings



echo "=== Kubernetes Preflight Check (container edition) ==="

check_module() {
  local mod=$1
  if lsmod | grep -q "^$mod"; then
    echo "✓ Module $mod loaded"
  elif modprobe -n $mod 2>/dev/null; then
    echo "✗ Module $mod not loaded (but available via modprobe)"
  else
    echo "✗ Module $mod missing (not available on this kernel)"
  fi
}

check_sysctl() {
  local key=$1
  local expected=$2
  local value
  value=$(sysctl -n $key 2>/dev/null || echo "N/A")
  if [ "$value" = "$expected" ]; then
    echo "✓ Sysctl $key=$value"
  else
    echo "✗ Sysctl $key=$value (expected $expected)"
  fi
}

check_cgroup() {
  local name=$1
  if mount | grep -q "cgroup.*$name"; then
    echo "✓ Cgroup $name mounted"
  else
    echo "✗ Cgroup $name missing"
  fi
}

echo
echo "== Kernel modules =="
for mod in overlay br_netfilter nf_conntrack ip_tables ip_vs; do
  check_module $mod
done

echo
echo "== Sysctl settings =="
check_sysctl net.bridge.bridge-nf-call-iptables 1
check_sysctl net.ipv4.ip_forward 1
check_sysctl net.bridge.bridge-nf-call-ip6tables 1

echo "== Cgroups =="

missing=0

if mount | grep -q "type cgroup2"; then
    echo "Detected cgroup v2 (unified hierarchy)"

    available=$(cat /sys/fs/cgroup/cgroup.controllers)
    enabled=$(cat /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null | tr -d ' ')

    for ctrl in cpu memory pids cpuset; do
        if echo "$available" | grep -qw "$ctrl"; then
            if echo "$enabled" | grep -qw "+$ctrl"; then
                echo "✓ Cgroup $ctrl enabled"
            else
                echo "⚠ Cgroup $ctrl available but not enabled in subtree_control"
            fi
        else
            echo "✗ Cgroup $ctrl not available"
            missing=1
        fi
    done

    # Handle devices separately (optional)
    if echo "$available" | grep -qw "devices"; then
        echo "⚠ Cgroup devices available but optional (often masked in containers)"
    else
        echo "⚠ Cgroup devices not available (optional)"
    fi

else
    echo "Detected cgroup v1 (legacy hierarchy)"
    for ctrl in cpu memory pids cpuset; do
        if mount | grep -q "cgroup.*$ctrl"; then
            echo "✓ Cgroup $ctrl mounted"
        else
            echo "✗ Cgroup $ctrl missing"
            missing=1
        fi
    done

    # Handle devices separately (optional)
    if mount | grep -q "cgroup.*devices"; then
        echo "⚠ Cgroup devices mounted but optional"
    else
        echo "⚠ Cgroup devices missing (optional)"
    fi
fi

if [ "$missing" -eq 0 ]; then
    echo "All required cgroup controllers are available"
else
    echo "Some required cgroup controllers are missing!"
fi

