# Platform delivery design

One pipeline, many packers:

```
mmdebstrap (amd64, arm64[, i386-lite])
   └─ rootfs.tar.zst  ──┬─ live ISO + Calamares ........ PC / ARM64 UEFI hardware, dual boot
                        ├─ RPi image (debos) ........... Raspberry Pi 4/5/400/500
                        ├─ .wsl tarball ................ Windows WSL2
                        ├─ .vhdx / .ova / qcow2 ........ Hyper-V, VirtualBox, QEMU, cloud
                        ├─ .utm bundle ................. macOS (UTM), iOS (UTM SE, lite)
                        ├─ proot-distro rootfs ......... Android / Termux (+ Termux:X11)
                        ├─ AVF disk image .............. Android 15+ Linux Terminal (validate)
                        ├─ OCI image ................... Docker/Podman, Codespaces, KasmVNC web desktop
                        └─ CheerpX ext2 (i386 lite) .... in-browser WebVM edition
```

Install commands for each target will be written in Phase 4, once real artifacts exist.
