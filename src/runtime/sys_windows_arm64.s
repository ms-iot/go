// Copyright 2018 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "go_asm.h"
#include "go_tls.h"
#include "tls_arm64.h"
#include "textflag.h"

// Note(ragav): verify the correctness of MOVD instruction (as opposed to MOVW)
// 				for non-register related moves. Especially as the target dest
//				might be 32-bit data type as opposed to 64.

// Note(ragav): verify if the link register needs to be saved as in some arm32 functions.

// void runtime·asmstdcall(void *c);
TEXT runtime·asmstdcall(SB),NOSPLIT|NOFRAME,$0
	// Save non-volatile registers
	SUB 	$32, RSP		// SP = SP - 32
	MOVD	R19, 0(RSP)
	MOVD	R20, 8(RSP)
	MOVD	R21, 16(RSP)

	MOVD	R0, R19			// R19 = libcall* (non-volatile)
	MOVD	RSP, R20		// R20 = SP (non-volatile)
	MOVD	LR, R21			// R21 = link register
	
	// SetLastError(0)
	WORD	$0xaa1203e1		// MOVD	R18, R1
	MOVW	$0, 0x68(R1)	// Note(ragav): Windows ABI says R18 holds the base of TEB struct

	MOVD	16(R19), R16	// R16 = libcall->args (intra-procedure-call scratch register)

	// Check if we have more than 8 arguments
	MOVD 	8(R19), R0		// R0 = libcall->n (num args)
	SUB		$8, R0, R2		// R2 = n - 8
	CMP		$8, R0			// if (n <= 8),
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
	SUB		$8, R0, R3		// R3 = n - 8
	CMP		R3, R2			// while(i < (n - 8)),
	BLT		pushargsonstack	// push args

	// Load parameter registers
loadR7:
	CMP		$7, R0			// if(n <= 7),
	BLE		loadR6			// jump to load args[6]
	MOVD	56(R16), R7		// R7 = args[7]
loadR6:
	CMP		$6, R0			// if(n <= 6),
	BLE		loadR5			// jump to load args[5]
	MOVD	48(R16), R6		// R6 = args[6]
loadR5:
	CMP		$5, R0			// if(n <= 5),
	BLE		loadR4			// jump to load args[4]
	MOVD	40(R16), R5		// R5 = args[5]
loadR4:
	CMP		$4, R0			// if(n <= 4),
	BLE		loadR3			// jump to load args[3]
	MOVD	32(R16), R4		// R4 = args[4]
loadR3:
	CMP		$3, R0			// if(n <= 3),
	BLE		loadR2			// jump to load args[2]
	MOVD	24(R16), R3		// R3 = args[3]
loadR2:
	CMP		$2, R0			// if(n <= 2),
	BLE		loadR1			// jump to load args[1]
	MOVD	16(R16), R2		// R2 = args[2]
loadR1:
	CMP		$1, R0			// if(n <= 1),
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
	MOVD	R21, LR			// restore link register
	
	// Free stack space
	MOVD	R20, RSP

	// Save return values
	MOVD	R0, 24(R19)
	MOVD	R1, 32(R19)		// Note(ragav): R1 is not a result register in ARM64. Double check this line.
	
	// GetLastError
	WORD	$0xaa1203e0			// MOVD	R18, R0
	MOVW	0x68(R0), R1		// R1 = LastError
	MOVW	R1, 40(R19)			// libcall->err = error

	// Restore non-volatile registers
	MOVD	0(RSP), R19
	MOVD	8(RSP), R20
	MOVD	16(RSP), R21
	ADD		$32, RSP		// SP = SP + 32
	RET

TEXT runtime·badsignal2(SB),NOSPLIT|NOFRAME,$0
	//@ MOVD	runtime·_GetStdHandle(SB), R1
	//@ MOVD	$-12, R0
	//@ BL	(R1)

	//@ MOVD	$runtime·badsignalmsg(SB), R1	// lpBuffer
	//@ MOVD	$runtime·badsignallen(SB), R2	// lpNumberOfBytesToWrite
	//@ MOVD	(R2), R2
	//@ ADD		$0x8, RSP, R3		// lpNumberOfBytesWritten
	//@ MOVD	$0, R16				// lpOverlapped
	//@ MOVD	R16, (RSP)

	//@ MOVD	runtime·_WriteFile(SB), R16
	//@ BL	(R16)
	MOVD	$1101, R19
	BRK
	RET

