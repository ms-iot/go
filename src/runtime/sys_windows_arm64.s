// Copyright 2018 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "go_asm.h"
#include "go_tls.h"
#include "tls_arm64.h"
#include "textflag.h"

// void runtime·asmstdcall(void *c);
TEXT runtime·asmstdcall(SB),NOSPLIT|NOFRAME,$0
	// Save non-volatile registers
	SUB 	$16, RSP		// SP = SP - 16
	MOVD	R19, 0(RSP)
	MOVD	R20, 8(RSP)

	MOVD	R0, R19			// R19 = libcall* (non-volatile)
	MOVD	RSP, R20		// R20 = SP (non-volatile)
	
	// SetLastError(0)
	MRS_TPIDR_R0			// MRS TPIDR_EL0, R0 <==> MRC 15, 0, R0, C13, C0, 2
	MOVW	$0, 0x68(R0)	// Ref: sys_windows_amd64.s uses MOVL (instead of MOVQ)	

	MOVD	16(R19), R16	// R16 = libcall->args (intra-procedure-call scratch register)

	// Check if we have more than 8 arguments
	MOVD 	8(R19), R1		// R1 = libcall->n (num args)
	SUB		$8, R1, R2		// R2 = n - 8
	CMP		$8, R1			// if (n <= 8),
	BLE 	loadR7			// load registers.

	// Reserve stack space for remaining args
	LSL 	$3, R2, R8		// R8 = R2<<3 = 8*(n-8)
	SUB 	R8, RSP			// SP = SP - 8*(n-8)
	
	// Stack must be 16-byte aligned
	MOVD	RSP, R13
	BIC		$0xF, R13
	MOVD	R13, RSP

	// Push the additional args on stack
	MOVD	$0, R2			// i = 0
pushargsonstack:
	ADD		$8, R2, R3		// R3 = 8 + i
	LSL		$3, R3			// R3 = R3<<3 = 8*(8+i)
	MOVD	(R3)(R16), R3	// R3 = args[8+i]
	LSL		$3, R2, R8		// R8 = R2<<3 = 8*(i)
	MOVD	R3, (R8)(RSP)	// stack[i] = R3 = args[8+i]
	ADD		$1, R2			// i++
	SUB		$8, R1, R3		// R3 = n - 8
	CMP		R3, R2			// while(i < (n - 8)),
	BLT		pushargsonstack	// push args

	// Load parameter registers
loadR7:
	CMP		$7, R1			// if(n <= 7),
	BLE		loadR6			// jump to load args[6]
	MOVD	56(R16), R7		// R7 = args[7]
loadR6:
	CMP		$6, R1			// if(n <= 6),
	BLE		loadR5			// jump to load args[5]
	MOVD	48(R16), R6		// R6 = args[6]
loadR5:
	CMP		$5, R1			// if(n <= 5),
	BLE		loadR4			// jump to load args[4]
	MOVD	40(R16), R5		// R5 = args[5]
loadR4:
	CMP		$4, R1			// if(n <= 4),
	BLE		loadR3			// jump to load args[3]
	MOVD	32(R16), R4		// R4 = args[4]
loadR3:
	CMP		$3, R1			// if(n <= 3),
	BLE		loadR2			// jump to load args[2]
	MOVD	24(R16), R3		// R3 = args[3]
loadR2:
	CMP		$2, R1			// if(n <= 2),
	BLE		loadR1			// jump to load args[1]
	MOVD	16(R16), R2		// R2 = args[2]
loadR1:
	CMP		$1, R1			// if(n <= 1),
	BLE		loadR0			// jump to load args[0]
	MOVD	8(R16), R1		// R1 = args[1]
loadR0:
	CMP		$0, R0			// if(n <= 0),
	BLE		argsloaded		// no args to load
	MOVD	0(R16), R0		// R0 = args[0]

argsloaded:
	// Stack must be 16-byte aligned
	MOVD	RSP, R13
	BIC		$0xF, R13
	MOVD	R13, RSP

	// Call fn
	MOVD	0(R19), R16		// R16 = libcall->fn
	BL		(R16)			// branch to libcall->fn 
	
	// Free stack space
	MOVD	R20, RSP

	// Save return values
	MOVD	R0, 24(R19)
	MOVD	R1, 32(R19)		// Note(ragav): R1 is not a result register in ARM64. Double check this line.
	
	// GetLastError
	MRS_TPIDR_R0			// MRS TPIDR_EL0, R0 <==> MRC 15, 0, R0, C13, C0, 2
	MOVD	0x68(R0), R1
	MOVD	R1, 40(R19)		// libcall->err = error

	// Restore non-volatile registers
	MOVD	0(RSP), R19
	MOVD	8(RSP), R20
	ADD		$16, RSP		// SP = SP + 16
	RET

TEXT runtime·badsignal2(SB),NOSPLIT|NOFRAME,$0
	MOVD	runtime·_GetStdHandle(SB), R1
	MOVD	$-12, R0
	BL	(R1)

	MOVD	$runtime·badsignalmsg(SB), R1	// lpBuffer
	MOVD	$runtime·badsignallen(SB), R2	// lpNumberOfBytesToWrite
	MOVD	(R2), R2
	ADD		$0x8, RSP, R3		// lpNumberOfBytesWritten
	MOVD	$0, R16				// lpOverlapped
	MOVD	R16, (RSP)

	MOVD	runtime·_WriteFile(SB), R16
	BL	(R16)
	RET

