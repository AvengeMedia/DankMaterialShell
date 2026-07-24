package bluez

import "os"

// linux/rfkill.h: struct rfkill_event { __u32 idx; __u8 type; __u8 op; __u8 soft; __u8 hard; },
// RFKILL_TYPE_BLUETOOTH=2, RFKILL_OP_CHANGE_ALL=3
func rfkillUnblockBluetooth() error {
	f, err := os.OpenFile("/dev/rfkill", os.O_WRONLY, 0)
	if err != nil {
		return err
	}
	defer f.Close()

	var event [8]byte
	event[4] = 2
	event[5] = 3
	_, err = f.Write(event[:])
	return err
}
