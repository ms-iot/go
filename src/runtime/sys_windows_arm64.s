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