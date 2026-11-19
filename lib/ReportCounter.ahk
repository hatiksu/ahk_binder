class ReportCounter {
    static Load(app) {
        app.autoClosed := Map(), app.autoDays := Map()
        try {
            for line in StrSplit(IniRead(app.reportIni, 'AutoClosed'), '`n', '`r') {
                if RegExMatch(line, '^(\d{6,12})=(\d{14})$', &m) {
                    app.autoClosed[m[1]] := m[2]
                    day := SubStr(m[2], 1, 8)
                    app.autoDays[day] := app.autoDays.Get(day, 0) + 1
                    app.reportDays[day] := app.reportDays.Get(day, 0) + 1
                }
            }
        }
    }
    static Accept(app, id, date) {
        if !RegExMatch(id, '^\d{6,12}$') || !RegExMatch(date, '^\d{14}$') || app.autoClosed.Has(id)
            return false
        IniWrite date, app.reportIni, 'AutoClosed', id
        app.autoClosed[id] := date
        day := SubStr(date, 1, 8)
        app.autoDays[day] := app.autoDays.Get(day, 0) + 1
        app.reportDays[day] := app.reportDays.Get(day, 0) + 1
        app.UpdateStats()
        app.UpdateOverlayText()
        return true
    }
    __New(app) {
        this.app := app
        this.path := app.rootDir '\report-watch-' DllCall('GetCurrentProcessId', 'uint') '-' A_TickCount '.ini'
        this.callback := this.Poll.Bind(this)
        this.game := ''
        SetTimer this.callback, 700
    }
    Poll() {
        app := this.app
        app.UpdateGameStatus()
        hwnd := app.gameWindow.hwnd
        if this.game != hwnd {
            IniWrite hwnd, this.path, 'Target', 'Hwnd'
            IniWrite app.gameWindow.pid, this.path, 'Target', 'PID'
            this.game := hwnd
        }
        if !this.HasOwnProp('pid') {
            Run '"' A_AhkPath '" /ErrorStdOut "' A_ScriptDir '\lib\ReportWorker.ahk" ' DllCall('GetCurrentProcessId', 'uint') ' 0 "' this.path '"', , 'Hide', &pid
            this.pid := pid
        }
        if !FileExist(this.path)
            return
        try {
            text := IniRead(this.path, 'State', 'Status', 'Автоподсчёт: запуск распознавания')
            if app.autoReportStatus.Text != text
                app.autoReportStatus.Text := text
            for line in StrSplit(IniRead(this.path, 'Closed', , ''), '`n', '`r') {
                if RegExMatch(line, '^(\d{6,12})=(\d{14})$', &m)
                    ReportCounter.Accept(app, m[1], m[2])
            }
        }
    }
}
