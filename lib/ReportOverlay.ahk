class ReportOverlay {
    __New(app, x, y) {
        this.app := app
        g := Gui('+AlwaysOnTop -Caption +ToolWindow +E0x08000000', 'Binder by Hatiksu • репорты')
        this.gui := g
        g.BackColor := '010203'
        g.MarginX := 0, g.MarginY := 0
        compact := app.overlayStyle = 'compact'
        this.width := compact ? 244 : 160
        this.height := compact ? 26 : 48
        this.day := this.Label(2, 2, 142, '', 10, 'FFFFFF', 22)
        this.week := this.Label(compact ? 148 : 2, compact ? 2 : 24, 96, '', 10, 'D8C9FF', 22)
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
        this.SetText(this.day, 'День: ' stats.day ' / ' this.app.norm)
        this.SetText(this.week, 'Нед.: ' stats.week)

    }
}
