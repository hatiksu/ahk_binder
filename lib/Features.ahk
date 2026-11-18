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
        if !InStr('|LSPD|FIB|SANG|LSCSD|Все|', '|' this.faction '|')
            this.faction := 'Все'
        this.esp := IniRead(this.ini, 'General', 'ESP', '3')
        this.overlayWindows := []
        this.overlayKeys := []
        this.overlayMoving := false
        this.reportIni := this.dir '\reports.ini'
        this.overlayIni := this.dir '\overlays.ini'
        this.overlayEnabled := IniRead(this.ini, 'Overlay', 'Enabled', '0') = '1'
        this.overlayStyle := IniRead(this.ini, 'Overlay', 'Style', 'compact')
        this.norm := Max(1, Integer(IniRead(this.ini, 'Reports', 'Norm', '20')))
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
        this.CreateProfileMenu().Show()
    }

    CreateProfileMenu() {
        profileMenu := Menu()
        profileMenu.Add 'Основной', (*) => this.SwitchProfile('Основной')
        if this.profile = 'Основной'
            profileMenu.Check 'Основной'
        if DirExist(this.rootDir '\profiles') {
            loop files this.rootDir '\profiles\*', 'D' {
                name := A_LoopFileName
                if !RegExMatch(name, '^[\p{L}\p{N}_ -]{1,32}$')
                    continue
                profileMenu.Add name, this.SwitchProfile.Bind(this, name)
                if name = this.profile
                    profileMenu.Check name
            }
        }
        profileMenu.Add
        profileMenu.Add '+ Новый профиль', (*) => this.NewProfile()
        return profileMenu
    }

    NewProfile() {
        result := InputBox('Название профиля: до 32 букв, цифр, пробелов или дефисов.', 'Новый профиль', 'w430 h140')
        if result.Result != 'OK'
            return
        name := Trim(result.Value)
        if !RegExMatch(name, '^[\p{L}\p{N}_ -]{1,32}$') {
            MsgBox 'В названии допустимы буквы, цифры, пробелы, _ и -.'
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
        this.faction := name
        IniWrite name, this.ini, 'General', 'Faction'
        for label, button in this.factionButtons
            Theme.Select(button, label = name)
        this.factionId.Value := IniRead(this.ini, 'FactionIDs', name, '')
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
    }

    ReportCounts(now := '') {
        if now = ''
            now := A_Now
        today := FormatTime(now, 'yyyyMMdd')
        day := Integer(IniRead(this.reportIni, 'Daily', today, '0'))
        week := 0
        days := Mod(Integer(FormatTime(now, 'WDay')) + 5, 7)
        loop days + 1 {
            date := FormatTime(DateAdd(now, -(A_Index - 1), 'Days'), 'yyyyMMdd')
            week += Integer(IniRead(this.reportIni, 'Daily', date, '0'))
        }
        return {day: day, week: week}
    }

    ChangeReports(delta, *) {
        today := FormatTime(, 'yyyyMMdd')
        current := Integer(IniRead(this.reportIni, 'Daily', today, '0'))
        IniWrite Max(0, current + delta), this.reportIni, 'Daily', today
        this.UpdateStats()
        this.RenderOverlays()
    }

    SaveNorm(*) {
        if !RegExMatch(this.normField.Value, '^\d{1,5}$') || Integer(this.normField.Value) < 1 {
            this.Notify('Норма должна быть числом от 1 до 99999.')
            return
        }
        this.norm := Integer(this.normField.Value)
        IniWrite this.norm, this.ini, 'Reports', 'Norm'
        this.UpdateStats()
        this.RenderOverlays()
        this.Notify('Дневная норма сохранена')
    }

    ResetReports(*) {
        if MsgBox('Обнулить счётчик за сегодня? История других дней сохранится.', 'Репорты', 'YesNo') = 'Yes' {
            IniWrite 0, this.reportIni, 'Daily', FormatTime(, 'yyyyMMdd')
            this.UpdateStats()
            this.RenderOverlays()
        }
    }

    UpdateStats(*) {
        stats := this.ReportCounts()
        this.triggerStat.Text := this.config.entries.Length
        this.todayStat.Text := stats.day
        this.weekStat.Text := stats.week
        this.reportToday.Text := stats.day ' / ' this.norm
        this.reportWeek.Text := stats.week
        this.reportProgress.Value := Min(100, Round(stats.day / this.norm * 100))
        this.reportHint.Text := 'Выполнено ' Round(stats.day / this.norm * 100) '% дневной нормы'
        loop 14 {
            date := DateAdd(A_Now, -(A_Index - 1), 'Days')
            key := FormatTime(date, 'yyyyMMdd')
            tile := this.historyTiles[A_Index]
            tile.date.Text := A_Index = 1 ? 'Сегодня' : FormatTime(date, 'dd.MM')
            tile.count.Text := IniRead(this.reportIni, 'Daily', key, '0')
        }
    }

    Notify(message) {
        this.statusText.Text := message
        SetTimer this.ClearNotice.Bind(this), -4500
    }

    ClearNotice() {
        this.statusText.Text := 'Majestic RP  •  AutoHotkey v2'
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
        this.SaveOverlayPositions()
        for item in this.overlayWindows
            item.gui.Destroy()
        this.overlayWindows := []
        if A_Args.Length && A_Args[1] = '--check'
            return
        if this.overlayEnabled {
            stats := this.ReportCounts()
            text := this.overlayStyle = 'compact' ? 'РЕПОРТЫ   ' stats.day ' / ' this.norm '     •     НЕДЕЛЯ   ' stats.week : 'Репорты за день: ' stats.day ' / ' this.norm '`nЗа неделю: ' stats.week
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
        g := Gui('+AlwaysOnTop -Caption +ToolWindow +E0x08000000', 'Hatiksu • оверлей')
        Theme.Window(g)
        g.MarginX := 16, g.MarginY := 12
        g.SetFont('s11 w600 cD8D0FF')
        if image != '' && FileExist(image) {
            try g.AddPicture('w240 h-1', image)
        }
        if text != ''
            g.AddText('w300', text)
        if this.overlayMoving {
            g.AddText('w300 cAA99FF', 'Перетащи окно • затем нажми «Готово»')
            for control in g
                control.OnEvent('Click', (*) => PostMessage(0xA1, 2, 0, , g))
        } else
            g.Opt('+E0x20')
        this.overlayWindows.Push({gui: g, index: index})
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
        d := Gui('+Owner' this.window.Hwnd, 'Кастомный оверлей')
        Theme.Window(d)
        d.MarginX := 24, d.MarginY := 20
        d.AddText('w600', 'Название')
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
            selectedImage := FileSelect(1, , 'Изображение оверлея', 'Изображения (*.png; *.jpg; *.jpeg; *.bmp; *.gif)')
            if selectedImage
                picture.Value := selectedImage
        }
        Commit(*) {
            if Trim(title.Value) = '' || (Trim(body.Value) = '' && picture.Value = '') {
                MsgBox 'Укажи название и текст или изображение.'
                return
            }
            if picture.Value != '' && !FileExist(picture.Value) {
                MsgBox 'Изображение не найдено.'
                return
            }
            for binding in this.binds {
                if key.Value != '' && key.Value = binding.key {
                    MsgBox 'Сочетание занято биндом.'
                    return
                }
            }
            for n, overlay in this.customOverlays {
                if key.Value != '' && key.Value = overlay.key && (fresh || n != index) {
                    MsgBox 'Сочетание занято другим оверлеем.'
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
        if index && MsgBox('Удалить выбранный оверлей?', 'Оверлей', 'YesNo') = 'Yes' {
            this.customOverlays.RemoveAt(index)
            this.SaveCustomOverlays()
            this.RefreshOverlayList()
            this.RenderOverlays()
        }
    }

    Guide(*) {
        text := '1. Выбери или создай профиль слева сверху.`n`n2. На главной выбери пол, фракцию и тип /esp. Discord-поля сохраняются сразу.`n`n3. В «Триггерах» доступен поиск, категории, импорт и экспорт. В открытом чате введи сокращение, затем пробел.`n`n4. В «Биндах клавиш» нажми поле клавиш и введи сочетание. Esc отменяет запись, Backspace очищает поле. Бинд открывает чат клавишей T.`n`n5. В «Оверлеях» включи счётчик и создай свои плашки. Кнопка «Переместить» позволяет перетаскивать их; «Готово» сохраняет положение.`n`n6. {rep} в конце успешно отправленного шаблона увеличивает локальный счётчик репортов. Счётчик не читает данные сервера; его можно поправить вручную.`n`nБиндер работает, пока запущен скрипт. Оверлеи работают поверх оконного режима игры и режима без рамки.'
        d := Gui('+Owner' this.window.Hwnd, 'Как пользоваться Hatiksu Binder')
        Theme.Window(d)
        d.MarginX := 24, d.MarginY := 24
        d.AddText('w670', text)
        Theme.Button(d, 'w200 h38 y+20', 'Понятно', '765DFF').OnEvent('Click', (*) => d.Destroy())
        d.Show()
    }

    Changelog(*) {
        this.ShowPage('Change Log')
    }

    DailyRefresh() {
        this.UpdateStats()
        if !this.overlayMoving
            this.RenderOverlays()
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

