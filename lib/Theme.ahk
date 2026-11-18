; Настоящие кнопки Windows: системная обработка кликов и клавиатуры,
; собственная отрисовка без светлых системных элементов.
class Theme {
    static items := Map()
    static proc := 0
    static panels := []

    static Button(g, options, text, color := '303033') {
        c := g.AddButton(options ' +0x4000000', text)
        c.SetFont('w600')
        return this.Attach(c, color, false)
    }

    static Panel(g, options, color) {
        c := g.AddText(options ' +0x4000000', '')
        this.panels.Push(c)
        return this.Attach(c, color, true)
    }

    static Restack() {
        loop this.panels.Length {
            c := this.panels[this.panels.Length - A_Index + 1]
            if DllCall('IsWindow', 'ptr', c.Hwnd)
                DllCall('SetWindowPos', 'ptr', c.Hwnd, 'ptr', 1, 'int', 0, 'int', 0, 'int', 0, 'int', 0, 'uint', 0x13)
        }
    }

    static Attach(c, color, panel) {
        if !this.proc
            this.proc := CallbackCreate(this.Subclass.Bind(this), 'Fast', 6)
        this.items[c.Hwnd] := {control: c, color: color, selected: false, panel: panel, hover: false}
        this.items[c.Hwnd].nav := false
        if !DllCall('comctl32\SetWindowSubclass', 'ptr', c.Hwnd, 'ptr', this.proc, 'uptr', 1, 'uptr', 0)
            throw Error('Не удалось создать элемент интерфейса')
        return c
    }

    static Color(hex) {
        n := Integer('0x' hex)
        return ((n & 255) << 16) | (n & 65280) | ((n >> 16) & 255)
    }

    static Subclass(hwnd, msg, wp, lp, id, data) {
        if !this.items.Has(hwnd)
            return DllCall('comctl32\DefSubclassProc', 'ptr', hwnd, 'uint', msg, 'uptr', wp, 'ptr', lp, 'ptr')
        item := this.items[hwnd]
        if msg = 0xF {
            this.Paint(hwnd, item)
            return 0
        }
        if msg = 0x14
            return 1
        if msg = 0x200 && !item.panel && !item.hover {
            item.hover := true
            track := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
            NumPut('uint', track.Size, 'uint', 2, 'ptr', hwnd, track)
            DllCall('TrackMouseEvent', 'ptr', track)
            DllCall('InvalidateRect', 'ptr', hwnd, 'ptr', 0, 'int', false)
        }
        if msg = 0x2A3 {
            item.hover := false
            DllCall('InvalidateRect', 'ptr', hwnd, 'ptr', 0, 'int', false)
        }
        if msg = 0x82 {
            DllCall('comctl32\RemoveWindowSubclass', 'ptr', hwnd, 'ptr', this.proc, 'uptr', id)
            this.items.Delete(hwnd)
        }
        result := DllCall('comctl32\DefSubclassProc', 'ptr', hwnd, 'uint', msg, 'uptr', wp, 'ptr', lp, 'ptr')
        if msg = 7 || msg = 8 || msg = 0x201 || msg = 0x202 || msg = 0xF3
            DllCall('InvalidateRect', 'ptr', hwnd, 'ptr', 0, 'int', false)
        return result
    }

    static Paint(hwnd, item) {
        paint := Buffer(A_PtrSize = 8 ? 72 : 64, 0)
        dc := DllCall('BeginPaint', 'ptr', hwnd, 'ptr', paint, 'ptr')
        saved := DllCall('SaveDC', 'ptr', dc, 'int')
        rect := Buffer(16)
        DllCall('GetClientRect', 'ptr', hwnd, 'ptr', rect)
        w := NumGet(rect, 8, 'int'), h := NumGet(rect, 12, 'int')
        state := item.panel ? 0 : DllCall('SendMessageW', 'ptr', hwnd, 'uint', 0xF2, 'uptr', 0, 'ptr', 0, 'ptr')
        fill := item.selected ? '302848' : item.color
        edge := item.selected ? '8870FF' : (item.panel ? '343436' : '424245')
        if item.nav {
            fill := item.selected ? '161618' : item.color
            edge := fill
        }
        if item.hover && !item.selected
            fill := item.color = '765DFF' ? '876FFF' : '3A3A3E'
        if state & 4
            fill := '50416F'
        if state & 8
            edge := 'A99AFF'
        base := DllCall('CreateSolidBrush', 'uint', this.Color('1D1D1F'), 'ptr')
        DllCall('FillRect', 'ptr', dc, 'ptr', rect, 'ptr', base)
        brush := DllCall('CreateSolidBrush', 'uint', this.Color(fill), 'ptr')
        pen := DllCall('CreatePen', 'int', 0, 'int', 1, 'uint', this.Color(edge), 'ptr')
        oldBrush := DllCall('SelectObject', 'ptr', dc, 'ptr', brush, 'ptr')
        oldPen := DllCall('SelectObject', 'ptr', dc, 'ptr', pen, 'ptr')
        DllCall('RoundRect', 'ptr', dc, 'int', 0, 'int', 0, 'int', w, 'int', h, 'int', 12, 'int', 12)
        if !item.panel {
            font := DllCall('SendMessageW', 'ptr', hwnd, 'uint', 0x31, 'uptr', 0, 'ptr', 0, 'ptr')
            DllCall('SelectObject', 'ptr', dc, 'ptr', font)
            DllCall('SetBkMode', 'ptr', dc, 'int', 1)
            DllCall('SetTextColor', 'ptr', dc, 'uint', this.Color(item.selected && !item.nav ? 'B7A5FF' : 'EEEEF2'))
            textBuffer := Buffer((DllCall('GetWindowTextLengthW', 'ptr', hwnd) + 1) * 2)
            DllCall('GetWindowTextW', 'ptr', hwnd, 'ptr', textBuffer, 'int', textBuffer.Size // 2)
            DllCall('DrawTextW', 'ptr', dc, 'ptr', textBuffer, 'int', -1, 'ptr', rect, 'uint', 0x825)
        }
        DllCall('SelectObject', 'ptr', dc, 'ptr', oldBrush)
        DllCall('SelectObject', 'ptr', dc, 'ptr', oldPen)
        DllCall('RestoreDC', 'ptr', dc, 'int', saved)
        DllCall('DeleteObject', 'ptr', base)
        DllCall('DeleteObject', 'ptr', brush)
        DllCall('DeleteObject', 'ptr', pen)
        DllCall('EndPaint', 'ptr', hwnd, 'ptr', paint)
    }

    static Select(c, selected, color := '') {
        item := this.items[c.Hwnd]
        item.selected := selected
        if color != ''
            item.color := color
        c.Redraw()
    }

    static Dark(c) {
        DllCall('uxtheme\SetWindowTheme', 'ptr', c.Hwnd, 'str', 'DarkMode_Explorer', 'ptr', 0)
    }

    static Window(g) {
        g.BackColor := '1D1D1F'
        g.SetFont('s10 cEAEAEF', 'Segoe UI')
        dark := Buffer(4, 0)
        NumPut('int', 1, dark)
        DllCall('dwmapi\DwmSetWindowAttribute', 'ptr', g.Hwnd, 'uint', 20, 'ptr', dark, 'uint', 4)
    }
}
