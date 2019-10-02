// Copyright 2019 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "go_asm.h"
#include "go_tls.h"
#include "tls_arm64.h"
#include "textflag.h"

// void runtime·asmstdcall(void *c);
TEXT runtime·asmstdcall(SB),NOSPLIT|NOFRAME,$0
    // Save non-volatile registers
    SUB     $32, RSP        // SP = SP - 32
    MOVD    R19, 0(RSP)
    MOVD    R20, 8(RSP)
    MOVD    R21, 16(RSP)

    MOVD    R0, R19         // R19 = libcall* (non-volatile)
    MOVD    RSP, R20        // R20 = SP (non-volatile)
    MOVD    LR, R21         // R21 = link register
    
    // SetLastError(0)
    WORD    $0xaa1203e1     // MOVD R18, R1
    MOVW    $0, 0x68(R1)    // According to Windows ABI, R18 holds the base of TEB struct

    MOVD    16(R19), R16    // R16 = libcall->args (intra-procedure-call scratch register)

    // Check if we have more than 8 arguments
    MOVD    8(R19), R0      // R0 = libcall->n (num args)
    SUB     $8, R0, R2      // R2 = n - 8
    CMP     $8, R0          // if (n <= 8),
    BLE     loadR7          // load registers.

    // Reserve stack space for remaining args
    LSL     $3, R2, R8      // R8 = R2<<3 = 8*(n-8)
    SUB     R8, RSP         // SP = SP - 8*(n-8)
    
    // Stack must be 16-byte aligned
    MOVD    RSP, R13
    BIC     $0xF, R13
    MOVD    R13, RSP

    // Push the additional args on stack
    MOVD    $0, R2          // i = 0
pushargsonstack:
    ADD     $8, R2, R3      // R3 = 8 + i
    LSL     $3, R3          // R3 = R3<<3 = 8*(8+i)
    MOVD    (R3)(R16), R3   // R3 = args[8+i]
    LSL     $3, R2, R8      // R8 = R2<<3 = 8*(i)
    MOVD    RSP, R9
    MOVD    R3, (R8)(R9)   // stack[i] = R3 = args[8+i]
    ADD     $1, R2          // i++
    SUB     $8, R0, R3      // R3 = n - 8
    CMP     R3, R2          // while(i < (n - 8)),
    BLT     pushargsonstack // push args

    // Load parameter registers
loadR7:
    CMP     $7, R0          // if(n <= 7),
    BLE     loadR6          // jump to load args[6]
    MOVD    56(R16), R7     // R7 = args[7]
loadR6:
    CMP     $6, R0          // if(n <= 6),
    BLE     loadR5          // jump to load args[5]
    MOVD    48(R16), R6     // R6 = args[6]
loadR5:
    CMP     $5, R0          // if(n <= 5),
    BLE     loadR4          // jump to load args[4]
    MOVD    40(R16), R5     // R5 = args[5]
loadR4:
    CMP     $4, R0          // if(n <= 4),
    BLE     loadR3          // jump to load args[3]
    MOVD    32(R16), R4     // R4 = args[4]
loadR3:
    CMP     $3, R0          // if(n <= 3),
    BLE     loadR2          // jump to load args[2]
    MOVD    24(R16), R3     // R3 = args[3]
loadR2:
    CMP     $2, R0          // if(n <= 2),
    BLE     loadR1          // jump to load args[1]
    MOVD    16(R16), R2     // R2 = args[2]
loadR1:
    CMP     $1, R0          // if(n <= 1),
    BLE     loadR0          // jump to load args[0]
    MOVD    8(R16), R1      // R1 = args[1]
loadR0:
    CMP     $0, R0          // if(n <= 0),
    BLE     argsloaded      // no args to load
    MOVD    0(R16), R0      // R0 = args[0]

argsloaded:
    // Stack must be 16-byte aligned
    MOVD    RSP, R13
    BIC     $0xF, R13
    MOVD    R13, RSP

    // Call fn
    MOVD    0(R19), R16     // R16 = libcall->fn
    BL      (R16)           // branch to libcall->fn 
    MOVD    R21, LR         // restore link register
    
    // Free stack space
    MOVD    R20, RSP

    // Save return values
    MOVD    R0, 24(R19)
    MOVD    R1, 32(R19)     // Note(ragav): R1 is not a result register in ARM64. Double check this line.
    
    // GetLastError
    WORD    $0xaa1203e0         // MOVD R18, R0
    MOVW    0x68(R0), R1        // R1 = LastError
    MOVW    R1, 40(R19)         // libcall->err = error

    // Restore non-volatile registers
    MOVD    0(RSP), R19
    MOVD    8(RSP), R20
    MOVD    16(RSP), R21
    ADD     $32, RSP        // SP = SP + 32
    RET

