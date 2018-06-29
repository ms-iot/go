// Copyright 2018 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "go_asm.h"
#include "go_tls.h"
#include "textflag.h"

// void runtime·asmstdcall(void *c);
TEXT runtime·asmstdcall(SB),NOSPLIT|NOFRAME,$0
	MOVM.DB.W [R4, R5, R14], (R13)	// push {r4, r5, lr}
	MOVW	R0, R4			// put libcall * in r4
	MOVW	R13, R5			// save stack pointer in r5

	// SetLastError(0)
	MOVW	$0, R0
	MRC	15, 0, R1, C13, C0, 2
	MOVW	R0, 0x34(R1)

	MOVW	8(R4), R12	// libcall->args

	// Do we have more than 4 arguments?
	MOVW	4(R4), R0	// libcall->n
	SUB.S	$4, R0, R2
	BLE	loadregs

	// Reserve stack space for remaining args
	SUB	R2<<2, R13
	BIC	$0x7, R13	// alignment for ABI

	// R0: count of arguments
	// R1:
	// R2: loop counter, from 0 to (n-4)
	// R3: scratch
	// R4: pointer to libcall struct
	// R12: libcall->args
	MOVW	$0, R2
stackargs:
	ADD	$4, R2, R3		// r3 = args[4 + i]
	MOVW	R3<<2(R12), R3
	MOVW	R3, R2<<2(R13)		// stack[i] = r3

	ADD	$1, R2			// i++
	SUB	$4, R0, R3		// while (i < (n - 4))
	CMP	R3, R2
	BLT	stackargs

loadregs:
	CMP	$3, R0
	MOVW.GT 12(R12), R3

	CMP	$2, R0
	MOVW.GT 8(R12), R2

	CMP	$1, R0
	MOVW.GT 4(R12), R1

	CMP	$0, R0
	MOVW.GT 0(R12), R0

	BIC	$0x7, R13		// alignment for ABI
	MOVW	0(R4), R12		// branch to libcall->fn
	BL	(R12)

	MOVW	R5, R13			// free stack space
	MOVW	R0, 12(R4)		// save return value to libcall->r1
	MOVW	R1, 16(R4)

	// GetLastError
	MRC	15, 0, R1, C13, C0, 2
	MOVW	0x34(R1), R0
	MOVW	R0, 20(R4)		// store in libcall->err

	MOVM.IA.W (R13), [R4, R5, R15]

TEXT	runtime·badsignal2(SB),NOSPLIT|NOFRAME,$0
/*
	// stderr
	MOVW	$-12, 0(SP)
	MOVW	SP, BP
	CALL	*runtime·_GetStdHandle(SB)
	MOVW	BP, SP

	MOVW	AX, 0(SP)	// handle
	MOVW	$runtime·badsignalmsg(SB), DX // pointer
	MOVW	DX, 4(SP)
	MOVW	runtime·badsignallen(SB), DX // count
	MOVW	DX, 8(SP)
	LEAL	20(SP), DX  // written count
	MOVW	$0, 0(DX)
	MOVW	DX, 12(SP)
	MOVW	$0, 16(SP) // overlapped
	CALL	*runtime·_WriteFile(SB)
	MOVW	BP, SI
*/
	MOVW	$0x1234, R12
	MOVW	R12, (R12)
	RET

// faster get/set last error
TEXT runtime·getlasterror(SB),NOSPLIT,$0
	MRC	15, 0, R0, C13, C0, 2
	MOVW	0x34(R0), R0
	MOVW	R0, ret+0(FP)
	RET

TEXT runtime·setlasterror(SB),NOSPLIT|NOFRAME,$0
	MRC	15, 0, R1, C13, C0, 2
	MOVW	R0, 0x34(R1)
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
	MOVM.DB.W [R0, R4-R11, R14], (R13)	// push {r0, r4-r11, lr} (SP-=40)
	SUB	$(8+20), R13		// reserve space for g, sp, and
					// parameters/retval to go call

	MOVW	R0, R6			// Save param0
	MOVW	R1, R7			// Save param1

	BL      runtime·load_g(SB)
	CMP	$0, g			// is there a current g?
	BL.EQ	runtime·badsignal2(SB)

	// save g and SP in case of stack switch
	MOVW	R13, 24(R13)
	MOVW	g, 20(R13)

	// do we need to switch to the g0 stack?
	MOVW	g, R5			// R5 = g
	MOVW	g_m(R5), R2		// R2 = m
	MOVW	m_g0(R2), R4		// R4 = g0
	CMP	R5, R4			// if curg == g0
	BEQ	g0

	// switch to g0 stack
	MOVW	R4, g				// g = g0
	MOVW	(g_sched+gobuf_sp)(g), R3	// R3 = g->gobuf.sp
	BL      runtime·save_g(SB)

	// traceback will think that we've done PUSHFQ and SUBQ
        // on this stack, so subtract them here to match.
        // (we need room for sighandler arguments anyway).
        // and re-save old SP for restoring later.
	SUB	$(40+8+20), R3
	MOVW	R13, 24(R3)		// save old stack pointer
	MOVW	R3, R13			// switch stack

