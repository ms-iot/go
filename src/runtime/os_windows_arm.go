// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package runtime

// Stub stub

const (
	_AT_PLATFORM = 15 //  introduced in at least 2.6.11

	_HWCAP_VFP   = 1 << 6  // introduced in at least 2.6.11
	_HWCAP_VFPv3 = 1 << 13 // introduced in 2.6.30
	_HWCAP_IDIVA = 1 << 17
)

var hwcap uint32      // set by archauxv
var hardDiv bool      // set if a hardware divider is available

//go:nosplit
func cputicks() int64 {
	return nanotime()
}

func archauxv(tag, val uintptr) {
	switch tag {
	case _AT_HWCAP: // CPU capability bit flags
		hwcap = uint32(val)
		hardDiv = (hwcap & _HWCAP_IDIVA) != 0
	}
}

func checkgoarm() {
    /*
	if goarm < 7 {
		print("atomic synchronization instructions. Recompile using GOARM=7.\n")
		exit(1)
	}
    */
}
