// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "textflag.h"

//
// System calls for arm, Windows are implemented in runtime/syscall_windows.goc
//

TEXT ·getprocaddress(SB), NOSPLIT|NOFRAME, $0
	B	syscall·getprocaddress(SB)

TEXT ·loadlibrary(SB), NOSPLIT|NOFRAME, $0
	B	syscall·loadlibrary(SB)
