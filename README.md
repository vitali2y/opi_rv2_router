### Orange Pi RV2 Home WiFi/Wired Router

<img src="doc/opi_rv2_painting.png" alt="Orange Pi RV2 painting" style="width:300px;"/>

Fast and simple way to make your [Orange Pi RV2](http://www.orangepi.org/orangepiwiki/index.php/Orange_Pi_RV2) SBC device as a home WiFi and wired router based on `Ubuntu 24.04`, in next few steps (currently I use `Linux Mint 22.1` as a host box):

1. SD Card formatting (`Ubuntu` uses less 2 Gb of space):
   ```shell
   ➜ mintstick -m format
   ```

2. Download `Ubuntu Image` from `orangepi.org`'s [Official Images](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-Pi-RV2.html) (I used `Orangepirv2_1.0.0_ubuntu_noble_server_linux6.6.63.img` server image), unarchive it, and check MD5 checksum:
   ```shell
   ➜ 7z e ./Orangepirv2_1.0.0_ubuntu_noble_server_linux6.6.63.7z
   ➜ md5sum ./Orangepirv2_1.0.0_ubuntu_noble_server_linux6.6.63.img
   cd9ee20ec7dc30abe701ec48a1952220  Orangepirv2_1.0.0_ubuntu_noble_server_linux6.6.63.img
   ➜
   ```

3. Write image to SD Card, install card to device, and reboot:
   ```shell
   ➜ mintstick -m iso
   ```

4. [Copy public key](https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys-on-ubuntu-20-04#step-2-copying-the-public-key-to-your-ubuntu-server) to device (optional: you will not need to enter password anymore) :
   ```shell
   ➜ ssh-copy-id orangepi@orangepirv2
   ```

    **IMPORTANT:** be aware that default `orangepi` password for `orangepi` user has to be changed ASAP!

5. Copy `install.sh` script to device:

   ```shell
   ➜ scp ./install.sh orangepi@orangepirv2:~
   ```

6. Login to your device from host:
   ```shell
   ➜ ssh orangepi@orangepirv2
   ```

7. Run installation script - do not forget to specify WiFi hotspot name and WiFi password as two mandatory parameters:
   ```shell
   orangepi@orangepirv2:~$ sudo ./install.sh <wifi_name> <wifi_password>
   ```

8. Reboot router:
   ```shell
   orangepi@orangepirv2:~$ sudo reboot
   ```

9. On your host configure `DHCP` (under `Network Manager`) manually:
   * IP: *192.168.10.10*,
   * netmask: *255.255.255.0*,
   * gateway: *192.168.10.1*,
   * DNS: *192.168.10.1,8.8.8.8*.

   Connect host's (LAN) cable to router's `end1` (left from top) port.

   Connect Internet (WAN) cable to another router's `end0` (right from top) port.

   Router's WiFi hotspot is available as `<wifi_name>`!

   Done!

10. You can always SSH to your new `Orange Pi RV2` router from host box (optional):
    ```shell
    ➜ ssh orangepi@192.168.10.1
    ```