TEXT runtime·getlasterror(SB),NOSPLIT,$0
	WORD	$0xaa1203e1		// MOVD	R18, R1
	MOVD	0x68(R1), R0
	MOVD 	R0, ret+0(FP)
	RET

TEXT runtime·setlasterror(SB),NOSPLIT|NOFRAME,$0
	WORD	$0xaa1203e1		// MOVD	R18, R1
	MOVW	R0, 0x68(R1)
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
	MOVD	$701, R19
	BRK
	RET

//
// Trampoline to resume execution from exception handler.
// This is part of the control flow guard workaround.
// It switches stacks and jumps to the continuation address.
 TEXT runtime·returntramp(SB),NOSPLIT|NOFRAME,$0
	MOVD	$801, R19
	BRK
	RET

TEXT runtime·exceptiontramp(SB),NOSPLIT|NOFRAME,$0
	// @ MOVD	$runtime·exceptionhandler(SB), R1		// sigmtramp needs handler function in R1
	// @ B	runtime·sigtramp(SB)
	MOVD	$702, R19
	BRK
	RET

TEXT runtime·firstcontinuetramp(SB),NOSPLIT|NOFRAME,$0
	// @ MOVD	$runtime·firstcontinuehandler(SB), R1	// sigmtramp needs handler function in R1
	// @ B	runtime·sigtramp(SB)
	MOVD	$703, R19
	BRK
	RET

TEXT runtime·lastcontinuetramp(SB),NOSPLIT|NOFRAME,$0
	// @ MOVD	$runtime·lastcontinuehandler(SB), R1	// sigmtramp needs handler function in R1
	// @ B	runtime·sigtramp(SB)
	MOVD	$704, R19
	BRK
	RET

TEXT runtime·ctrlhandler(SB),NOSPLIT|NOFRAME,$0
	// @ MOVD	$runtime·ctrlhandler1(SB), R1			// sigmtramp needs handler function in R1
	// @ B	runtime·externalthreadhandler(SB)
	MOVD	$705, R19
	BRK
	RET

TEXT runtime·profileloop(SB),NOSPLIT|NOFRAME,$0
	// @ MOVD	$runtime·profileloop1(SB), R1			// sigmtramp needs handler function in R1
	// @ B	runtime·externalthreadhandler(SB)
	MOVD	$705, R19
	BRK
	RET

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
	// @ SUB	$(m__size + g__size + 40), RSP	// space for locals
	// @ MOVD	R0, 24(RSP)
	// @ MOVD	R1, 32(RSP)

	// @ // zero out m and g structures
	// @ ADD		$40, RSP, R0				// compute pointer to g
	// @ MOVD	R0, 8(RSP)
	// @ MOVD	$(m__size + g__size), R0
	// @ MOVD	R0, 16(RSP)
	// @ BL	runtime·memclrNoHeapPointers(SB)

	// @ // initialize m and g structures
	// @ ADD		$40, RSP, R2				// R2 = g
	// @ ADD		$(40 + g__size), RSP, R3	// R3 = m
	// @ MOVD	R2, m_g0(R3)				// m->g0 = g
	// @ MOVD	R3, g_m(R2)					// g->m = m
	// @ MOVD	R2, m_curg(R3)				// m->curg = g

	// @ MOVD	R2, g
	// @ BL		runtime·save_g(SB)

	// @ // set up stackguard stuff
	// @ MOVD	RSP, R0
	// @ MOVD	R0, g_stack+stack_hi(g)
	// @ SUB		$(32*1024), R0
	// @ MOVD	R0, (g_stack+stack_lo)(g)
	// @ MOVD	R0, g_stackguard0(g)
	// @ MOVD	R0, g_stackguard1(g)

	// @ // move argument into position and call function
	// @ MOVD	24(RSP), R0
	// @ MOVD	R0, 8(RSP)
	// @ MOVD	32(RSP), R1
	// @ BL		(R1)

	// @ // clear g
	// @ MOVD	$0, g
	// @ BL	runtime·save_g(SB)

	// @ MOVD	0(RSP), R0							// load return value
	// @ ADD		$(m__size + g__size + 40), RSP		// free locals
	// @ // todo(ragav): restore non-volatile registers
	MOVD	$706, R19
	BRK
	RET

