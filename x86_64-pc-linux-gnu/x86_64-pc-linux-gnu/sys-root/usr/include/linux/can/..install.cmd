cmd_/synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/can/.install := perl scripts/headers_install.pl /synosrc2/GPLSource/bromolow-build/source/linux-3.x/include/linux/can /synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/can x86 bcm.h error.h gw.h netlink.h raw.h; perl scripts/headers_install.pl /synosrc2/GPLSource/bromolow-build/source/linux-3.x/include/linux/can /synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/can x86 ; for F in ; do echo "\#include <asm-generic/$$F>" > /synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/can/$$F; done; touch /synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/can/.install