g0:
	MOVW	0(R6), R2	// R2 = ExceptionPointers->ExceptionRecord
	MOVW	4(R6), R3	// R3 = ExceptionPointers->ContextRecord

	// make it look like mstart called us on g0, to stop traceback
	MOVW    $runtime·mstart(SB), R4

	MOVW	R4, 0(R13)	// Save link register for traceback
	MOVW	R2, 4(R13)	// Move arg0 (ExceptionRecord) into position
	MOVW	R3, 8(R13)	// Move arg1 (ContextRecord) into position
	MOVW	R5, 12(R13)	// Move arg2 (original g) into position
	BL	(R7)		// Call the go routine
	MOVW	16(R13), R4	// Fetch return value from stack

	ADD	$(40+20), R13, R12 	// save current g0 stack pointer and reserve 8 bytes

	// switch back to original stack and g
	MOVW	24(R13), R13
	MOVW	20(R13), g
	BL      runtime·save_g(SB)

done:
	MOVW	R4, R0
	ADD	$(8 + 20), R13
	MOVM.IA.W (R13), [R3, R4-R11, R14]	// pop {r3, r4-r11, lr}

	// if return value is CONTINUE_SEARCH, do not trampoline
	CMP	$0, R0
	BEQ	return

	// Check if we need to trampoline
	MOVW	4(R3), R3			// PEXCEPTION_POINTERS->Context
	MOVW	0x40(R3), R2			// load PC from context record
	MOVW	$runtime·returntramp(SB), R1
	CMP	R1, R2
	B.EQ	return				// do not clobber saved SP/PC if already armed

	// Save return SP and PC onto g0 stack
	MOVW	0x38(R3), R2			// load SP from context record
	MOVW	R2, 0(R12)			// Store resume SP on g0 stack
	MOVW	0x40(R3), R2			// load PC from context record
	MOVW	R2, 4(R12)			// Store resume PC on g0 stack

	// Set up context record to return to returntramp on g0 stack
	MOVW	R12, 0x38(R3)			// save g0 stack pointer in context record
	MOVW	$runtime·returntramp(SB), R2
	MOVW	R2, 0x40(R3)			// set continuation address in context record

return:
	B	(R14)				// return

//
// Function to resume execution from exception handler.
// It switches stacks and jumps to the continuation address
//
TEXT runtime·returntramp(SB),NOSPLIT|NOFRAME,$0
	MOVM.IA	(R13), [R13, R15]		// ldm sp, [sp, pc]

TEXT runtime·exceptiontramp(SB),NOSPLIT|NOFRAME,$0
	MOVW	$runtime·exceptionhandler(SB), R1
	B	runtime·sigtramp(SB)

TEXT runtime·firstcontinuetramp(SB),NOSPLIT|NOFRAME,$0
	MOVW	$runtime·firstcontinuehandler(SB), R1
	B	runtime·sigtramp(SB)

TEXT runtime·lastcontinuetramp(SB),NOSPLIT|NOFRAME,$0
	MOVW	$runtime·lastcontinuehandler(SB), R1
	B	runtime·sigtramp(SB)

TEXT runtime·ctrlhandler(SB),NOSPLIT,$0
/*
	PUSHL	$runtime·ctrlhandler1(SB)
	CALL	runtime·externalthreadhandler(SB)
	MOVW	4(SP), CX
	ADDL	$12, SP
	JMP	CX
*/
    // Stub
	MOVW	$5, R12
	MOVW	R12, (R12)
	RET

TEXT runtime·profileloop(SB),NOSPLIT,$0
/*
	PUSHL	$runtime·profileloop1(SB)
	CALL	runtime·externalthreadhandler(SB)
	MOVW	4(SP), CX
	ADDL	$12, SP
	JMP	CX
*/
	// Stub
	MOVW	$6, R12
	MOVW	R12, (R12)
	RET

