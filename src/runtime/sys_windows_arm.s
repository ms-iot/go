// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "go_asm.h"
#include "go_tls.h"
#include "textflag.h"

// Stub stub stub

// void runtime·asmstdcall(void *c);
TEXT runtime·asmstdcall(SB),NOSPLIT,$0

	MOVW	fn+0(FP), R0
/*
	// SetLastError(0).
	MOVW	$0, 0x34(FS)

	// Copy args to the stack.
	MOVW	SP, BP
	MOVW	libcall_n(BX), CX	// words
	MOVW	CX, AX
	SLL	    $2, AX
	SUB	    AX, SP			// room for args
	MOVW	SP, DI
	MOVW	libcall_args(BX), SI
	//CLD
	//REP; MOVSL

	// Call stdcall or cdecl function.
	// DI SI BP BX are preserved, SP is not
	CALL	libcall_fn(BX)
	MOVW	BP, SP

	// Return result.
	MOVW	fn+0(FP), BX
	MOVW	AX, libcall_r1(BX)
	MOVW	DX, libcall_r2(BX)

	// GetLastError().
	MOVW	0x34(FS), AX
	MOVW	AX, libcall_err(BX)
*/
	RET

TEXT	runtime·badsignal2(SB),NOSPLIT,$24
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
	RET

// faster get/set last error
TEXT runtime·getlasterror(SB),NOSPLIT,$0
/*
	MOVW	0x34(FS), AX
	MOVW	AX, ret+0(FP)
*/
	RET

TEXT runtime·setlasterror(SB),NOSPLIT,$0
/*
	MOVW	err+0(FP), AX
	MOVW	AX, 0x34(FS)
*/
	RET

// Called by Windows as a Vectored Exception Handler (VEH).
// First argument is pointer to struct containing
// exception record and context pointers.
// Handler function is stored in AX.
// Return 0 for 'not handled', -1 for handled.
TEXT runtime·sigtramp(SB),NOSPLIT,$0-0
/*
	MOVW	ptrs+0(FP), CX
	SUB	    $40, SP

	// save callee-saved registers
	MOVW	BX, 28(SP)
	MOVW	BP, 16(SP)
	MOVW	SI, 20(SP)
	MOVW	DI, 24(SP)

	MOVW	AX, SI	// save handler address

	// find g
	get_tls(DX)
	CMPL	DX, $0
	JNE	3(PC)
	MOVW	$0, AX // continue
	JMP	done
	MOVW	g(DX), DX
	CMPL	DX, $0
	JNE	2(PC)
	CALL	runtime·badsignal2(SB)

	// save g and SP in case of stack switch
	MOVW	DX, 32(SP)	// g
	MOVW	SP, 36(SP)

	// do we need to switch to the g0 stack?
	MOVW	g_m(DX), BX
	MOVW	m_g0(BX), BX
	CMPL	DX, BX
	JEQ	g0

	// switch to the g0 stack
	get_tls(BP)
	MOVW	BX, g(BP)
	MOVW	(g_sched+gobuf_sp)(BX), DI
	// make it look like mstart called us on g0, to stop traceback
	SUB	    $4, DI
	MOVW	$runtime·mstart(SB), 0(DI)
	// traceback will think that we've done SUB
	// on this stack, so subtract them here to match.
	// (we need room for sighandler arguments anyway).
	// and re-save old SP for restoring later.
	SUB	    $40, DI
	MOVW	SP, 36(DI)
	MOVW	DI, SP

g0:
	MOVW	0(CX), BX // ExceptionRecord*
	MOVW	4(CX), CX // Context*
	MOVW	BX, 0(SP)
	MOVW	CX, 4(SP)
	MOVW	DX, 8(SP)
	CALL	SI	// call handler
	// AX is set to report result back to Windows
	MOVW	12(SP), AX

	// switch back to original stack and g
	// no-op if we never left.
	MOVW	36(SP), SP
	MOVW	32(SP), DX
	get_tls(BP)
	MOVW	DX, g(BP)

done:
	// restore callee-saved registers
	MOVW	24(SP), DI
	MOVW	20(SP), SI
	MOVW	16(SP), BP
	MOVW	28(SP), BX

	ADDL	$40, SP
	// RET 4 (return and pop 4 bytes parameters)
	BYTE $0xC2; WORD $4
*/
	RET // unreached; make assembler happy