GLOBL runtime·cbctxts(SB), NOPTR, $4

TEXT runtime·callbackasm1(SB),NOSPLIT|NOFRAME,$0
	// @ // Save non-volatile registers
	// @ SUB 	$16, RSP		// SP = SP - 16
	// @ MOVD	R19, 0(RSP)
	// @ MOVD	R20, 8(RSP)

	// @ SUB		$72, RSP
	// @ // Save callback arguments to stack. We currently support up to 4 arguments
	// @ // Note(ragav): We can potentially store up to 8 in Arm64.
	// @ MOVD	R0, 32(RSP)
	// @ MOVD	R1, 40(RSP)
	// @ MOVD	R2, 48(RSP)
	// @ MOVD	R3, 56(RSP)

	// @ // load cbctxts[i]. The trampoline in zcallback_windows.s puts the callback
	// @ // index in R16
	// @ MOVD	runtime·cbctxts(SB), R19
	// @ LSL 	$3, R16, R8		// R8 = R16<<3 = 8*R16		
	// @ MOVD	(R16)(R19), R19		// R19 holds pointer to wincallbackcontext structure

	// @ // extract callback context
	// @ MOVD	wincallbackcontext_argsize(R19), R20
	// @ MOVD	wincallbackcontext_gobody(R19), R19

	// @ // we currently support up to 4 arguments
	// @ CMP		$(4 * 8), R20
	// @ BGT		2(PC)
	// @ BL		runtime·abort(SB)

	// @ // extend argsize by size of return value
	// @ ADD		$8, R20

	// @ // Build 'type args struct'
	// @ MOVD	R19, 8(RSP)		// fn
	// @ ADD		$32, RSP, R0	// arg (points to r0-r3, ret on stack)
	// @ MOVD	R0, 16(RSP)
	// @ MOVD	R20, 24(RSP)	// argsize

	// @ BL	runtime·load_g(SB)
	// @ BL	runtime·cgocallback_gofunc(SB)

	// @ ADD		$32, RSP, R0	// load arg
	// @ MOVD	24(RSP), R1		// load argsize
	// @ SUB		$8, R1			// offset to return value
	// @ MOVD	(R1)(R0), R0	// load return value

	// @ ADD		$72, RSP		// free locals
	
	// @ // Restore non-volatile registers
	// @ MOVD	0(RSP), R19
	// @ MOVD	8(RSP), R20
	// @ ADD		$16, RSP		// SP = SP + 16
	MOVD	$707, R19
	BRK
	RET

// uint32 tstart_stdcall(M *newm);
TEXT runtime·tstart_stdcall(SB),NOSPLIT|NOFRAME,$0
	// Todo(ragav): save non-volatile registers, if needed
	// @ MOVD	m_g0(R0), g
	// @ MOVD	R0, g_m(g)
	// @ BL	runtime·save_g(SB)

	// @ // do per-thread TLS initialization
	// @ BL	runtime·init_thread_tls(SB)

	// @ // Layout new m scheduler stack on os stack.
	// @ MOVD	RSP, R0
	// @ MOVD	R0, (g_stack+stack_hi)(g)
	// @ SUB		$(64*1024), R0
	// @ MOVD	R0, (g_stack+stack_lo)(g)
	// @ MOVD	R0, g_stackguard0(g)
	// @ MOVD	R0, g_stackguard1(g)

	// @ // BL	runtime·emptyfunc(SB)	// fault if stack check is wrong
	// @ BL	runtime·mstart(SB)

	// @ // Exit the thread.
	// @ MOVD	$0, R0
	MOVD	$708, R19
	BRK
	RET

// onosstack calls fn on OS stack.
// adapted from asm_arm.s : systemstack
// func onosstack(fn unsafe.Pointer, arg uint32)
// Note(ragav): highly likely to be wrong. Temporary implementation.
TEXT runtime·onosstack(SB),NOSPLIT,$0
	// Todo(ragav): save non-volatile registers, if needed (currently 19, 20, 21)
// @ 	MOVD	fn+0(FP), R20		// R20 = fn
// @ 	MOVW	arg+8(FP), R21		// R21 = arg