TEXT runtime·externalthreadhandler(SB),NOSPLIT,$0
/*
	PUSHL	BP
	MOVW	SP, BP
	PUSHL	BX
	PUSHL	SI
	PUSHL	DI
	PUSHL	0x14(FS)
	MOVW	SP, DX

	// setup dummy m, g
	SUB	    $m__size, SP		// space for M
	MOVW	SP, 0(SP)
	MOVW	$m__size, 4(SP)
	CALL	runtime·memclrNoHeapPointers(SB)	// smashes AX,BX,CX

	LEAL	m_tls(SP), CX
	MOVW	CX, 0x14(FS)
	MOVW	SP, BX
	SUB	    $g__size, SP		// space for G
	MOVW	SP, g(CX)
	MOVW	SP, m_g0(BX)

	MOVW	SP, 0(SP)
	MOVW	$g__size, 4(SP)
	CALL	runtime·memclrNoHeapPointers(SB)	// smashes AX,BX,CX
	LEAL	g__size(SP), BX
	MOVW	BX, g_m(SP)

	LEAL	-32768(SP), CX		// must be less than SizeOfStackReserve set by linker
	MOVW	CX, (g_stack+stack_lo)(SP)
	ADDL	$const__StackGuard, CX
	MOVW	CX, g_stackguard0(SP)
	MOVW	CX, g_stackguard1(SP)
	MOVW	DX, (g_stack+stack_hi)(SP)

	PUSHL	AX			// room for return value
	PUSHL	16(BP)			// arg for handler
	CALL	8(BP)
	POPL	CX
	POPL	AX			// pass return value to Windows in AX

	get_tls(CX)
	MOVW	g(CX), CX
	MOVW	(g_stack+stack_hi)(CX), SP
	POPL	0x14(FS)
	POPL	DI
	POPL	SI
	POPL	BX
	POPL	BP
*/
	MOVW	$7, R12
	MOVW	R12, (R12)
	RET

GLOBL runtime·cbctxts(SB), NOPTR, $4

TEXT runtime·callbackasm1(SB),NOSPLIT|NOFRAME,$0
	MOVM.DB.W [R4-R11, R14], (R13)	// push {r4-r11, lr}
	SUB	$36, R13		// space for locals

	// save callback arguments to stack. We currently support up to 4 arguments
	ADD	$16, R13, R4
	MOVM.IA	[R0-R3], (R4)

	// load cbctxts[i]. The trampoline in zcallback_windows.s puts the callback
	// index in R12
	MOVW	runtime·cbctxts(SB), R4
	MOVW	R12<<2(R4), R4		// R4 holds pointer to wincallbackcontext structure

	// extract callback context
	MOVW	wincallbackcontext_argsize(R4), R5
	MOVW	wincallbackcontext_gobody(R4), R4

	// we currently support up to 4 arguments
	CMP	$(4 * 4), R5
	BL.GT	runtime·badsignal2(SB)

	// extend argsize by size of return value
	ADD	$4, R5

	// Build 'type args struct'
	MOVW	R4, 4(R13)		// fn
	ADD	$16, R13, R0		// arg (points to r0-r3, ret on stack)
	MOVW	R0, 8(R13)
	MOVW	R5, 12(R13)		// argsize

	BL	runtime·load_g(SB)
	BL	runtime·cgocallback_gofunc(SB)

	ADD	$16, R13, R0		// load arg
	MOVW	12(R13), R1		// load argsize
	SUB	$4, R1			// offset to return value
	MOVW	R1<<0(R0), R0		// load return value
	
	ADD	$36, R13		// free locals
	MOVM.IA.W (R13), [R4-R11, R15]	// pop {r4-r11, pc}

// uint32 tstart_stdcall(M *newm);
TEXT runtime·tstart_stdcall(SB),NOSPLIT|NOFRAME,$0
	MOVM.DB.W [R14], (R13)		// push {lr}

	MOVW	m_g0(R0), g
	MOVW	R0, g_m(g)

	// Layout new m scheduler stack on os stack.
	MOVW	R13, R0
	MOVW	R0, g_stack+stack_hi(g)
	SUB	$(64*1024), R0
	MOVW	R0, (g_stack+stack_lo)(g)
	MOVW	R0, g_stackguard0(g)
	MOVW	R0, g_stackguard1(g)

	// Set up tls
	BL      runtime·save_g(SB)

	BL	runtime·emptyfunc(SB)	// fault if stack check is wrong
	BL	runtime·mstart(SB)

	// Exit the thread.
	MOVW	$0, R0
	MOVM.IA.W (R13), [R15]		// pop {pc}