TEXT runtime·exceptiontramp(SB),NOSPLIT,$0
//	MOVW	$runtime·exceptionhandler(SB), AX
	JMP	runtime·sigtramp(SB)

TEXT runtime·firstcontinuetramp(SB),NOSPLIT,$0-0
	// is never called
//	INT	$3

TEXT runtime·lastcontinuetramp(SB),NOSPLIT,$0-0
//	MOVW	$runtime·lastcontinuehandler(SB), AX
	JMP	runtime·sigtramp(SB)

TEXT runtime·ctrlhandler(SB),NOSPLIT,$0
/*
	PUSHL	$runtime·ctrlhandler1(SB)
	CALL	runtime·externalthreadhandler(SB)
	MOVW	4(SP), CX
	ADDL	$12, SP
	JMP	CX
*/
    // Stub
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
	RET

GLOBL runtime·cbctxts(SB), NOPTR, $4

TEXT runtime·callbackasm1+0(SB),NOSPLIT,$0
/*
  	MOVW	0(SP), AX	// will use to find our callback context

	// remove return address from stack, we are not returning there
	ADDL	$4, SP

	// address to callback parameters into CX
	LEAL	4(SP), CX

	// save registers as required for windows callback
	PUSHL	DI
	PUSHL	SI
	PUSHL	BP
	PUSHL	BX

	// determine index into runtime·cbctxts table
	SUB	    $runtime·callbackasm(SB), AX
	MOVW	$0, DX
	MOVW	$5, BX	// divide by 5 because each call instruction in runtime·callbacks is 5 bytes long
	DIVL	BX

	// find correspondent runtime·cbctxts table entry
	MOVW	runtime·cbctxts(SB), BX
	MOVW	-4(BX)(AX*4), BX

	// extract callback context
	MOVW	wincallbackcontext_gobody(BX), AX
	MOVW	wincallbackcontext_argsize(BX), DX

	// preserve whatever's at the memory location that
	// the callback will use to store the return value
	PUSHL	0(CX)(DX*1)

	// extend argsize by size of return value
	ADDL	$4, DX

	// remember how to restore stack on return
	MOVW	wincallbackcontext_restorestack(BX), BX
	PUSHL	BX

	// call target Go function
	PUSHL	DX			// argsize (including return value)
	PUSHL	CX			// callback parameters
	PUSHL	AX			// address of target Go function
	//CLD
	CALL	runtime·cgocallback_gofunc(SB)
	POPL	AX
	POPL	CX
	POPL	DX

	// how to restore stack on return
	POPL	BX

	// return value into AX (as per Windows spec)
	// and restore previously preserved value
	MOVW	-4(CX)(DX*1), AX
	POPL	-4(CX)(DX*1)

	MOVW	BX, CX			// cannot use BX anymore

	// restore registers as required for windows callback
	POPL	BX
	POPL	BP
	POPL	SI
	POPL	DI

	// remove callback parameters before return (as per Windows spec)
	POPL	DX
	ADDL	CX, SP
	PUSHL	DX

	//CLD
*/
	RET

