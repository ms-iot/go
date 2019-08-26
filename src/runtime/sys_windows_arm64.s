// Copyright 2018 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "go_asm.h"
#include "go_tls.h"
#include "tls_arm64.h"
#include "textflag.h"

//todo(ragav): adapt for arm64

// void runtime·asmstdcall(void *c);
TEXT runtime·asmstdcall(SB),NOSPLIT|NOFRAME,$0
	RET

TEXT runtime·badsignal2(SB),NOSPLIT|NOFRAME,$0
	RET

TEXT runtime·getlasterror(SB),NOSPLIT,$0
	RET

TEXT runtime·setlasterror(SB),NOSPLIT|NOFRAME,$0
	RET

// Called by Windows as a Vectored Exception Handler (VEH).
// First argument is pointer to struct containing
// exception record and context pointers.
// Handler function is stored in R1
// Return 0 for 'not handled', -1 for handled.
// int32_t sigtramp(
//     PEXCEPTION_POINTERS ExceptionInfo,
//     func *GoExceptionHandler);
TEXT runtime·sigtramp(SB),NOSPLIT|NOFRAME,$0
	RET

//
// Trampoline to resume execution from exception handler.
// This is part of the control flow guard workaround.
// It switches stacks and jumps to the continuation address.
//
TEXT runtime·returntramp(SB),NOSPLIT|NOFRAME,$0
	RET

TEXT runtime·exceptiontramp(SB),NOSPLIT|NOFRAME,$0
	RET

TEXT runtime·firstcontinuetramp(SB),NOSPLIT|NOFRAME,$0
	RET

TEXT runtime·lastcontinuetramp(SB),NOSPLIT|NOFRAME,$0
	RET

TEXT runtime·ctrlhandler(SB),NOSPLIT|NOFRAME,$0
	RET

TEXT runtime·profileloop(SB),NOSPLIT|NOFRAME,$0
	RET

// int32 externalthreadhandler(uint32 arg, int (*func)(uint32))
// stack layout:
//   +----------------+
//   | callee-save    |
//   | registers      |
//   +----------------+
//   | m              |
//   +----------------+
// 20| g              |
//   +----------------+
// 16| func ptr (r1)  |
//   +----------------+
// 12| argument (r0)  |
//---+----------------+
// 8 | param1         |
//   +----------------+
// 4 | param0         |
//   +----------------+
// 0 | retval         |
//   +----------------+
//
TEXT runtime·externalthreadhandler(SB),NOSPLIT|NOFRAME,$0
	RET

GLOBL runtime·cbctxts(SB), NOPTR, $4

TEXT runtime·callbackasm1(SB),NOSPLIT|NOFRAME,$0
	RET

// uint32 tstart_stdcall(M *newm);
TEXT runtime·tstart_stdcall(SB),NOSPLIT|NOFRAME,$0
	RET

// onosstack calls fn on OS stack.
// adapted from asm_arm.s : systemstack
// func onosstack(fn unsafe.Pointer, arg uint32)
TEXT runtime·onosstack(SB),NOSPLIT,$0
	RET

// Runs on OS stack. Duration (in 100ns units) is in R0.
TEXT runtime·usleep2(SB),NOSPLIT|NOFRAME,$0
	RET

// Runs on OS stack.
TEXT runtime·switchtothread(SB),NOSPLIT|NOFRAME,$0
	RET

TEXT ·publicationBarrier(SB),NOSPLIT|NOFRAME,$0-0
	RET

// never called (cgo not supported)
TEXT runtime·read_tls_fallback(SB),NOSPLIT|NOFRAME,$0
	RET

// See http://www.dcl.hpi.uni-potsdam.de/research/WRK/2007/08/getting-os-information-the-kuser_shared_data-structure/
// Must read hi1, then lo, then hi2. The snapshot is valid if hi1 == hi2.
#define _INTERRUPT_TIME 0x7ffe0008
#define _SYSTEM_TIME 0x7ffe0014
#define time_lo 0
#define time_hi1 4
#define time_hi2 8

TEXT runtime·nanotime(SB),NOSPLIT,$0-8
	RET

TEXT time·now(SB),NOSPLIT,$0-20
	RET

// save_g saves the g register (R10) into thread local memory
// so that we can call externally compiled
// ARM code that will overwrite those registers.
// NOTE: runtime.gogo assumes that R1 is preserved by this function.
//       runtime.mcall assumes this function only clobbers R0 and R11.
// Returns with g in R0.
// Save the value in the _TEB->TlsSlots array.
// Effectively implements TlsSetValue().
// tls_g stores the TLS slot allocated TlsAlloc().
TEXT runtime·save_g(SB),NOSPLIT|NOFRAME,$0
	RET

// load_g loads the g register from thread-local memory,
// for use after calling externally compiled
// ARM code that overwrote those registers.
// Get the value from the _TEB->TlsSlots array.
// Effectively implements TlsGetValue().
TEXT runtime·load_g(SB),NOSPLIT|NOFRAME,$0
	RET

// This is called from rt0_go, which runs on the system stack
// using the initial stack allocated by the OS.
// It calls back into standard C using the BL below.
// To do that, the stack pointer must be 8-byte-aligned.
TEXT runtime·_initcgo(SB),NOSPLIT|NOFRAME,$0
	RET

// void init_thread_tls()
//
// Does per-thread TLS initialization. Saves a pointer to the TLS slot
// holding G, in the current m.
//
//     g->m->tls[0] = &_TEB->TlsSlots[tls_g]
//
// The purpose of this is to enable the profiling handler to get the
// current g associated with the thread. We cannot use m->curg because curg
// only holds the current user g. If the thread is executing system code or
// external code, m->curg will be NULL. The thread's TLS slot always holds
// the current g, so save a reference to this location so the profiling
// handler can get the real g from the thread's m.
//
// Clobbers R0-R3
TEXT runtime·init_thread_tls(SB),NOSPLIT|NOFRAME,$0
	RET

// Holds the TLS Slot, which was allocated by TlsAlloc()
GLOBL runtime·tls_g+0(SB), NOPTR, $4
