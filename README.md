# Ubuntu Autoinstall — macOS, Windows & Linux

This guide prepares a **NoCloud seed ISO (`seed.iso`)** to automate installation of **Ubuntu Server 24.04 LTS** in a virtual machine. The host computer may run **macOS, Windows, or Linux**.

> **Safety:** The `direct` storage layout erases/partitions the VM's selected installation disk. Use a new, disposable virtual disk; never attach a disk containing important data.

## 1. Requirements and architecture

- Ubuntu Server 24.04 LTS installer ISO: https://ubuntu.com/download/server
- A virtualization program: VirtualBox (compatible x86-64 hosts), VMware, or UTM (particularly useful on Apple Silicon).
- Approximately **2 vCPUs, 4 GB RAM, 25 GB empty virtual disk**, and internet connectivity.
- A text editor such as VS Code.

**Match the guest architecture to your virtualizer:** Intel/AMD x86-64 machines generally use the Ubuntu **amd64** ISO; Apple Silicon Macs running an ARM virtual machine use **arm64**. Do not expect an amd64 ISO to boot in an ARM VM without emulation.

If you cloned a repository already containing `user-data` and `meta-data`, review those files and skip to **Section 4**.

## 2. Create the project files

Create a folder called `linux-autoinstall-demo` in your preferred location, containing two **extensionless** UTF-8 text files:

```text
linux-autoinstall-demo/
├── user-data
└── meta-data
```

On macOS or Linux:

```bash
mkdir -p ~/linux-autoinstall-demo
cd ~/linux-autoinstall-demo
touch user-data meta-data
```

On Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$HOME\linux-autoinstall-demo" | Out-Null
Set-Location "$HOME\linux-autoinstall-demo"
New-Item -ItemType File -Force user-data, meta-data | Out-Null
```

### `user-data`

Paste this content into `user-data` (the `#cloud-config` header must be the first line):

```yaml
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  identity:
    hostname: linux-demo
    username: student
    password: "$6$REPLACE_WITH_A_VALID_SHA512_CRYPT_HASH"
  storage:
    layout:
      name: direct
  ssh:
    install-server: true
    allow-pw: true
  packages:
    - git
    - curl
    - vim
    - nginx
  updates: security
  late-commands:
    - curtin in-target --target=/target -- systemctl enable nginx
```

Replace the password placeholder with a **SHA-512 crypt** password hash. An easy cross-platform way is to run the following **inside an Ubuntu environment** (an existing VM, Ubuntu live environment, or WSL Ubuntu on Windows):

```bash
openssl passwd -6
```

Enter a demo password and paste the resulting `$6$...` hash between the existing double quotes. Do not paste the plain-text password. Some macOS OpenSSL builds do not support `-6`; run it inside Ubuntu instead. **Do not commit real password hashes or secrets to a public repository.** Password-based SSH is enabled here for a disposable lab; production systems should use SSH keys.

### `meta-data`

```yaml
instance-id: linux-autoinstall-demo-001
local-hostname: linux-demo
```

## 3. How the seed ISO works

The seed ISO contains `user-data` and `meta-data` **at its root**, and its volume label must be **`cidata`**. Ubuntu's cloud-init NoCloud data source uses these to discover the Autoinstall instructions. This ISO is **separate** from the Ubuntu Server installer ISO.

## 4. Generate `seed.iso` on your host OS

Choose **one** method below. Run commands from the directory containing `user-data` and `meta-data`.

### Option A — macOS (Homebrew)

```bash
brew install cdrtools
mkisofs -output seed.iso -volid cidata -joliet -rock user-data meta-data
ls -lh seed.iso
```

If Homebrew is not installed: https://brew.sh/

Optional inspection:

```bash
hdiutil attach -readonly seed.iso
# Inspect the mounted volume; then unmount using the path shown by hdiutil:
hdiutil detach /Volumes/cidata
```

The mount path may differ.

### Option B — Windows (PowerShell + WSL Ubuntu)