TEXT runtime·badsignal2(SB),NOSPLIT|NOFRAME,$0
    MOVD    $1101, R19
    BRK
    RET

TEXT runtime·getlasterror(SB),NOSPLIT,$0
    WORD    $0xaa1203e1     // MOVD R18, R1
    MOVD    0x68(R1), R0
    MOVD    R0, ret+0(FP)
    RET

TEXT runtime·setlasterror(SB),NOSPLIT|NOFRAME,$0
    WORD    $0xaa1203e1     // MOVD R18, R1
    MOVW    R0, 0x68(R1)
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
    MOVD    $701, R19
    BRK
    RET

//
// Trampoline to resume execution from exception handler.
// This is part of the control flow guard workaround.
// It switches stacks and jumps to the continuation address.
 TEXT runtime·returntramp(SB),NOSPLIT|NOFRAME,$0
    MOVD    $801, R19
    BRK
    RET

TEXT runtime·exceptiontramp(SB),NOSPLIT|NOFRAME,$0
    // @ MOVD   $runtime·exceptionhandler(SB), R1       // sigmtramp needs handler function in R1
    // @ B  runtime·sigtramp(SB)
    MOVD    $702, R19
    BRK
    RET

TEXT runtime·firstcontinuetramp(SB),NOSPLIT|NOFRAME,$0
    // @ MOVD   $runtime·firstcontinuehandler(SB), R1   // sigmtramp needs handler function in R1
    // @ B  runtime·sigtramp(SB)
    MOVD    $703, R19
    BRK
    RET

TEXT runtime·lastcontinuetramp(SB),NOSPLIT|NOFRAME,$0
    // @ MOVD   $runtime·lastcontinuehandler(SB), R1    // sigmtramp needs handler function in R1
    // @ B  runtime·sigtramp(SB)
    MOVD    $704, R19
    BRK
    RET

TEXT runtime·ctrlhandler(SB),NOSPLIT|NOFRAME,$0
    // @ MOVD   $runtime·ctrlhandler1(SB), R1           // sigmtramp needs handler function in R1
    // @ B  runtime·externalthreadhandler(SB)
    MOVD    $705, R19
    BRK
    RET

TEXT runtime·profileloop(SB),NOSPLIT|NOFRAME,$0
    // @ MOVD   $runtime·profileloop1(SB), R1           // sigmtramp needs handler function in R1
    // @ B  runtime·externalthreadhandler(SB)
    MOVD    $7055, R19
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
// 16| param1         |
//   +----------------+
// 8 | param0         |
//   +----------------+
// 0 | retval         |
//   +----------------+
//
TEXT runtime·externalthreadhandler(SB),NOFRAME,$0
    // TODO(ragav): Check if the function needs to be nosplit.
    MOVD    $706, R19
    BRK
    RET

GLOBL runtime·cbctxts(SB), NOPTR, $4

TEXT runtime·callbackasm1(SB),NOSPLIT|NOFRAME,$0
    MOVD    $707, R19
    BRK
    RET

// uint32 tstart_stdcall(M *newm);
TEXT runtime·tstart_stdcall(SB),NOSPLIT|NOFRAME,$0
    // Todo(ragav): save non-volatile registers, if needed
    SUB     $16, RSP
    MOVD    R21, 0(RSP)
    MOVD    LR, R21

    MOVD    m_g0(R0), g
    MOVD    R0, g_m(g)
    BL  runtime·save_g(SB)

    // do per-thread TLS initialization
    BL  runtime·init_thread_tls(SB)

    // Layout new m scheduler stack on os stack.
    MOVD    RSP, R0
    MOVD    R0, (g_stack+stack_hi)(g)
    SUB     $(64*1024), R0
    MOVD    R0, (g_stack+stack_lo)(g)
    MOVD    R0, g_stackguard0(g)
    MOVD    R0, g_stackguard1(g)

    BL  runtime·emptyfunc(SB)   // fault if stack check is wrong
    BL  runtime·mstart(SB)

    // Exit the thread.
    MOVD    $0, R0

    MOVD    R21, LR
    MOVD    0(RSP), R21
    ADD     $16, RSP
    RET

TEXT runtime·emptyfunc(SB),0,$0-0
    RET

