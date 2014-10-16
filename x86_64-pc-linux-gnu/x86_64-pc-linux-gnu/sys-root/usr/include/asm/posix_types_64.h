//SYNO , user space toolchain use __ARCH_I386_POSIX_TYPES_H and _ASM_X86_64_POSIX_TYPES_H , so we need to compatable with them
#if !defined(_ASM_X86_POSIX_TYPES_64_H) &&  !defined(_ASM_X86_64_POSIX_TYPES_H)
#define _ASM_X86_POSIX_TYPES_64_H
#if defined(SYNO_X64) || defined(SYNO_X86)
#define _ASM_X86_64_POSIX_TYPES_H
#endif


/*
 * This file is generally used by user-level software, so you need to
 * be a little careful about namespace pollution etc.  Also, we cannot
 * assume GCC is being used.
 */

typedef unsigned long	__kernel_ino_t;
typedef unsigned int	__kernel_mode_t;
typedef unsigned long	__kernel_nlink_t;
typedef long		__kernel_off_t;
typedef int		__kernel_pid_t;
typedef int		__kernel_ipc_pid_t;
typedef unsigned int	__kernel_uid_t;
typedef unsigned int	__kernel_gid_t;
typedef unsigned long	__kernel_size_t;
typedef long		__kernel_ssize_t;
typedef long		__kernel_ptrdiff_t;
typedef long		__kernel_time_t;
typedef long		__kernel_suseconds_t;
typedef long		__kernel_clock_t;
typedef int		__kernel_timer_t;
typedef int		__kernel_clockid_t;
typedef int		__kernel_daddr_t;
typedef char *		__kernel_caddr_t;
typedef unsigned short	__kernel_uid16_t;
typedef unsigned short	__kernel_gid16_t;

#ifdef __GNUC__
typedef long long	__kernel_loff_t;
#endif

typedef struct {
	int	val[2];
} __kernel_fsid_t;

typedef unsigned short __kernel_old_uid_t;
typedef unsigned short __kernel_old_gid_t;
typedef __kernel_uid_t __kernel_uid32_t;
typedef __kernel_gid_t __kernel_gid32_t;

typedef unsigned long	__kernel_old_dev_t;


#endif /* _ASM_X86_POSIX_TYPES_64_H */
