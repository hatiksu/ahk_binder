class ReportOverlay {
    __New(app, x, y) {
        this.app := app
        g := Gui('+AlwaysOnTop -Caption +ToolWindow +E0x08000000', 'Binder by Hatiksu • репорты')
        this.gui := g
        g.BackColor := '010203'
        g.MarginX := 0, g.MarginY := 0
        compact := app.overlayStyle = 'compact'
        this.width := compact ? 356 : 292
        this.height := compact ? 88 : 144
        g.AddText('x0 y6 w3 h48 BackgroundA78BFA', '')
        this.Label(14, 4, 200, 'РЕПОРТЫ / СЕГОДНЯ', 8, 'D8C9FF')
        this.day := this.Label(14, 22, 190, '', 23, 'FFFFFF', 40)
        weekX := compact ? 234 : 14
        weekY := compact ? 4 : 69
        this.Label(weekX, weekY, 116, 'ЗА НЕДЕЛЮ', 8, 'D8C9FF')
        this.week := this.Label(weekX, weekY + 20, 116, '', 18, 'FFFFFF', 32)
        barY := compact ? 68 : 130
        this.progress := g.AddProgress('x14 y' barY ' w' (this.width - 88) ' h3 cA78BFA Background3E394C -Theme', 0)
        this.percent := this.Label(this.width - 65, barY - 7, 65, '', 9, 'E3D9FF', 20)
        this.Update(app.ReportCounts())
        if app.overlayMoving {
            g.BackColor := '202023'
            for control in g {
                if control.Type = 'Text'
                    control.OnEvent('Click', (*) => PostMessage(0xA1, 2, 0, , g))
            }
        } else
            g.Opt('+E0x20')
        if x < -3000 || x > A_ScreenWidth || y < -3000 || y > A_ScreenHeight
            x := 40, y := 60
        if !app.overlayMoving
            WinSetTransColor '010203', g
        g.Show((A_Args.Length && A_Args[1] = '--check' ? 'Hide ' : 'NoActivate ') 'w' this.width ' h' this.height ' x' x ' y' y)
    }
    Label(x, y, w, text, size, color, h := 20) {
        g := this.gui
        g.SetFont('s' size ' w600 q4', 'Segoe UI')
        shadow := g.AddText('x' (x + 1) ' y' (y + 1) ' w' w ' h' h ' c101018 BackgroundTrans', text)
        front := g.AddText('x' x ' y' y ' w' w ' h' h ' c' color ' BackgroundTrans', text)
        return {front: front, shadow: shadow}
    }
    SetText(pair, text) {
        if pair.front.Text = text
            return
        pair.shadow.Text := text
        pair.front.Text := text
    }
    Update(stats) {
        this.SetText(this.day, stats.day ' / ' this.app.norm)
        this.SetText(this.week, stats.week '')
        percent := Round(stats.day / this.app.norm * 100)
        this.SetText(this.percent, percent '%')
        this.progress.Value := Min(100, percent)
    }
}
