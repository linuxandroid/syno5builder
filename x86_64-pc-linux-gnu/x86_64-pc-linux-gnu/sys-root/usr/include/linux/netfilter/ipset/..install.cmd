cmd_/synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/netfilter/ipset/.install := perl scripts/headers_install.pl /synosrc2/GPLSource/bromolow-build/source/linux-3.x/include/linux/netfilter/ipset /synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/netfilter/ipset x86 ip_set.h ip_set_bitmap.h ip_set_hash.h ip_set_list.h; perl scripts/headers_install.pl /synosrc2/GPLSource/bromolow-build/source/linux-3.x/include/linux/netfilter/ipset /synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/netfilter/ipset x86 ; for F in ; do echo "\#include <asm-generic/$$F>" > /synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/netfilter/ipset/$$F; done; touch /synosrc2/GPLSource/bromolow-build/source/linux-3.x/usr/include/linux/netfilter/ipset/.install
