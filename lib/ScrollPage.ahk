class ScrollPage {
    static instances := Map()
    static hooks := false

    __New(parent, x, y, width, height) {
        if !ScrollPage.hooks {
            OnMessage(0x20A, ScrollPage.Wheel.Bind(ScrollPage))
            OnMessage(0x115, ScrollPage.Vertical.Bind(ScrollPage))
            ScrollPage.hooks := true
        }
        this.viewport := Gui('+Parent' parent.Hwnd ' -Caption +0x40000000 +0x200000', '')
        this.content := Gui('+Parent' this.viewport.Hwnd ' -Caption +0x40000000', '')
        Theme.Window(this.viewport)
        Theme.Window(this.content)
        Theme.Dark(this.viewport)
        this.x := x, this.y := y, this.width := width, this.height := height
        this.contentWidth := width - 24
        this.offset := 0, this.nextY := 4, this.shown := false
        this.cards := []
        ScrollPage.instances[this.viewport.Hwnd] := this
    }

    AddCard(title, lines, metadata := '') {
        g := this.content
        y := this.nextY
        panel := Theme.Panel(g, 'x0 y' y ' w' this.contentWidth ' h100', '222224')
        g.SetFont('s18 w700 cB7A4FF')
        g.AddText('x24 y' (y + 20) ' w' (this.contentWidth - 48) ' h32 Background222224', title)
        cursor := y + 64
        if metadata != '' {
            g.SetFont('s9 w400 c9393A2')
            g.AddText('x24 y' cursor ' w' (this.contentWidth - 48) ' h22 Background222224', metadata)
            cursor += 33
        }
        g.SetFont('s10 w400 cCCCCD6')
        for text in lines {
            label := g.AddText('x24 y' cursor ' w' (this.contentWidth - 52) ' Background222224', text)
            label.GetPos(, , , &labelHeight)
            cursor += labelHeight + 13
        }
        cardHeight := cursor - y + 12
        panel.Move(, , , cardHeight)
        this.cards.Push({title: title, top: y, height: cardHeight})
        this.nextY := y + cardHeight + 18
    }

    Finish() {
        this.total := this.nextY + 4
        this.content.Show('x0 y0 w' this.contentWidth ' h' this.total ' NoActivate')
        this.viewport.Show('x' this.x ' y' this.y ' w' this.width ' h' this.height ' NoActivate')
        this.SetOffset(0)
        this.viewport.Hide()
    }

    Visible {
        get => this.shown
        set {
            this.shown := value
            if value {
                this.viewport.Show('NoActivate')
                this.SetOffset(this.offset)
            } else
                this.viewport.Hide()
        }
    }

    SetOffset(position) {
        this.offset := Max(0, Min(position, Max(0, this.total - this.height)))
        info := Buffer(28, 0)
        NumPut('uint', 28, 'uint', 7, 'int', 0, 'int', this.total - 1,
            'uint', this.height, 'int', Round(this.offset), info)
        DllCall('SetScrollInfo', 'ptr', this.viewport.Hwnd, 'int', 1, 'ptr', info, 'int', true)
        DllCall('SetWindowPos', 'ptr', this.content.Hwnd, 'ptr', 0, 'int', 0,
            'int', -Round(this.offset * A_ScreenDPI / 96), 'int', 0, 'int', 0, 'uint', 0x15)
    }

    static Find(hwnd) {
        while hwnd {
            if this.instances.Has(hwnd)
                return this.instances[hwnd]
            hwnd := DllCall('GetParent', 'ptr', hwnd, 'ptr')
        }
        return 0
    }

    static Wheel(wp, lp, msg, hwnd) {
        panel := ScrollPage.Find(hwnd)
        if !panel {
            x := lp & 65535, y := (lp >> 16) & 65535
            if x >= 32768
                x -= 65536
            if y >= 32768
                y -= 65536
            for viewport, candidate in ScrollPage.instances {
                if !candidate.shown
                    continue
                root := DllCall('GetAncestor', 'ptr', viewport, 'uint', 2, 'ptr')
                if !WinActive('ahk_id ' root)
                    continue
                rect := Buffer(16)
                DllCall('GetWindowRect', 'ptr', viewport, 'ptr', rect)
                if x >= NumGet(rect, 0, 'int') && x < NumGet(rect, 8, 'int') && y >= NumGet(rect, 4, 'int') && y < NumGet(rect, 12, 'int') {
                    panel := candidate
                    break
                }
            }
        }
        if !panel || !panel.shown
            return
        delta := (wp >> 16) & 65535
        if delta >= 32768
            delta -= 65536
        panel.SetOffset(panel.offset - delta / 120 * 70)
        return 0
    }

    static Vertical(wp, lp, msg, hwnd) {
        panel := ScrollPage.Find(hwnd)
        if !panel || !panel.shown
            return
        command := wp & 65535
        next := panel.offset
        switch command {
            case 0: next -= 36
            case 1: next += 36
            case 2: next -= panel.height - 40
            case 3: next += panel.height - 40
            case 4, 5:
                info := Buffer(28, 0)
                NumPut('uint', 28, 'uint', 16, info)
                DllCall('GetScrollInfo', 'ptr', panel.viewport.Hwnd, 'int', 1, 'ptr', info)
                next := NumGet(info, 24, 'int')
            case 6: next := 0
            case 7: next := panel.total
        }
        panel.SetOffset(next)
        return 0
    }
}

class ReleaseHistory {
    static Load(path) {
        entries := [], current := 0
        for line in StrSplit(StrReplace(FileRead(path, 'UTF-8'), '`r'), '`n') {
            if RegExMatch(line, '^## (\d+\.\d+\.\d+)\s*$', &version) {
                current := {version: version[1], date: '', lines: []}
                entries.Push(current)
            } else if current && RegExMatch(line, '^Дата выпуска: (\d{2}\.\d{2}\.\d{4})$', &published)
                current.date := published[1]
            else if current && RegExMatch(line, '^- (.+)$', &bullet)
                current.lines.Push('• ' bullet[1])
        }
        return entries
    }
}