TEXT runtime·getlasterror(SB),NOSPLIT,$0
	MRS_TPIDR_R0			// MRS TPIDR_EL0, R0 <==> MRC 15, 0, R0, C13, C0, 2
	MOVD	0x68(R0), R0
	MOVD 	R0, ret+0(FP)
	RET

TEXT runtime·setlasterror(SB),NOSPLIT|NOFRAME,$0
	MOVD 	R0, R1			// store err in R1
	MRS_TPIDR_R0			// MRS TPIDR_EL0, R0 <==> MRC 15, 0, R0, C13, C0, 2
	MOVD	R1, 0x68(R0)
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
// Note(ragav): The function made use of PC register which is
// not accessible in Arm64. The use and alternative to this
// function needs to be evaluated.
// TEXT runtime·returntramp(SB),NOSPLIT|NOFRAME,$0
//	RET

TEXT runtime·exceptiontramp(SB),NOSPLIT|NOFRAME,$0
	MOVD	$runtime·exceptionhandler(SB), R1		// sigmtramp needs handler function in R1
	B	runtime·sigtramp(SB)

TEXT runtime·firstcontinuetramp(SB),NOSPLIT|NOFRAME,$0
	MOVD	$runtime·firstcontinuehandler(SB), R1	// sigmtramp needs handler function in R1
	B	runtime·sigtramp(SB)

TEXT runtime·lastcontinuetramp(SB),NOSPLIT|NOFRAME,$0
	MOVD	$runtime·lastcontinuehandler(SB), R1	// sigmtramp needs handler function in R1
	B	runtime·sigtramp(SB)

TEXT runtime·ctrlhandler(SB),NOSPLIT|NOFRAME,$0
	MOVD	$runtime·ctrlhandler1(SB), R1			// sigmtramp needs handler function in R1
	B	runtime·externalthreadhandler(SB)

TEXT runtime·profileloop(SB),NOSPLIT|NOFRAME,$0
	MOVD	$runtime·profileloop1(SB), R1			// sigmtramp needs handler function in R1
	B	runtime·externalthreadhandler(SB)

// int32 externalthreadhandler(uint32 arg, int (*func)(uint32))
// stack layout: 
//   +----------------+
//   | callee-save    |
//   | registers      |
//   +----------------+
//   | m              |
//   +----------------+
// 40| g              |
//   +----------------+
// 32| func ptr (r1)  |
//   +----------------+
// 24| argument (r0)  |
//---+----------------+
// 16 | param1         |
//   +----------------+
// 8 | param0         |
//   +----------------+
// 0 | retval         |
//   +----------------+
//
TEXT runtime·externalthreadhandler(SB),NOFRAME,$0
	// Note(ragav): Check if the function needs to be nosplit.
	// Removed for now due to stack overflow.
	
	//todo: (ragav) store non-volatile registers, if needed
	SUB	$(m__size + g__size + 40), RSP	// space for locals
	MOVD	R0, 24(RSP)
	MOVD	R1, 32(RSP)

	// zero out m and g structures
	ADD		$40, RSP, R0				// compute pointer to g
	MOVD	R0, 8(RSP)
	MOVD	$(m__size + g__size), R0
	MOVD	R0, 16(RSP)
	BL	runtime·memclrNoHeapPointers(SB)

	// initialize m and g structures
	ADD		$40, RSP, R2				// R2 = g
	ADD		$(40 + g__size), RSP, R3	// R3 = m
	MOVD	R2, m_g0(R3)				// m->g0 = g
	MOVD	R3, g_m(R2)					// g->m = m
	MOVD	R2, m_curg(R3)				// m->curg = g

	MOVD	R2, g
	BL		runtime·save_g(SB)

	// set up stackguard stuff
	MOVD	RSP, R0
	MOVD	R0, g_stack+stack_hi(g)
	SUB		$(32*1024), R0
	MOVD	R0, (g_stack+stack_lo)(g)
	MOVD	R0, g_stackguard0(g)
	MOVD	R0, g_stackguard1(g)

	// move argument into position and call function
	MOVD	24(RSP), R0
	MOVD	R0, 8(RSP)
	MOVD	32(RSP), R1
	BL		(R1)

	// clear g
	MOVD	$0, g
	BL	runtime·save_g(SB)

	MOVD	0(RSP), R0							// load return value
	ADD		$(m__size + g__size + 40), RSP		// free locals
	// todo(ragav): restore non-volatile registers
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

// Note(ragav): commented because duplicate symbol
// TEXT ·publicationBarrier(SB),NOSPLIT|NOFRAME,$0-0
//	B	runtime·armPublicationBarrier(SB)

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

// Note(ragav): commented because duplicate symbol
// TEXT runtime·save_g(SB),NOSPLIT|NOFRAME,$0
//	RET

// load_g loads the g register from thread-local memory,
// for use after calling externally compiled
// ARM code that overwrote those registers.
// Get the value from the _TEB->TlsSlots array.
// Effectively implements TlsGetValue().

// Note(ragav): commented because duplicate symbol
// TEXT runtime·load_g(SB),NOSPLIT|NOFRAME,$0
//	RET

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
