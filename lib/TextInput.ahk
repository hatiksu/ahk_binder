class TextInput {
    static Put(text, target) {
        if DllCall('GetForegroundWindow', 'ptr') != target
            return false
        delay := A_KeyDelay, duration := A_KeyDuration
        try {
            SetKeyDelay -1, -1
            SendInput '{Text}' text
        } finally
            SetKeyDelay delay, duration
        return DllCall('GetForegroundWindow', 'ptr') = target
    }
}
