cmd_/synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/byteorder/.install := perl scripts/headers_install.pl /synosrc2/GPLSource/bromolow-build/source/linux-3.x/include/linux/byteorder /synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/byteorder x86 big_endian.h little_endian.h; perl scripts/headers_install.pl /synosrc2/GPLSource/bromolow-build/source/linux-3.x/include/linux/byteorder /synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/byteorder x86 ; for F in ; do echo "\#include <asm-generic/$$F>" > /synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/byteorder/$$F; done; touch /synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/byteorder/.install
