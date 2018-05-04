// Copyright 2011 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "go_asm.h"
#include "go_tls.h"
#include "textflag.h"

// Stub stub stub

// This is the entry point for the program from the
// kernel for an ordinary -buildmode=exe program. The stack holds the
// number of arguments and the C-style argv.
TEXT _rt0_arm_windows(SB),NOSPLIT|NOFRAME,$0
    B	_rt0_arm(SB)

// When building with -buildmode=(c-shared or c-archive), this
// symbol is called. For dynamic libraries it is called when the
// library is loaded. For static libraries it is called when the
// final executable starts, during the C runtime initialization
// phase.
/*
TEXT _rt0_arm_windows_lib(SB),NOSPLIT|NOFRAME,$0x1C
	MOVL	BP, 0x08(SP)
	MOVL	BX, 0x0C(SP)
	MOVL	AX, 0x10(SP)
	MOVL  CX, 0x14(SP)
	MOVL  DX, 0x18(SP)

	// Create a new thread to do the runtime initialization and return.
	MOVL	_cgo_sys_thread_create(SB), AX
	MOVL	$_rt0_arm_windows_lib_go(SB), 0x00(SP)
	MOVL	$0, 0x04(SP)

	 // Top two items on the stack are passed to _cgo_sys_thread_create
	 // as parameters. This is the calling convention on 32-bit Windows.
	CALL	AX

	MOVL	0x08(SP), BP
	MOVL	0x0C(SP), BX
	MOVL	0x10(SP), AX
	MOVL	0x14(SP), CX
	MOVL	0x18(SP), DX
	RET
*/
// When building with -buildmode=c-shared, this symbol is called when the shared
// library is loaded.
TEXT _rt0_arm_windows_lib(SB),NOSPLIT|NOFRAME,$0
	B	_rt0_arm_lib(SB)