// onosstack calls fn on OS stack.
// adapted from asm_arm.s : systemstack
// func onosstack(fn unsafe.Pointer, arg uint32)
TEXT runtime·onosstack(SB), NOSPLIT, $0
    MOVD    fn+0(FP), R19   // R19 = fn
    MOVD    arg+8(FP), R20  // R20 = arg

    // This function can be called when there is no g,
    // for example, when we are handling a callback on a non-go thread.
    // In this case we're already on the system stack.
    CMP $0, g
    BEQ noswitch

    MOVD    g_m(g), R4  // R4 = m

    MOVD    m_gsignal(R4), R5   // R5 = gsignal
    CMP g, R5
    BEQ noswitch

    MOVD    m_g0(R4), R5    // R5 = g0
    CMP g, R5
    BEQ noswitch

    MOVD    m_curg(R4), R6
    CMP g, R6
    BEQ switch

    // Bad: g is not gsignal, not g0, not curg. What is it?
    // Hide call from linker nosplit analysis.
    MOVD    $runtime·badsystemstack(SB), R19
    BL  (R19)
    B   runtime·abort(SB)

switch:
    // save our state in g->sched. Pretend to
    // be systemstack_switch if the G stack is scanned.
    MOVD    $runtime·systemstack_switch(SB), R6
    ADD $8, R6  // get past prologue
    MOVD    R6, (g_sched+gobuf_pc)(g)
    MOVD    RSP, R0
    MOVD    R0, (g_sched+gobuf_sp)(g)
    MOVD    R29, (g_sched+gobuf_bp)(g)
    MOVD    $0, (g_sched+gobuf_lr)(g)
    MOVD    g, (g_sched+gobuf_g)(g)

    // switch to g0
    MOVD    R5, g
    BL  runtime·save_g(SB)
    MOVD    (g_sched+gobuf_sp)(g), R3
    // make it look like mstart called systemstack on g0, to stop traceback
    SUB $16, R3
    AND $~15, R3
    MOVD    $runtime·mstart(SB), R4
    MOVD    R4, 0(R3)
    MOVD    R3, RSP
    MOVD    (g_sched+gobuf_bp)(g), R29

    // call target function
    MOVD    R20, R0 // args
    BL  (R19)

    // switch back to g
    MOVD    g_m(g), R19
    MOVD    m_curg(R19), g
    BL  runtime·save_g(SB)
    MOVD    (g_sched+gobuf_sp)(g), R0
    MOVD    R0, RSP
    MOVD    (g_sched+gobuf_bp)(g), R29
    MOVD    $0, (g_sched+gobuf_sp)(g)
    MOVD    $0, (g_sched+gobuf_bp)(g)
    RET

noswitch:
    // already on m stack, just call directly
    // Using a tail call here cleans up tracebacks since we won't stop
    // at an intermediate systemstack.
    MOVD.P  16(RSP), R30    // restore LR
    SUB $8, RSP, R29    // restore FP
    MOVD    R20, R0     // arg
    B   (R19)

// Runs on OS stack. Duration (in 100ns units) is in R0.
TEXT runtime·usleep2(SB),NOSPLIT|NOFRAME,$0
    // Save non-volatile registers
    SUB     $16, RSP        // SP = SP - 16
    MOVD    R19, 0(RSP)
    MOVD    LR, 8(RSP)
    MOVD    RSP, R19        // Save SP

    // Stack must be 16-byte aligned
    MOVD    RSP, R13
    BIC     $0xF, R13
    MOVD    R13, RSP

    MOVD    $0, R8
    SUB     R0, R8, R3      // R3 = -R0 Note(ragav): orignally RSB instruction was used
    
    MOVD    $0, R1          // R1 = FALSE (alertable)
    MOVD    $-1, R0         // R0 = handle
    MOVD    RSP, R2         // R2 = pTime
    MOVD    R3, (R2)
    
    MOVD    runtime·_NtWaitForSingleObject(SB), R3
    BL      (R3)
    MOVD    R19, RSP            // Restore SP

    // Restore non-volatile registers
    MOVD    0(RSP), R19
    MOVD    8(RSP), LR
    ADD     $16, RSP
    RET

// Runs on OS stack.
TEXT runtime·switchtothread(SB),NOSPLIT|NOFRAME,$0
    // Save non-volatile registers
    SUB     $16, RSP        // SP = SP - 16
    MOVD    R19, 0(RSP)
    MOVD    LR, 8(RSP)
    MOVD    RSP, R19

    // Stack must be 16-byte aligned
    MOVD    RSP, R13
    BIC     $0xF, R13
    MOVD    R13, RSP

    MOVD    runtime·_SwitchToThread(SB), R0
    BL      (R0)
    MOVD    R19, RSP            // restore stack pointer

    // Restore non-volatile registers
    MOVD    0(RSP), R19
    MOVD    8(RSP), LR 
    ADD     $16, RSP
    RET