WSL is a convenient, repeatable way to generate the ISO. From **PowerShell as Administrator**, install WSL if it is not already available:

```powershell
wsl --install -d Ubuntu
```

Restart Windows if requested, then launch Ubuntu and complete its initial user setup. **Inside the WSL Ubuntu terminal**, install the tools:

```bash
sudo apt update
sudo apt install -y cloud-image-utils
```

Access the Windows project folder from WSL (replace `WINDOWS_USERNAME`):

```bash
cd /mnt/c/Users/WINDOWS_USERNAME/linux-autoinstall-demo
cloud-localds seed.iso user-data meta-data
ls -lh seed.iso
```

If your Windows profile or project is on another drive/path, locate it under `/mnt/<drive-letter>/...`. The resulting `seed.iso` will appear in the Windows project folder.

**Alternative:** Use a Linux VM instead of WSL and run the Linux method below, then copy `seed.iso` back to Windows.

### Option C — Linux (Ubuntu/Debian host)

```bash
sudo apt update
sudo apt install -y cloud-image-utils
cd ~/linux-autoinstall-demo
cloud-localds seed.iso user-data meta-data
ls -lh seed.iso
```

On other Linux distributions, install `xorriso`/`genisoimage` or the distribution's equivalent and generate an ISO with the **`cidata`** label, containing the two files at the root. For example, where `genisoimage` is available:

```bash
genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data
```

## 5. Verify the ISO

At minimum, confirm that `seed.iso` exists and that it contains both `user-data` and `meta-data` at the root.

- **macOS:** `hdiutil attach -readonly seed.iso`, inspect the mounted volume, then detach it.
- **Windows:** Right-click `seed.iso` → **Mount** (if supported), inspect the mounted drive, then **Eject**. Alternatively inspect it with an archive tool that supports ISO files.
- **Linux:** `isoinfo -i seed.iso -f` (if `isoinfo` is installed), or mount the ISO read-only and inspect it.

If you used `cloud-localds` with its default settings or `mkisofs`/`genisoimage` with `-volid cidata`, the seed has the expected label.

## 6. Create the VM and attach both ISOs

1. Create a **new** Ubuntu Server VM with approximately **2 vCPUs, 4 GB RAM, and a new 25 GB virtual disk**.
2. Attach the **Ubuntu Server installer ISO** as boot media.
3. Attach **`seed.iso`** as a **second virtual CD/DVD drive**. If your virtualizer only supports one optical drive, add another virtual optical device or use a supported alternative for passing NoCloud data.
4. Disable or skip any virtualization software's **own** unattended-install feature. Ubuntu Autoinstall should control this installation.
5. Use NAT networking for the demo, if available.

## 7. Boot with Autoinstall enabled

Start the VM. At the Ubuntu installer GRUB menu, highlight **Try or Install Ubuntu Server** and press `e` to edit its boot entry. On the line starting with `linux`, add `autoinstall` among the kernel arguments, typically **before the final `---` marker**:

```text
linux /casper/vmlinuz ... autoinstall ---
```

Keep the existing arguments unchanged. Boot the edited entry with `Ctrl+X` or `F10` (as indicated by GRUB).

## 8. Verify the installation

Log in with `student` and the password corresponding to your configured hash. Run:

```bash
cat /etc/os-release
hostnamectl
whoami
git --version
curl --version
nginx -v
systemctl status nginx
```

Expected results: Ubuntu Server installed, hostname `linux-demo`, user `student`, requested packages installed, and Nginx enabled/running. If Nginx is not running, inspect `sudo journalctl -u nginx -n 30`.

## References

- Ubuntu Server downloads: https://ubuntu.com/download/server
- Ubuntu Autoinstall documentation: https://canonical-subiquity.readthedocs-hosted.com/en/latest/intro-to-autoinstall.html
- Ubuntu Autoinstall quick start: https://canonical-subiquity.readthedocs-hosted.com/en/latest/howto/autoinstall-quickstart.html
- cloud-init NoCloud documentation: https://docs.cloud-init.io/en/latest/reference/datasources/nocloud.html
