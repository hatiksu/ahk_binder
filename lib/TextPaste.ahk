class TextPaste {
    static busy := false
    static Put(text, target) {
        if DllCall('GetForegroundWindow', 'ptr') != target
            return false
        return this.WithClipboard(text, Deliver)
        Deliver() {
            if DllCall('GetForegroundWindow', 'ptr') != target
                return false
            SendInput '^v'
            Sleep 120
            return DllCall('GetForegroundWindow', 'ptr') = target
        }
    }
    static WithClipboard(text, deliver) {
        if this.busy
            return false
        this.busy := true
        sequence := 0
        try {
            saved := ClipboardAll()
            A_Clipboard := text
            sequence := DllCall('GetClipboardSequenceNumber', 'uint')
            if !ClipWait(0.5)
                return false
            return deliver.Call()
        } finally {
            try {
                if IsSet(saved) && sequence && DllCall('GetClipboardSequenceNumber', 'uint') = sequence
                    A_Clipboard := saved
            }
            this.busy := false
        }
    }
}
