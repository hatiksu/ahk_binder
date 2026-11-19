class GameWindow {
    __New(ini) {
        this.ini := ini
        this.mode := IniRead(ini, 'Window', 'Mode', 'auto')
        this.title := IniRead(ini, 'Window', 'Title', '')
        this.className := IniRead(ini, 'Window', 'Class', '')
        this.hwnd := 0, this.pid := 0
    }
    static Matches(title, className) {
        return className = 'grcWindow' && RegExMatch(title, 'i)(Grand Theft Auto V\b|GTA ?(?:V|5)\b|RAGE Multiplayer|Majestic)') && !RegExMatch(title, 'i)launcher')
    }
    Active() {
        if !this.hwnd || DllCall('GetForegroundWindow', 'ptr') != this.hwnd
            return false
        DllCall('GetWindowThreadProcessId', 'ptr', this.hwnd, 'uint*', &ownerPID := 0)
        return ownerPID = this.pid
    }
    Refresh() {
        if this.hwnd && DllCall('IsWindow', 'ptr', this.hwnd) {
            try {
                if WinGetPID(this.hwnd) = this.pid
                    return this.hwnd
            }
        }
        this.hwnd := 0
        for hwnd in WinGetList() {
            try {
                title := WinGetTitle(hwnd), className := WinGetClass(hwnd)
                match := this.mode = 'auto' ? GameWindow.Matches(title, className) : title = this.title && className = this.className
                if match && WinGetPID(hwnd) != DllCall('GetCurrentProcessId', 'uint') {
                    this.hwnd := hwnd, this.pid := WinGetPID(hwnd)
                    break
                }
            }
        }
        return this.hwnd
    }
    Use(hwnd := 0) {
        this.mode := hwnd ? 'manual' : 'auto'
        this.title := hwnd ? WinGetTitle(hwnd) : ''
        this.className := hwnd ? WinGetClass(hwnd) : ''
        this.hwnd := hwnd, this.pid := hwnd ? WinGetPID(hwnd) : 0
        IniWrite this.mode, this.ini, 'Window', 'Mode'
        IniWrite this.title, this.ini, 'Window', 'Title'
        IniWrite this.className, this.ini, 'Window', 'Class'
        this.Refresh()
    }
}