// never called (cgo not supported)
TEXT runtime·read_tls_fallback(SB),NOSPLIT|NOFRAME,$0
    // @ MOVD   $0xabcd, R0
    // @ MOVD   R0, (R0)
    MOVD    $712, R19
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
    MOVD    $0, R0
    MOVB    runtime·useQPCTime(SB), R0
    CMP     $0, R0
    BNE     useQPC
    MOVD    $_INTERRUPT_TIME, R3
 loop:
    MOVW    time_hi1(R3), R1
    MOVW    time_lo(R3), R0
    MOVW    time_hi2(R3), R2
    CMP     R1, R2
    BNE     loop
// TODO(ragav): need to verify the correctness of the following logic
    LSL     $32, R1                     // R1 = [time_hi:0]
    BIC     $0xffffffff00000000, R0     // R0 = [0:time_low]
    ORR     R1, R0, R1                  // R1 = [time_hi:time_low]
    MOVD    $100, R0        
    MUL     R0, R1                      // R1 = [time_hi:time_low]*100
    MOVD    R1, ret+0(FP)
    RET
 useQPC:
    B   runtime·nanotimeQPC(SB)     // tail call

TEXT time·now(SB),NOSPLIT,$0-24
    MOVD    $0, R0
    MOVB    runtime·useQPCTime(SB), R0
    CMP     $0, R0
    BNE     useQPC
    MOVD    $_INTERRUPT_TIME, R3
loop:
    MOVW    time_hi1(R3), R1
    MOVW    time_lo(R3), R0
    MOVW    time_hi2(R3), R2
    CMP     R1, R2
    BNE     loop
    LSL     $32, R1                     // R1 = [time_hi_00]
    BIC     $0xffffffff00000000, R0     // R0 = [00_time_low]
    ORR     R1, R0, R1                  // R1 = [time_hi_time_low] = [time]
    MOVD    $100, R0        
    MUL     R0, R1                      // R1 = [time]*100
    MOVD    R1, mono+16(FP)

    MOVW    $_SYSTEM_TIME, R3
wall:
    MOVW    time_hi1(R3), R1
    MOVW    time_lo(R3), R0
    MOVW    time_hi2(R3), R2
    CMP     R1, R2
    BNE     wall
    LSL     $32, R1                     // R1 = [time_hi_00]
    BIC     $0xffffffff00000000, R0     // R0 = [00_time_low]
    ORR     R1, R0, R1                  // R1 = [time_hi_time_low] = [time]
    MOVD    $116444736000000000, R0
    SUB     R0, R1
    MOVD    $100, R0
    MUL     R0, R1                      // convert to nanosec

    MOVD    $0x3b9aca00, R2             // R2 = 10^9
    UDIV    R2, R1, R0                  // R0 = R1 / 10^9
    MSUB    R0, R1, R2, R3              // R3 = R1 - (R0 * 10^9) = R1 % 10^9

    MOVD    R0, sec+0(FP)
    MOVW    R3, nsec+8(FP)
    RET
useQPC:
    B   runtime·nanotimeQPC(SB)     // tail call
    RET

TEXT runtime·alloc_tls(SB),NOSPLIT|NOFRAME,$0
    // Save non-volatile registers
    SUB     $16, RSP        // SP = SP - 16
    MOVD    R19, 0(RSP)
    MOVD    LR, 8(RSP)

    MOVD    RSP, R19
    // Stack must be 16-byte aligned
    MOVD    RSP, R13
    BIC     $0xF, R13
    MOVD    R13, RSP

    // Allocate a TLS slot to hold g across calls to external code
    MOVD    $runtime·_TlsAlloc(SB), R0
    MOVD    (R0), R0
    BL  (R0)

    // Assert that slot is less than 64 so we can use _TEB->TlsSlots
    CMP     $64, R0
    MOVD    $runtime·abort(SB), R1
    BLT     2(PC)
    BL      (R1)

    // Save Slot into tls_g
    MOVD    $runtime·tls_g(SB), R1
    MOVD    R0, (R1)

    BL  runtime·init_thread_tls(SB)

    MOVD    R19, RSP
    // Restore non-volatile registers
    MOVD    0(RSP), R19
    MOVD    8(RSP), LR
    ADD     $16, RSP
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
    WORD    $0xaa1203e0     // MOVD R18, R0
    ADD     $0xe10, R0
    MOVD    $runtime·tls_g(SB), R1
    MOVD    (R1), R1
    LSL     $2, R1, R1
    ADD     R1, R0

    // save in g->m->tls[0]
    MOVD    g_m(g), R1
    MOVD    R0, m_tls(R1)
    RET