// onosstack calls fn on OS stack.
// adapted from asm_arm.s : systemstack
// func onosstack(fn unsafe.Pointer, arg uint32)
TEXT runtime·onosstack(SB),NOSPLIT,$0
	MOVW	fn+0(FP), R5	// R5 = fn
	MOVW	arg+4(FP), R6	// R6 = arg
	
	// This function can be called when there is no g
	// This indicates that we're already on the g0 stack
	CMP	$0, g
	BEQ	noswitch
	
	MOVW	g_m(g), R1	// R1 = m

	MOVW	m_gsignal(R1), R2	// R2 = gsignal
	CMP	g, R2
	B.EQ	noswitch

	MOVW	m_g0(R1), R2	// R2 = g0
	CMP	g, R2
	B.EQ	noswitch

	MOVW	m_curg(R1), R3
	CMP	g, R3
	B.EQ	switch

	// Bad: g is not gsignal, not g0, not curg. What is it?
	// Hide call from linker nosplit analysis.
	MOVW	$runtime·badsystemstack(SB), R0
	BL	(R0)
	B	runtime·abort(SB)

switch:
	// save our state in g->sched. Pretend to
	// be systemstack_switch if the G stack is scanned.
	MOVW	$runtime·systemstack_switch(SB), R3
	ADD	$4, R3, R3 // get past push {lr}
	MOVW	R3, (g_sched+gobuf_pc)(g)
	MOVW	R13, (g_sched+gobuf_sp)(g)
	MOVW	LR, (g_sched+gobuf_lr)(g)
	MOVW	g, (g_sched+gobuf_g)(g)

	// switch to g0
	MOVW	R2, g
	MOVW	(g_sched+gobuf_sp)(R2), R3
	// make it look like mstart called systemstack on g0, to stop traceback
	SUB	$4, R3, R3
	MOVW	$runtime·mstart(SB), R4
	MOVW	R4, 0(R3)
	MOVW	R3, R13

	// call target function
	MOVW	R6, R0		// arg
	BL	(R5)

	// switch back to g
	MOVW	g_m(g), R1
	MOVW	m_curg(R1), g
	MOVW	(g_sched+gobuf_sp)(g), R13
	MOVW	$0, R3
	MOVW	R3, (g_sched+gobuf_sp)(g)
	RET

noswitch:
	// Using a tail call here cleans up tracebacks since we won't stop
	// at an intermediate systemstack.
	MOVW.P	4(R13), R14	// restore LR
	MOVW	R6, R0		// arg
	B	(R5)

// Runs on OS stack. duration (in 100ns units) is in R0.
TEXT runtime·usleep2(SB),NOSPLIT|NOFRAME,$0
	MOVM.DB.W [R4, R14], (R13)	// push {r4, lr}
	MOVW	R13, R4			// Save SP
	SUB	$8, R13			// R13 = R13 - 8
	BIC	$0x7, R13		// Align SP for ABI
	RSB	$0, R0, R3		// R3 = -R0
	MOVW	$0, R1			// R1 = FALSE (alertable)
	MOVW	$-1, R0			// R0 = handle
	MOVW	R13, R2			// R2 = pTime
	MOVW	R3, 0(R2)		// time_lo
	MOVW	R0, 4(R2)		// time_hi
	MOVW	runtime·_NtWaitForSingleObject(SB), R3
	BL	(R3)
	MOVW	R4, R13			// Restore SP
	MOVM.IA.W (R13), [R4, R15]	// pop {R4, pc}

// Runs on OS stack.
TEXT runtime·switchtothread(SB),NOSPLIT|NOFRAME,$0
	MOVM.DB.W [R5, R14], (R13)  	// push {R5, lr}
	MOVW    R13, R5
	BIC	$0x7, R13		// alignment for ABI
	MOVW	runtime·_SwitchToThread(SB), R0
	BL	(R0)
	MOVW 	R5, R13			// free extra stack space
	MOVM.IA.W (R13), [R5, R15]	// pop {R5, pc}

TEXT ·publicationBarrier(SB),NOSPLIT|NOFRAME,$0-0
	B	runtime·armPublicationBarrier(SB)

// never called (cgo not supported)
TEXT runtime·read_tls_fallback(SB),NOSPLIT|NOFRAME,$0
	MOVW	$0xabcd, R0
	MOVW	R0, (R0)
	RET

// See http://www.dcl.hpi.uni-potsdam.de/research/WRK/2007/08/getting-os-information-the-kuser_shared_data-structure/
// Must read hi1, then lo, then hi2. The snapshot is valid if hi1 == hi2.
#define _INTERRUPT_TIME 0x7ffe0008
#define _SYSTEM_TIME 0x7ffe0014
#define time_lo 0
#define time_hi1 4
#define time_hi2 8

