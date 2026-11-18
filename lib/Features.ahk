class BinderFeatures {
    InitProfile() {
        this.rootDir := A_ScriptDir '\data'
        if A_Args.Length && A_Args[1] = '--check'
            this.rootDir := A_ScriptDir '\work\check-data-' DllCall('GetCurrentProcessId', 'uint')
        DirCreate this.rootDir
        this.appIni := this.rootDir '\app.ini'
        this.profile := IniRead(this.appIni, 'Profiles', 'Current', 'Основной')
        if !RegExMatch(this.profile, '^[\p{L}\p{N}_ -]{1,32}$')
            this.profile := 'Основной'
        this.dir := this.profile = 'Основной' ? this.rootDir : this.rootDir '\profiles\' this.profile
        DirCreate this.dir
        this.ini := this.dir '\settings.ini'
        this.faction := IniRead(this.ini, 'General', 'Faction', 'Все')
        if !InStr('|LSPD|FIB|SANG|LSCSD|GOV|EMS|WN|Все|', '|' this.faction '|')
            this.faction := 'Все'
        this.esp := IniRead(this.ini, 'General', 'ESP', '3')
        this.overlayWindows := []
        this.overlayKeys := []
        this.overlayMoving := false
        this.reportIni := this.dir '\reports.ini'
        this.reportDays := Map()
        if FileExist(this.reportIni) {
            try {
                for line in StrSplit(IniRead(this.reportIni, 'Daily'), '`n', '`r') {
                    if RegExMatch(line, '^(\d{8})=(\d+)$', &record)
                        this.reportDays[record[1]] := Integer(record[2])
                }
            }
        }
        this.lastDate := FormatTime(, 'yyyyMMdd')
        this.statsSignature := ''
        this.statsPaints := 0
        this.overlayBuilds := 0
        this.overlayIni := this.dir '\overlays.ini'
        this.overlayEnabled := IniRead(this.ini, 'Overlay', 'Enabled', '0') = '1'
        this.overlayStyle := IniRead(this.ini, 'Overlay', 'Style', 'compact')
        legacyNorm := IniRead(this.ini, 'Reports', 'Norm', '20')
        this.normWeekday := Max(1, Integer(IniRead(this.ini, 'Reports', 'WeekdayNorm', legacyNorm)))
        this.normWeekend := Max(1, Integer(IniRead(this.ini, 'Reports', 'WeekendNorm', legacyNorm)))
        this.customOverlays := []
        count := Integer(IniRead(this.overlayIni, 'General', 'Count', '0'))
        loop Min(count, 100) {
            section := 'Overlay' A_Index
            this.customOverlays.Push({name: IniRead(this.overlayIni, section, 'Name', 'Оверлей'),
                text: IniRead(this.overlayIni, section, 'Text', ''),
                image: IniRead(this.overlayIni, section, 'Image', ''),
                key: IniRead(this.overlayIni, section, 'Key', ''),
                enabled: IniRead(this.overlayIni, section, 'Enabled', '1') = '1',
                x: IniRead(this.overlayIni, section, 'X', '60'), y: IniRead(this.overlayIni, section, 'Y', '180')})
        }
    }

    ProfileMenu(*) {
        choices := ['Основной']
        if DirExist(this.rootDir '\profiles') {
            loop files this.rootDir '\profiles\*', 'D' {
                if RegExMatch(A_LoopFileName, '^[\p{L}\p{N}_ -]{1,32}$')
                    choices.Push(A_LoopFileName)
            }
        }
        choices.Push('+ Новый профиль')
        selected := DarkDialog.Choice('Профили', choices, this.profile)
        if selected = '+ Новый профиль'
            this.NewProfile()
        else if selected != ''
            this.SwitchProfile(selected)
    }

    NewProfile() {
        result := DarkDialog.Prompt('Название профиля: до 32 букв, цифр, пробелов или дефисов.', 'Новый профиль', 'w430 h140')
        if result.Result != 'OK'
            return
        name := Trim(result.Value)
        if !RegExMatch(name, '^[\p{L}\p{N}_ -]{1,32}$') {
            DarkDialog.Message 'В названии допустимы буквы, цифры, пробелы, _ и -.'
            return
        }
        this.SwitchProfile(name)
    }

    SwitchProfile(name, *) {
        if name = this.profile
            return
        this.SaveOverlayPositions()
        IniWrite name, this.appIni, 'Profiles', 'Current'
        Reload
    }

    SetFaction(name, *) {
        if name = 'Все' {
            this.ChooseExtraFaction()
            return
        }
        this.faction := name
        IniWrite name, this.ini, 'General', 'Faction'
        for label, button in this.factionButtons
            Theme.Select(button, label = name || (label = 'Все' && this.IsExtraFaction(name)))
        this.factionButtons['Все'].Text := this.IsExtraFaction(name) ? name : 'Все'
        this.factionId.Value := IniRead(this.ini, 'FactionIDs', name, '')
        this.factionLabel.Text := 'Для выбранной фракции: ' name
    }

    IsExtraFaction(name) {
        return name = 'GOV' || name = 'EMS' || name = 'WN'
    }

    ChooseExtraFaction() {
        current := this.faction = 'WN' ? 'WN — Weazel News' : (this.IsExtraFaction(this.faction) ? this.faction : 'GOV')
        selected := DarkDialog.Choice('Остальные фракции', ['GOV', 'EMS', 'WN — Weazel News'], current)
        if selected != ''
            this.SetFaction(selected = 'WN — Weazel News' ? 'WN' : selected)
    }

    SetESP(number, *) {
        this.esp := number
        IniWrite number, this.ini, 'General', 'ESP'
        for n, button in this.espButtons
            Theme.Select(button, n = number)
    }

    SetGender(gender, *) {
        if this.gender = gender
            return
        this.gender := gender
        IniWrite gender, this.ini, 'General', 'Gender'
        this.Load()
        this.Activate()
        this.Refresh()
        for label, button in this.genderButtons
            Theme.Select(button, label = gender)
    }

    SaveVariable(name, field, *) {
        IniWrite field.Value, this.ini, 'Variables', name
        this.UpdateOverlayText()
    }

    ReportCounts(now := '') {
        if now = ''
            now := A_Now
        today := FormatTime(now, 'yyyyMMdd')
        day := this.reportDays.Get(today, 0)
        week := 0
        days := Mod(Integer(FormatTime(now, 'WDay')) + 5, 7)
        loop days + 1 {
            date := FormatTime(DateAdd(now, -(A_Index - 1), 'Days'), 'yyyyMMdd')
            week += this.reportDays.Get(date, 0)
        }
        return {day: day, week: week}
    }

    ChangeReports(delta, *) {
        today := FormatTime(, 'yyyyMMdd')
        current := this.reportDays.Get(today, 0)
        next := Max(0, current + delta)
        IniWrite next, this.reportIni, 'Daily', today
        this.reportDays[today] := next
        this.UpdateStats()
        this.UpdateOverlayText()
    }

    SaveNorm(*) {
        for field in [this.weekdayNormField, this.weekendNormField] {
            if !RegExMatch(field.Value, '^\d{1,5}$') || Integer(field.Value) < 1 {
                DarkDialog.Message('Укажи обе нормы: целые числа от 1 до 99999.', 'Норма репортов')
                return
            }
        }
        this.normWeekday := Integer(this.weekdayNormField.Value)
        this.normWeekend := Integer(this.weekendNormField.Value)
        IniWrite this.normWeekday, this.ini, 'Reports', 'WeekdayNorm'
        IniWrite this.normWeekend, this.ini, 'Reports', 'WeekendNorm'
        this.UpdateStats()
        this.UpdateOverlayText()
        this.Notify('Нормы для будней и выходных сохранены')
    }

    NormForDay(date := '') {
        if date = ''
            date := A_Now
        day := Integer(FormatTime(date, 'WDay'))
        return day = 1 || day = 7 ? this.normWeekend : this.normWeekday
    }

    norm {
        get => this.NormForDay()
    }

    ResetReports(*) {
        if DarkDialog.Message('Обнулить счётчик за сегодня? История других дней сохранится.', 'Репорты', 'YesNo') = 'Yes' {
            IniWrite 0, this.reportIni, 'Daily', FormatTime(, 'yyyyMMdd')
            this.reportDays[FormatTime(, 'yyyyMMdd')] := 0
            this.UpdateStats()
            this.UpdateOverlayText()
        }
    }

    UpdateStats(*) {
        stats := this.ReportCounts()
        signature := FormatTime(, 'yyyyMMdd') '|' stats.day '|' stats.week '|' this.norm '|' this.config.entries.Length
        if this.statsSignature = signature
            return
        this.statsSignature := signature
        this.statsPaints += 1
        this.triggerStat.Text := this.config.entries.Length
        this.todayStat.Text := stats.day
        this.weekStat.Text := stats.week
        this.reportToday.Text := stats.day ' / ' this.norm
        this.reportWeek.Text := stats.week
        this.reportProgress.Value := Min(100, Round(stats.day / this.norm * 100))
        weekend := FormatTime(, 'WDay') = '1' || FormatTime(, 'WDay') = '7'
        this.reportHint.Text := 'Выполнено ' Round(stats.day / this.norm * 100) '%  ·  ' (weekend ? 'Норма выходного дня' : 'Норма буднего дня') ': ' this.norm
        loop 14 {
            date := DateAdd(A_Now, -(A_Index - 1), 'Days')
            key := FormatTime(date, 'yyyyMMdd')
            tile := this.historyTiles[A_Index]
            tile.date.Text := A_Index = 1 ? 'Сегодня' : FormatTime(date, 'dd.MM')
            tile.count.Text := this.reportDays.Get(key, 0)
        }
    }

    Notify(message) {
        this.statusText.Text := message
        this.statusText.Visible := true
        SetTimer this.ClearNotice.Bind(this), -4500
    }

    ClearNotice() {
        this.statusText.Text := ''
        this.statusText.Visible := false
    }

    ToggleReportOverlay(*) {
        this.overlayEnabled := !this.overlayEnabled
        IniWrite this.overlayEnabled ? 1 : 0, this.ini, 'Overlay', 'Enabled'
        this.overlayToggle.Text := this.overlayEnabled ? '●  Включён' : '○  Выключен'
        Theme.Select(this.overlayToggle, this.overlayEnabled)
        this.RenderOverlays()
    }

    SetOverlayStyle(style, *) {
        this.overlayStyle := style
        IniWrite style, this.ini, 'Overlay', 'Style'
        Theme.Select(this.classicButton, style = 'classic')
        Theme.Select(this.compactButton, style = 'compact')
        this.RenderOverlays()
    }

    OverlayText(text) {
        text := StrReplace(text, '\n', '`n')
        stats := this.ReportCounts()
        for key, value in Map('{today}', stats.day, '{week}', stats.week, '{norm}', this.norm)
            text := StrReplace(text, key, value)
        for name, field in this.variables
            text := StrReplace(text, '%' name '%', field.Value)
        return text
    }

    RenderOverlays(*) {
        this.overlayBuilds += 1
        this.SaveOverlayPositions()
        for item in this.overlayWindows
            item.gui.Destroy()
        this.overlayWindows := []
        if A_Args.Length && A_Args[1] = '--check'
            return
        if this.overlayEnabled {
            stats := this.ReportCounts()
            text := this.ReportOverlayText(stats)
            x := IniRead(this.ini, 'Overlay', 'X', '40')
            y := IniRead(this.ini, 'Overlay', 'Y', '60')
            this.CreateOverlay(0, text, '', x, y)
        }
        for index, item in this.customOverlays {
            if item.enabled
                this.CreateOverlay(index, this.OverlayText(item.text), item.image, item.x, item.y)
        }
    }

    CreateOverlay(index, text, image, x, y) {
        g := Gui('+AlwaysOnTop -Caption +ToolWindow +E0x08000000', 'Binder by Hatiksu • оверлей')
        Theme.Window(g)
        g.MarginX := 16, g.MarginY := 12
        g.SetFont('s11 w600 cD8D0FF')
        if image != '' && FileExist(image) {
            try g.AddPicture('w240 h-1', image)
        }
        textControl := g.AddText('w300', text = '' ? ' ' : text)
        textControl.Visible := text != ''
        if this.overlayMoving {
            g.AddText('w300 cAA99FF', 'Перетащи окно • затем нажми «Готово»')
            for control in g
                control.OnEvent('Click', (*) => PostMessage(0xA1, 2, 0, , g))
        } else
            g.Opt('+E0x20')
        this.overlayWindows.Push({gui: g, index: index, textControl: textControl, text: text})
        ; If the stored monitor is disconnected, bring the overlay back on-screen.
        if x < -3000 || x > A_ScreenWidth || y < -3000 || y > A_ScreenHeight
            x := 40, y := 60
        g.Show((A_Args.Length && A_Args[1] = '--check' ? 'Hide ' : 'NoActivate ') 'AutoSize x' x ' y' y)
        WinSetTransparent 235, g
    }

    SaveOverlayPositions() {
        if !this.overlayMoving
            return
        for item in this.overlayWindows {
            item.gui.GetPos(&x, &y)
            if item.index = 0 {
                IniWrite x, this.ini, 'Overlay', 'X'
                IniWrite y, this.ini, 'Overlay', 'Y'
            } else {
                this.customOverlays[item.index].x := x
                this.customOverlays[item.index].y := y
            }
        }
        this.SaveCustomOverlays()
    }

    MoveOverlays(*) {
        this.SaveOverlayPositions()
        this.overlayMoving := !this.overlayMoving
        this.moveButton.Text := this.overlayMoving ? '✓ Готово' : '✥ Переместить'
        this.RenderOverlays()
    }

    ResetOverlayPosition(*) {
        this.overlayMoving := false
        this.moveButton.Text := '✥ Переместить'
        IniWrite 40, this.ini, 'Overlay', 'X'
        IniWrite 60, this.ini, 'Overlay', 'Y'
        for index, item in this.customOverlays
            item.x := 60, item.y := 180 + (index - 1) * 60
        this.SaveCustomOverlays()
        this.RenderOverlays()
    }

    SaveCustomOverlays() {
        IniWrite this.customOverlays.Length, this.overlayIni, 'General', 'Count'
        for index, item in this.customOverlays {
            section := 'Overlay' index
            for property in ['name', 'text', 'image', 'key', 'enabled', 'x', 'y']
                IniWrite item.%property%, this.overlayIni, section, property
        }
    }

    RefreshOverlayList() {
        this.customList.Delete()
        for item in this.customOverlays
            this.customList.Add(, item.enabled ? '●' : '○', item.name, item.key = '' ? '—' : KeyLabel(item.key), item.image = '' ? 'Текст' : 'Картинка + текст')
        this.Columns(this.customList, [40, 330, 200, 242])
        this.EmptyStates()
        this.BindOverlayKeys()
    }

    BindOverlayKeys() {
        HotIf this.context
        for key in this.overlayKeys {
            try Hotkey key, 'Off'
        }
        this.overlayKeys := []
        for index, item in this.customOverlays {
            if item.key = ''
                continue
            try {
                Hotkey item.key, this.ToggleCustomOverlay.Bind(this, index), 'On'
                this.overlayKeys.Push(item.key)
            } catch as err
                this.Notify('Оверлей «' item.name '»: ' err.Message)
        }
        HotIf
    }

    ToggleCustomOverlay(index, *) {
        this.customOverlays[index].enabled := !this.customOverlays[index].enabled
        this.SaveCustomOverlays()
        this.RefreshOverlayList()
        this.RenderOverlays()
    }

    EditOverlay(fresh := false) {
        index := this.customList.GetNext()
        if !fresh && !index
            return
        item := fresh ? {name: '', text: '', image: '', key: '', enabled: true, x: 60, y: 180} : this.customOverlays[index]
        d := DarkDialog.Window('Кастомный оверлей', 650)
        Theme.Window(d)
        d.MarginX := 24, d.MarginY := 20
        d.AddText('x24 y78 w600', 'Название')
        title := d.AddEdit('w600 Background252527 cEEEEF2', item.name)
        d.AddText('w600 y+20', 'Текст • {today}, {week}, {norm}, %dis%')
        body := d.AddEdit('w600 r3 Background252527 cEEEEF2', StrReplace(item.text, '\n', '`n'))
        d.AddText('w600 y+20', 'Изображение (необязательно)')
        picture := d.AddEdit('w450 Background252527 cEEEEF2', item.image)
        Theme.Button(d, 'x+10 w140 h30', 'Выбрать…').OnEvent('Click', Browse)
        d.AddText('xm y+20 w600', 'Клавиши показа / скрытия в игре (необязательно)')
        key := KeyPicker(d, 'w600 h40', item.key)
        saveButton := Theme.Button(d, 'xm y+25 w180 h38 Default', 'Сохранить', '765DFF')
        saveButton.OnEvent('Click', Commit)
        this.overlayEditor := {gui: d, title: title, body: body, image: picture, key: key, save: saveButton}
        d.Show(A_Args.Length && A_Args[1] = '--check' ? 'Hide' : '')
        Browse(*) {
            selectedImage := DarkDialog.File(1, , 'Изображение оверлея', 'Изображения (*.png; *.jpg; *.jpeg; *.bmp; *.gif)')
            if selectedImage
                picture.Value := selectedImage
        }
        Commit(*) {
            if Trim(title.Value) = '' || (Trim(body.Value) = '' && picture.Value = '') {
                DarkDialog.Message 'Укажи название и текст или изображение.'
                return
            }
            if picture.Value != '' && !FileExist(picture.Value) {
                DarkDialog.Message 'Изображение не найдено.'
                return
            }
            for binding in this.binds {
                if key.Value != '' && key.Value = binding.key {
                    DarkDialog.Message 'Сочетание занято биндом.'
                    return
                }
            }
            for n, overlay in this.customOverlays {
                if key.Value != '' && key.Value = overlay.key && (fresh || n != index) {
                    DarkDialog.Message 'Сочетание занято другим оверлеем.'
                    return
                }
            }
            ; INI stores one line; visible newline markers are expanded when rendering.
            saved := {name: Trim(title.Value), text: StrReplace(StrReplace(body.Value, '`r'), '`n', '\n'),
                image: picture.Value, key: key.Value, enabled: item.enabled, x: item.x, y: item.y}
            if fresh
                this.customOverlays.Push(saved)
            else
                this.customOverlays[index] := saved
            this.SaveCustomOverlays()
            this.RefreshOverlayList()
            this.RenderOverlays()
            d.Destroy()
        }
    }

    DeleteOverlay(*) {
        index := this.customList.GetNext()
        if index && DarkDialog.Message('Удалить выбранный оверлей?', 'Оверлей', 'YesNo') = 'Yes' {
            this.customOverlays.RemoveAt(index)
            this.SaveCustomOverlays()
            this.RefreshOverlayList()
            this.RenderOverlays()
        }
    }

    Guide(*) {
        this.ShowPage('Гайд')
    }

    Changelog(*) {
        this.ShowPage('Change Log')
    }

    DailyRefresh() {
        today := FormatTime(, 'yyyyMMdd')
        if today = this.lastDate
            return
        this.lastDate := today
        this.UpdateStats()
        this.UpdateOverlayText()
    }

    ReportOverlayText(stats) {
        return this.overlayStyle = 'compact' ? 'РЕПОРТЫ   ' stats.day ' / ' this.norm '     •     НЕДЕЛЯ   ' stats.week : 'Репорты за день: ' stats.day ' / ' this.norm '`nЗа неделю: ' stats.week
    }

    UpdateOverlayText() {
        stats := this.ReportCounts()
        for item in this.overlayWindows {
            text := item.index = 0 ? this.ReportOverlayText(stats) : this.OverlayText(this.customOverlays[item.index].text)
            if text = item.text
                continue
            item.text := text
            item.textControl.Text := text = '' ? ' ' : text
            item.textControl.Visible := text != ''
            if !this.overlayMoving && !(A_Args.Length && A_Args[1] = '--check')
                item.gui.Show('AutoSize NoActivate')
        }
    }

    PrepareCommands(text) {
        text := StrReplace(text, '%faction%', this.faction)
        text := StrReplace(text, '%esp%', this.esp)
        id := IniRead(this.ini, 'FactionIDs', this.faction, '')
        if this.faction != 'Все' && id != '' && RegExMatch(text, 'i)^/templeader(?=\{space\}|$)')
            text := RegExReplace(text, 'i)^/templeader', '/templeader ' id)
        text := RegExReplace(text, 'i)^/esp(?:\s+\d+)?(?=\{|$|\s)', '/esp ' this.esp)
        return text
    }

    UpdateCategories() {
        selected := this.category.Text
        categories := ['Все категории'], seen := Map()
        for item in this.config.entries {
            if !seen.Has(item.category) {
                seen[item.category] := true
                categories.Push(item.category)
            }
        }
        this.category.Delete()
        this.category.Add(categories)
        this.category.Choose(1)
        for index, name in categories {
            if name = selected
                this.category.Choose(index)
        }
    }
}