// @ 	// This function can be called when there is no g,
// @ 	// for example, when we are handling a callback on a non-go thread.
// @ 	// In this case we're already on the system stack.
// @ 	CMP	$0, g
// @ 	BEQ	noswitch

// @ 	MOVD	g_m(g), R1		// R1 = m

// @ 	MOVD	m_gsignal(R1), R2	// R2 = gsignal
// @ 	CMP		g, R2
// @ 	BEQ		noswitch

// @ 	MOVD	m_g0(R1), R2		// R2 = g0
// @ 	CMP		g, R2
// @ 	BEQ		noswitch

// @ 	MOVD	m_curg(R1), R3
// @ 	CMP		g, R3
// @ 	BEQ		switch

// @ 	// Bad: g is not gsignal, not g0, not curg. What is it?
// @ 	// Hide call from linker nosplit analysis.
// @ 	MOVD	$runtime·badsystemstack(SB), R0
// @ 	BL	(R0)
// @ 	B	runtime·abort(SB)
	
// @ switch:
// @ 	// save our state in g->sched. Pretend to
// @ 	// be systemstack_switch if the G stack is scanned.
// @ 	MOVD	$runtime·systemstack_switch(SB), R3
// @ 	ADD		$8, R3, R3 // get past push {lr}
// @ 	MOVD	R3, (g_sched+gobuf_pc)(g)
// @ 	MOVD	RSP, R8
// @ 	MOVD	R8, (g_sched+gobuf_sp)(g)
// @ 	MOVD	LR, (g_sched+gobuf_lr)(g)
// @ 	MOVD	g, (g_sched+gobuf_g)(g)

// @ 	// switch to g0
// @ 	MOVD	R2, g
// @ 	MOVD	(g_sched+gobuf_sp)(R2), R3
// @ 	// make it look like mstart called systemstack on g0, to stop traceback
// @ 	SUB		$8, R3, R3
// @ 	MOVD	$runtime·mstart(SB), R19
// @ 	MOVD	R19, 0(R3)
// @ 	MOVD	R3, RSP

// @ 	// call target function
// @ 	MOVD	R6, R0		// arg
// @ 	BL	(R5)

// @ 	// switch back to g
// @ 	MOVD	g_m(g), R1
// @ 	MOVD	m_curg(R1), g
// @ 	MOVD	(g_sched+gobuf_sp)(g), R8
// @ 	MOVD	R8, RSP
// @ 	MOVD	$0, R3
// @ 	MOVD	R3, (g_sched+gobuf_sp)(g)
// @ 	RET

// @ noswitch:
// @ 	// Using a tail call here cleans up tracebacks since we won't stop
// @ 	// at an intermediate systemstack.
// @ 	MOVD.P	8(RSP), R30	// restore LR
// @ 	MOVD	R21, R0		// arg
// @ 	B	(R20)
	MOVD	$709, R19
	BRK
	RET

// Runs on OS stack. Duration (in 100ns units) is in R0.
TEXT runtime·usleep2(SB),NOSPLIT|NOFRAME,$0
	// Save non-volatile registers
	// @ SUB 	$8, RSP		// SP = SP - 8
	// @ MOVD	R19, 0(RSP)

	// @ MOVD	RSP, R19		// Save SP
	// @ SUB		$16, RSP		// SP = SP - 16
	
	// @ // Stack must be 16-byte aligned
	// @ MOVD	RSP, R13
	// @ BIC		$0xF, R13
	// @ MOVD	R13, RSP

	// @ MOVD	$0, R8
	// @ SUB		R0, R8, R3		// R3 = -R0	Note(ragav): orignally RSB instruction was used
	// @ MOVD	$0, R1			// R1 = FALSE (alertable)
	// @ MOVD	$-1, R0			// R0 = handle
	// @ MOVD	RSP, R2			// R2 = pTime
	// @ MOVD	R3, 0(R2)		// time_lo
	// @ MOVD	R0, 8(R2)		// time_hi
	// @ MOVD	runtime·_NtWaitForSingleObject(SB), R3
	// @ BL		(R3)
	// @ MOVD	R19, RSP			// Restore SP

	// @ // Restore non-volatile registers
	// @ MOVD	0(RSP), R19
	// @ ADD 	$8, RSP
	MOVD	$710, R19
	BRK
	RET

