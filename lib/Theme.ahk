; Настоящие кнопки Windows: системная обработка кликов и клавиатуры,
; собственная отрисовка без светлых системных элементов.
class Theme {
    static items := Map()
    static proc := 0
    static panels := []
    static rowImages := []
    static listColumns := Map()

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
        if item.HasOwnProp('keyPicker') {
            picker := item.keyPicker
            if (msg = 0x100 || msg = 0x104) && picker.active {
                scan := (lp >> 16) & 255
                if lp & 0x1000000
                    scan |= 256
                picker.KeyDown(wp, scan)
                return 0
            }
            if msg = 8 && picker.active
                picker.Cancel()
        }
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

    static List(c, columns) {
        ; Убираем сетку и задаём свободную высоту строк.
        SendMessage 0x1036, 1, 0, c
        images := DllCall('comctl32\ImageList_Create', 'int', 1, 'int', Round(36 * A_ScreenDPI / 96), 'uint', 0x20, 'int', 1, 'int', 1, 'ptr')
        c.SetImageList(images, 1)
        this.rowImages.Push(images)
        this.listColumns[c.Hwnd] := columns
        c.OnNotify(-12, this.ListDraw.Bind(this))
    }

    static ListDraw(c, notification) {
        stageOffset := A_PtrSize = 8 ? 24 : 12
        stage := NumGet(notification, stageOffset, 'uint')
        if stage = 1 {
            dc := NumGet(notification, A_PtrSize = 8 ? 32 : 16, 'ptr')
            this.PaintList(c, dc)
            ; Explorer рисует разделители даже без LVS_EX_GRIDLINES.
            ; Отрисовываем содержимое целиком; выбор и прокрутка остаются системными.
            return 4
        }
    }

    static PaintList(c, dc) {
        saved := DllCall('SaveDC', 'ptr', dc, 'int')
        bounds := Buffer(16)
        DllCall('GetClientRect', 'ptr', c.Hwnd, 'ptr', bounds)
        width := NumGet(bounds, 8, 'int')
        brushes := []
        for color in ['1C1C1F', '202023', '302848']
            brushes.Push(DllCall('CreateSolidBrush', 'uint', this.Color(color), 'ptr'))
        DllCall('FillRect', 'ptr', dc, 'ptr', bounds, 'ptr', brushes[1])
        font := DllCall('SendMessageW', 'ptr', c.Hwnd, 'uint', 0x31, 'uptr', 0, 'ptr', 0, 'ptr')
        DllCall('SelectObject', 'ptr', dc, 'ptr', font)
        DllCall('SetBkMode', 'ptr', dc, 'int', 1)
        top := SendMessage(0x1027, 0, 0, c)
        visible := SendMessage(0x1028, 0, 0, c) + 1
        count := c.GetCount()
        widths := []
        loop this.listColumns[c.Hwnd]
            widths.Push(SendMessage(0x101D, A_Index - 1, 0, c))
        offset := DllCall('GetScrollPos', 'ptr', c.Hwnd, 'int', 0)
        loop Min(visible, count - top) {
            row := top + A_Index - 1
            rect := Buffer(16, 0)
            SendMessage 0x100E, row, rect.Ptr, c
            y := NumGet(rect, 4, 'int'), bottom := NumGet(rect, 12, 'int')
            NumPut('int', 0, rect, 0)
            NumPut('int', width, rect, 8)
            selected := SendMessage(0x102C, row, 2, c) & 2
            brush := selected ? brushes[3] : brushes[1 + Mod(row, 2)]
            DllCall('FillRect', 'ptr', dc, 'ptr', rect, 'ptr', brush)
            DllCall('SetTextColor', 'ptr', dc, 'uint', this.Color(selected ? 'CDBFFF' : 'DEDEE7'))
            x := -offset
            for column, cellWidth in widths {
                text := c.GetText(row + 1, column)
                NumPut('int', x + 14, 'int', y, 'int', x + cellWidth - 12, 'int', bottom, rect)
                DllCall('DrawTextW', 'ptr', dc, 'str', text, 'int', -1, 'ptr', rect, 'uint', 0x8824)
                x += cellWidth
            }
        }
        DllCall('RestoreDC', 'ptr', dc, 'int', saved)
        for brush in brushes
            DllCall('DeleteObject', 'ptr', brush)
    }
}