// void tstart(M *newm);
TEXT runtime·tstart(SB),NOSPLIT,$0
/*
	MOVW	newm+0(FP), CX		// m
	MOVW	m_g0(CX), DX		// g

	// Layout new m scheduler stack on os stack.
	MOVW	SP, AX
	MOVW	AX, (g_stack+stack_hi)(DX)
	SUB	    $(64*1024), AX		// stack size
	MOVW	AX, (g_stack+stack_lo)(DX)
	ADDL	$const__StackGuard, AX
	MOVW	AX, g_stackguard0(DX)
	MOVW	AX, g_stackguard1(DX)

	// Set up tls.
	LEAL	m_tls(CX), SI
	MOVW	SI, 0x14(FS)
	MOVW	CX, g_m(DX)
	MOVW	DX, g(SI)

	// Someday the convention will be D is always cleared.
	//CLD

	CALL	runtime·stackcheck(SB)	// clobbers AX,CX
	CALL	runtime·mstart(SB)
*/
	RET

// uint32 tstart_stdcall(M *newm);
TEXT runtime·tstart_stdcall(SB),NOSPLIT,$0
/*
	MOVW	newm+0(FP), BX

	PUSHL	BX
	CALL	runtime·tstart(SB)
	POPL	BX

	// Adjust stack for stdcall to return properly.
	MOVW	(SP), AX		// save return address
	ADDL	$4, SP			// remove single parameter
	MOVW	AX, (SP)		// restore return address

	XORL	AX, AX			// return 0 == success
*/
	RET

// setldt(int entry, int address, int limit)
TEXT runtime·setldt(SB),NOSPLIT,$0
/*
	MOVW	address+4(FP), CX
	MOVW	CX, 0x14(FS)
*/
	RET

// onosstack calls fn on OS stack.
// func onosstack(fn unsafe.Pointer, arg uint32)
TEXT runtime·onosstack(SB),NOSPLIT,$0
/*
	MOVW	fn+0(FP), AX		// to hide from 8l
	MOVW	arg+4(FP), BX

	// Execute call on m->g0 stack, in case we are not actually
	// calling a system call wrapper, like when running under WINE.
	get_tls(CX)
	CMPL	CX, $0
	JNE	3(PC)
	// Not a Go-managed thread. Do not switch stack.
	CALL	AX
	RET

	MOVW	g(CX), BP
	MOVW	g_m(BP), BP

	// leave pc/sp for cpu profiler
	MOVW	(SP), SI
	MOVW	SI, m_libcallpc(BP)
	MOVW	g(CX), SI
	MOVW	SI, m_libcallg(BP)
	// sp must be the last, because once async cpu profiler finds
	// all three values to be non-zero, it will use them
	LEAL	usec+0(FP), SI
	MOVW	SI, m_libcallsp(BP)

	MOVW	m_g0(BP), SI
	CMPL	g(CX), SI
	JNE	switch
	// executing on m->g0 already
	CALL	AX
	JMP	ret

switch:
	// Switch to m->g0 stack and back.
	MOVW	(g_sched+gobuf_sp)(SI), SI
	MOVW	SP, -4(SI)
	LEAL	-4(SI), SP
	CALL	AX
	MOVW	0(SP), SP

ret:
	get_tls(CX)
	MOVW	g(CX), BP
	MOVW	g_m(BP), BP
	MOVW	$0, m_libcallsp(BP)
*/
	RET

// Runs on OS stack. duration (in 100ns units) is in BX.
TEXT runtime·usleep2(SB),NOSPLIT,$20
/*
	// Want negative 100ns units.
	NEGL	BX
	MOVW	$-1, hi-4(SP)
	MOVW	BX, lo-8(SP)
	LEAL	lo-8(SP), BX
	MOVW	BX, ptime-12(SP)
	MOVW	$0, alertable-16(SP)
	MOVW	$-1, handle-20(SP)
	MOVW	SP, BP
	MOVW	runtime·_NtWaitForSingleObject(SB), AX
	CALL	AX
	MOVW	BP, SP
*/
	RET

// Runs on OS stack.
TEXT runtime·switchtothread(SB),NOSPLIT,$0
/*
	MOVW	SP, BP
	MOVW	runtime·_SwitchToThread(SB), AX
	CALL	AX
	MOVW	BP, SP
*/
	RET

TEXT ·publicationBarrier(SB),NOSPLIT|NOFRAME,$0-0
	B	runtime·armPublicationBarrier(SB)