// Runs on OS stack.
TEXT runtime·switchtothread(SB),NOSPLIT|NOFRAME,$0
	// Save non-volatile registers
	// @ SUB 	$8, RSP		// SP = SP - 8
	// @ MOVD	R19, 0(RSP)

	// @ MOVD    RSP, R19
	
	// @ // Stack must be 16-byte aligned
	// @ MOVD	RSP, R13
	// @ BIC		$0xF, R13
	// @ MOVD	R13, RSP
	
	// @ MOVD	runtime·_SwitchToThread(SB), R0
	// @ BL		(R0)
	// @ MOVD 	R19, R13			// restore stack pointer 
	
	// @ // Restore non-volatile registers
	// @ MOVD	0(RSP), R19
	// @ ADD 	$8, RSP
	MOVD	$711, R19
	BRK
	RET

// Note(ragav): commented because duplicate symbol
// TEXT ·publicationBarrier(SB),NOSPLIT|NOFRAME,$0-0
//	B	runtime·armPublicationBarrier(SB)

// never called (cgo not supported)
TEXT runtime·read_tls_fallback(SB),NOSPLIT|NOFRAME,$0
	// @ MOVD	$0xabcd, R0
	// @ MOVD	R0, (R0)
	MOVD	$712, R19
	BRK
	RET

// See http://www.dcl.hpi.uni-potsdam.de/research/WRK/2007/08/getting-os-information-the-kuser_shared_data-structure/
// Must read hi1, then lo, then hi2. The snapshot is valid if hi1 == hi2.
#define _INTERRUPT_TIME 0x7ffe0008
#define _SYSTEM_TIME 0x7ffe0014
#define time_lo 0
#define time_hi1 4
#define time_hi2 8

TEXT runtime·nanotime(SB),NOSPLIT,$0-8
// @ 	MOVD	$0, R0
// @ 	MOVB	runtime·useQPCTime(SB), R0
// @ 	CMP		$0, R0
// @ 	BNE		useQPC
// @ 	MOVD	$_INTERRUPT_TIME, R3
// @ loop:
// @ 	MOVD	time_hi1(R3), R1
// @ 	MOVD	time_lo(R3), R0
// @ 	MOVD	time_hi2(R3), R2
// @ 	CMP		R1, R2
// @ 	BNE		loop

// @ 	// wintime = R1:R0, multiply by 100
// @ 	MOVD	$100, R2
// @ 	// Todo(ragav): verify correctness
// @ 	UMULL	R0, R2, R3    // R4:R3 = R1:R0 * R2
// @ 	UMULH	R0, R2, R4
// @ 	MADD	R1, R2, R4, R4

// @ 	// wintime*100 = R4:R3
// @ 	MOVD	R3, ret_lo+0(FP)
// @ 	MOVD	R4, ret_hi+8(FP)
// @ 	RET
// @ useQPC:
// @ 	B	runtime·nanotimeQPC(SB)		// tail call
	MOVD	$713, R19
	BRK
	RET



TEXT time·now(SB),NOSPLIT,$0-20
// 	MOVD    $0, R0
// 	MOVB    runtime·useQPCTime(SB), R0
// 	CMP		$0, R0
// 	BNE		useQPC
// 	MOVD	$_INTERRUPT_TIME, R3
// loop:
// 	MOVD	time_hi1(R3), R1
// 	MOVD	time_lo(R3), R0
// 	MOVD	time_hi2(R3), R2
// 	CMP		R1, R2
// 	BNE		loop

// 	// wintime = R1:R0, multiply by 100
// 	MOVD	$100, R2
// 	// verify the correctness
// 	UMULL	R0, R2, R3    // R4:R3 = R1:R0 * R2
// 	UMULH	R0, R2, R4
// 	MADD	R1, R2, R4, R4

// 	// wintime*100 = R4:R3
// 	MOVD	R3, mono+12(FP)
// 	MOVD	R4, mono+16(FP)

// 	MOVD	$_SYSTEM_TIME, R3
// wall:
// 	MOVD	time_hi1(R3), R1
// 	MOVD	time_lo(R3), R0
// 	MOVD	time_hi2(R3), R2
// 	CMP		R1, R2
// 	BNE		wall

// 	// w = R1:R0 in 100ns untis
// 	// convert to Unix epoch (but still 100ns units)
// 	#define delta 116444736000000000
// 	SUBS   $(delta & 0xFFFFFFFF), R0
// 	SBC     $(delta >> 32), R1

