#Requires AutoHotkey v2.0
#SingleInstance Off
#NoTrayIcon
#Include vendor\OCR.ahk
#Include ReportDetector.ahk
OnError(WorkerError)
WorkerError(err, *) {
    if A_Args.Length >= 3
        IniWrite 'Ошибка распознавания: ' err.Message, A_Args[3], 'State', 'Status'
    else
        FileAppend err.Message '`n' err.Stack, '*'
    ExitApp 1
}
if A_Args.Length && A_Args[1] = '--file' {
    result := OCR.FromFile(A_Args[2], {lang: 'ru-RU', scale: 1.5, monochrome: 180, invertcolors: true})
    parsed := ReportDetector.Parse(result)
    FileAppend 'ID=' parsed.id ' EMPTY=' parsed.empty ' BUTTON=' IsObject(parsed.button) '`n' result.Text '`n', '*', 'UTF-8'
    ExitApp
}
parent := Integer(A_Args[1]), game := A_Args[2], output := A_Args[3]
detector := ReportDetector()
CoordMode 'Mouse', 'Screen'
HotIf (*) => WinActive('ahk_exe ' game)
Hotkey '~LButton', RecordClick
HotIf
RecordClick(*) {
    MouseGetPos &x, &y
    detector.Click(x, y)
}
OCR.LoadLanguage('ru-RU')
while ProcessExist(parent) {
    hwnd := WinActive('ahk_exe ' game)
    if !hwnd || WinGetMinMax(hwnd) = -1 {
        detector.Reset()
        Sleep 700
        continue
    }
    WinGetClientPos &x, &y, &w, &h, hwnd
    started := A_TickCount
    ; Область правой панели с заголовком, кнопкой и подтверждением закрытия.
    result := OCR.FromRect(x + Round(w * .58), y + Round(h * .07), Round(w * .42), Round(h * .20), {lang: 'ru-RU', scale: 1.5, monochrome: 180, invertcolors: true})
    if WinExist('A') != hwnd || A_TickCount - started > 800 {
        detector.Reset()
        continue
    }
    state := ReportDetector.Parse(result)
    closed := detector.Observe(state.id, state.empty, state.button, started)
    if closed != ''
        IniWrite FormatTime(, 'yyyyMMddHHmmss'), output, 'Closed', closed
    status := state.id != '' ? 'Автоподсчёт: обращение ' state.id : 'Автоподсчёт: ожидаю закрытия обращения'
    if !IsSet(lastStatus) || status != lastStatus {
        IniWrite status, output, 'State', 'Status'
        lastStatus := status
    }
    Sleep detector.pending != '' ? 60 : 300
}