TEXT runtime·nanotime(SB),NOSPLIT,$0-8
	MOVW    $0, R0
	MOVB    runtime·useQPCTime(SB), R0
	CMP	$0, R0
	BNE	useQPC
	MOVW	$_INTERRUPT_TIME, R3
loop:
	MOVW	time_hi1(R3), R1
	MOVW	time_lo(R3), R0
	MOVW	time_hi2(R3), R2
	CMP R1, R2
	BNE	loop

	// wintime = R1:R0, multiply by 100
	MOVW	$100, R2
	MULLU	R0, R2, (R4, R3)    // R4:R3 = R1:R0 * R2
	MULA	R1, R2, R4, R4

	// wintime*100 = R4:R3, subtract startNano and return
	MOVW    runtime·startNano+0(SB), R0
	MOVW    runtime·startNano+4(SB), R1
	SUB.S   R0, R3
	SBC	R1, R4
	MOVW	R3, ret_lo+0(FP)
	MOVW	R4, ret_hi+4(FP)
	RET
useQPC:
	B	runtime·nanotimeQPC(SB)
	RET

TEXT time·now(SB),NOSPLIT,$0-20
	MOVW    $0, R0
	MOVB    runtime·useQPCTime(SB), R0
	CMP	$0, R0
	BNE	useQPC
	MOVW	$_INTERRUPT_TIME, R3
loop:
	MOVW	time_hi1(R3), R1
	MOVW	time_lo(R3), R0
	MOVW	time_hi2(R3), R2
	CMP R1, R2
	BNE	loop

	// wintime = R1:R0, multiply by 100
	MOVW	$100, R2
	MULLU	R0, R2, (R4, R3)    // R4:R3 = R1:R0 * R2
	MULA	R1, R2, R4, R4

	// wintime*100 = R4:R3, subtract startNano and return
	MOVW    runtime·startNano+0(SB), R0
	MOVW    runtime·startNano+4(SB), R1
	SUB.S   R0, R3
	SBC	R1, R4
	MOVW	R3, mono+12(FP)
	MOVW	R4, mono+16(FP)

	MOVW	$_SYSTEM_TIME, R3
wall:
	MOVW	time_hi1(R3), R1
	MOVW	time_lo(R3), R0
	MOVW	time_hi2(R3), R2
	CMP R1, R2
	BNE	wall

	// w = R1:R0 in 100ns untis
	// convert to Unix epoch (but still 100ns units)
	#define delta 116444736000000000
	SUB.S   $(delta & 0xFFFFFFFF), R0
	SBC     $(delta >> 32), R1

	// Convert to nSec
	MOVW    $100, R2
	MULLU   R0, R2, (R4, R3)    // R4:R3 = R1:R0 * R2
	MULA    R1, R2, R4, R4
	// w = R2:R1 in nSec
	MOVW    R3, R1              // R4:R3 -> R2:R1
	MOVW    R4, R2

	// multiply nanoseconds by reciprocal of 10**9 (scaled by 2**61)
	// to get seconds (96 bit scaled result)
	MOVW	$0x89705f41, R3		// 2**61 * 10**-9
	MULLU	R1,R3,(R6,R5)		// R7:R6:R5 = R2:R1 * R3
	MOVW	$0,R7
	MULALU	R2,R3,(R7,R6)

	// unscale by discarding low 32 bits, shifting the rest by 29
	MOVW	R6>>29,R6		// R7:R6 = (R7:R6:R5 >> 61)
	ORR	R7<<3,R6
	MOVW	R7>>29,R7

	// subtract (10**9 * sec) from nsec to get nanosecond remainder
	MOVW	$1000000000, R5	// 10**9
	MULLU	R6,R5,(R9,R8)   // R9:R8 = R7:R6 * R5
	MULA	R7,R5,R9,R9
	SUB.S	R8,R1		// R2:R1 -= R9:R8
	SBC	R9,R2

	// because reciprocal was a truncated repeating fraction, quotient
	// may be slightly too small -- adjust to make remainder < 10**9
	CMP	R5,R1	// if remainder > 10**9
	SUB.HS	R5,R1   //    remainder -= 10**9
	ADD.HS	$1,R6	//    sec += 1

	MOVW	R6,sec_lo+0(FP)
	MOVW	R7,sec_hi+4(FP)
	MOVW	R1,nsec+8(FP)
	RET
useQPC:
	B	runtime·nanotimeQPC(SB)
	RET