// 	// Convert to nSec
// 	MOVD    $100, R2
// 	// Todo(ragav): verify correctness
// 	UMULL	R0, R2, R3    // R4:R3 = R1:R0 * R2
// 	UMULH	R0, R2, R4
// 	MADD	R1, R2, R4, R4
// 	// w = R2:R1 in nSec
// 	MOVD    R3, R1	      // R4:R3 -> R2:R1
// 	MOVD    R4, R2

// 	// multiply nanoseconds by reciprocal of 10**9 (scaled by 2**61)
// 	// to get seconds (96 bit scaled result)
// 	MOVD	$0x89705f41, R3		// 2**61 * 10**-9
	
// 	// Todo(ragav): verify correctness. Very likely it's wrong.
// 	// R7:R6:R5 = R2:R1 * R3
// 	UMULL	R3, R1, R5    
// 	UMULH	R3, R1, R6
// 	UMADDL	R3, R2, R6, R6
// 	UMADDH 	R3, R2, R6, R7

// 	// unscale by discarding low 32 bits, shifting the rest by 29
// 	MOVW	R6>>29,R6		// R7:R6 = (R7:R6:R5 >> 61)clea
// 	ORR	R7<<3,R6
// 	MOVW	R7>>29,R7

// 	// subtract (10**9 * sec) from nsec to get nanosecond remainder
// 	MOVW	$1000000000, R5	// 10**9
// 	MULLU	R6,R5,(R9,R8)   // R9:R8 = R7:R6 * R5
// 	MULA	R7,R5,R9,R9
// 	SUB.S	R8,R1		// R2:R1 -= R9:R8
// 	SBC	R9,R2

// 	// because reciprocal was a truncated repeating fraction, quotient
// 	// may be slightly too small -- adjust to make remainder < 10**9
// 	CMP	R5,R1	// if remainder > 10**9
// 	SUB.HS	R5,R1   //    remainder -= 10**9
// 	ADD.HS	$1,R6	//    sec += 1

// 	MOVW	R6,sec_lo+0(FP)
// 	MOVW	R7,sec_hi+4(FP)
// 	MOVW	R1,nsec+8(FP)
// 	RET
// useQPC:
// 	B	runtime·nanotimeQPC(SB)		// tail call
	MOVD	$714, R19
	BRK
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
	// Save non-volatile registers
	// @ SUB 	$8, RSP		// SP = SP - 8
	// @ MOVD	R19, 0(RSP)

	// @ MOVD	RSP, R19
	// @ // Stack must be 16-byte aligned
	// @ MOVD	RSP, R13
	// @ BIC		$0xF, R13
	// @ MOVD	R13, RSP

	// @ // Allocate a TLS slot to hold g across calls to external code
	// @ MOVD 	$runtime·_TlsAlloc(SB), R0
	// @ MOVD	(R0), R0
	// @ BL	(R0)

	// @ // Assert that slot is less than 64 so we can use _TEB->TlsSlots
	// @ CMP		$64, R0
	// @ MOVD	$runtime·abort(SB), R1
	// @ BGE		2(PC)
	// @ BL		(R1)

	// @ // Save Slot into tls_g
	// @ MOVD 	$runtime·tls_g(SB), R1
	// @ MOVD	R0, (R1)

	// @ BL	runtime·init_thread_tls(SB)

	// @ MOVD	R19, R13
	// @ // Restore non-volatile registers
	// @ MOVD	0(RSP), R19
	// @ ADD 	$8, RSP
	MOVD	$715, R19
	BRK
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
	// compute &_TEB->TlsSlots[tls_g]
	// @ WORD	$0xaa1203e0		// MOVD	R18, R0
	// @ ADD		$0xe10, R0
	// @ MOVD 	$runtime·tls_g(SB), R1
	// @ MOVD	(R1), R1
	// @ LSL		$3, R1, R1
	// @ ADD		R1, R0

	// @ // save in g->m->tls[0]
	// @ MOVD	g_m(g), R1
	// @ MOVD	R0, m_tls(R1)
	MOVD	$716, R19
	BRK
	RET

// Holds the TLS Slot, which was allocated by TlsAlloc()
GLOBL runtime·tls_g+0(SB), NOPTR, $4