// never called (cgo not supported)
TEXT runtime·read_tls_fallback(SB),NOSPLIT|NOFRAME,$0
	MOVW	$0, R0
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
/*
	CMPB	runtime·useQPCTime(SB), $0
	JNE	useQPC
loop:
	MOVW	(_INTERRUPT_TIME+time_hi1), AX
	MOVW	(_INTERRUPT_TIME+time_lo), CX
	MOVW	(_INTERRUPT_TIME+time_hi2), DI
	CMPL	AX, DI
	JNE	loop

	// wintime = DI:CX, multiply by 100
	MOVW	$100, AX
	MULL	CX
	IMULL	$100, DI
	ADDL	DI, DX
	// wintime*100 = DX:AX, subtract startNano and return
	SUB	    runtime·startNano+0(SB), AX
	SBBL	runtime·startNano+4(SB), DX
	MOVW	AX, ret_lo+0(FP)
	MOVW	DX, ret_hi+4(FP)
	RET
useQPC:
*/
	JMP	runtime·nanotimeQPC(SB)
	RET

TEXT time·now(SB),NOSPLIT,$0-20
    MOVW	runtime·useQPCTime(SB), R0
    CMP     $0, R0
	BNE	    useQPC
/*
loop:
	MOVW	(_INTERRUPT_TIME+time_hi1), AX
	MOVW	(_INTERRUPT_TIME+time_lo), CX
	MOVW	(_INTERRUPT_TIME+time_hi2), DI
	CMPL	AX, DI
	JNE	loop

	// w = DI:CX
	// multiply by 100
	MOVW	$100, AX
	MULL	CX
	IMULL	$100, DI
	ADDL	DI, DX
	// w*100 = DX:AX
	// subtract startNano and save for return
	SUB	    runtime·startNano+0(SB), AX
	SBBL	runtime·startNano+4(SB), DX
	MOVW	AX, mono+12(FP)
	MOVW	DX, mono+16(FP)

wall:
	MOVW	(_SYSTEM_TIME+time_hi1), CX
	MOVW	(_SYSTEM_TIME+time_lo), AX
	MOVW	(_SYSTEM_TIME+time_hi2), DX
	CMPL	CX, DX
	JNE	wall
	
	// w = DX:AX
	// convert to Unix epoch (but still 100ns units)
	#define delta 116444736000000000
	SUB	$(delta & 0xFFFFFFFF), AX
	SBBL $(delta >> 32), DX
	
	// nano/100 = DX:AX
	// split into two decimal halves by div 1e9.
	// (decimal point is two spots over from correct place,
	// but we avoid overflow in the high word.)
	MOVW	$1000000000, CX
	DIVL	CX
	MOVW	AX, DI
	MOVW	DX, SI
	
	// DI = nano/100/1e9 = nano/1e11 = sec/100, DX = SI = nano/100%1e9
	// split DX into seconds and nanoseconds by div 1e7 magic multiply.
	MOVW	DX, AX
	MOVW	$1801439851, CX
	MULL	CX
	SHRL	$22, DX
	MOVW	DX, BX
	IMULL	$10000000, DX
	MOVW	SI, CX
	SUB	DX, CX
	
	// DI = sec/100 (still)
	// BX = (nano/100%1e9)/1e7 = (nano/1e9)%100 = sec%100
	// CX = (nano/100%1e9)%1e7 = (nano%1e9)/100 = nsec/100
	// store nsec for return
	IMULL	$100, CX
	MOVW	CX, nsec+8(FP)

	// DI = sec/100 (still)
	// BX = sec%100
	// construct DX:AX = 64-bit sec and store for return
	MOVW	$0, DX
	MOVW	$100, AX
	MULL	DI
	ADDL	BX, AX
	ADCL	$0, DX
	MOVW	AX, sec+0(FP)
	MOVW	DX, sec+4(FP)
	RET
*/
useQPC:
	JMP	runtime·nowQPC(SB)
	RET
