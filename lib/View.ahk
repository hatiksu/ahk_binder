class BinderView extends BinderFeatures {
    Build() {
        g := Gui('-Caption +Border', 'Hatiksu Binder')
        this.window := g
        Theme.Window(g)
        sidebar := g.AddText('x0 y0 w246 h746 Background1B1B1D +0x4000000', '')
        g.AddText('x245 y0 w1 h746 Background333335', '')
        logo := Theme.Button(g, 'x24 y22 w30 h30 -Tabstop', 'H', '765DFF')
        brand := g.AddText('x65 y22 w175 h34 BackgroundTrans', 'Hatiksu Binder')
        brand.SetFont('s16 w700 italic')
        brand.OnEvent('Click', (*) => PostMessage(0xA1, 2, 0, , g))
        this.profileButton := Theme.Button(g, 'x18 y80 w210 h44', '●  ' this.profile '      ⌄', '18181A')
        this.profileButton.OnEvent('Click', this.ProfileMenu.Bind(this))
        this.pages := Map(), this.nav := Map()
        names := ['Основное', 'Оверлеи', 'Бинды клавиш', 'Триггеры', 'Репорты', 'Настройки']
        symbols := ['⌂', '▱', '⌨', 'ϟ', '▣', '⚙']
        for i, name in names {
            y := 144 + (i - 1) * 40
            if name = 'Настройки'
                y += 18
            button := Theme.Button(g, 'x18 y' y ' w210 h34', symbols[i] '   ' name, '1B1B1D')
            Theme.items[button.Hwnd].nav := true
            button.OnEvent('Click', this.ShowPage.Bind(this, name))
            this.nav[name] := button
            this.pages[name] := []
        }
        this.state := g.AddText('x28 y613 w190 h22 cA99AFF BackgroundTrans', '● Биндер включён')
        Theme.Button(g, 'x24 y645 w198 h34', 'Пауза  ·  Ctrl+Alt+F12', '252527').OnEvent('Click', (*) => this.Toggle())
        g.AddText('x24 y704 w200 h22 c77777F Center BackgroundTrans', 'Hatiksu  /  Majestic RP')
        this.pageTitle := g.AddText('x272 y25 w740 h30 BackgroundTrans', 'Основное')
        this.pageTitle.SetFont('s17 w700')
        this.pageTitle.OnEvent('Click', (*) => PostMessage(0xA1, 2, 0, , g))
        this.pageSubtitle := g.AddText('x272 y61 w760 h22 cA9A9B1 BackgroundTrans', '')
        Theme.Button(g, 'x1090 y22 w27 h26 -Tabstop', '−', '19191B').OnEvent('Click', (*) => g.Minimize())
        Theme.Button(g, 'x1128 y22 w27 h26 -Tabstop', '×', '19191B').OnEvent('Click', (*) => g.Hide())
        this.statusText := g.AddText('x276 y724 w870 h20 c777780 BackgroundTrans', 'Majestic RP  •  AutoHotkey v2')
        this.Card('Основное', 272, 90, 884, 623)
        this.BuildHome()
        this.BuildTriggers()
        this.BuildBinds()
        this.BuildSettings()
        this.BuildOverlayPage()
        this.BuildReports()
        Theme.Restack()
        DllCall('SetWindowPos', 'ptr', sidebar.Hwnd, 'ptr', 1, 'int', 0, 'int', 0, 'int', 0, 'int', 0, 'uint', 0x13)
        g.OnEvent('Close', (*) => g.Hide())
        this.currentPage := 'Основное'
        this.Refresh()
        this.RefreshOverlayList()
        this.ShowPage('Основное')
        if !(A_Args.Length && A_Args[1] = '--check') {
            g.Show('w1180 h746')
            g.GetPos(, , &windowWidth, &windowHeight)
            WinSetRegion '0-0 W' windowWidth ' H' windowHeight ' R16-16', g
        }
    }

    Add(page, type, options, value) {
        if type = 'Button'
            c := Theme.Button(this.window, options, value)
        else {
            if type = 'Edit' || type = 'Hotkey'
                options .= ' Background171719 cEEEEF2 -E0x200'
            else if type = 'ListView'
                options .= ' Background1D1D1F cDEDEE5 -E0x200'
            else if type = 'Text'
                options .= ' BackgroundTrans'
            c := this.window.Add(type, options, value)
            if type = 'Edit' || type = 'ListView' || type = 'DropDownList'
                Theme.Dark(c)
        }
        this.pages[page].Push(c)
        return c
    }

    Label(page, x, y, w, text, size := 10, color := 'EEEEF2', weight := 400, h := 24) {
        c := this.Add(page, 'Text', 'x' x ' y' y ' w' w ' h' h ' c' color, text)
        c.SetFont('s' size ' w' weight)
        return c
    }

    Button(page, x, y, w, text, callback, accent := false, h := 38) {
        c := Theme.Button(this.window, 'x' x ' y' y ' w' w ' h' h, text, accent ? '765DFF' : '303033')
        this.pages[page].Push(c)
        c.OnEvent('Click', callback)
        return c
    }

    Card(page, x, y, w, h, color := '1D1D1F') {
        c := Theme.Panel(this.window, 'x' x ' y' y ' w' w ' h' h, color)
        this.pages[page].Push(c)
        return c
    }

    BuildHome() {
        page := 'Основное'
        titles := ['Всего триггеров', 'Репортов за день', 'Репортов за неделю', 'Версия']
        values := []
        for i, title in titles {
            x := 298 + (i - 1) * 211
            this.Card(page, x, 115, 196, 78, '222224')
            caption := this.Label(page, x + 16, 129, 170, title, 9, 'C9C9D0', 600)
            caption.Opt('Background222224')
            value := this.Label(page, x + 16, 153, 165, i = 4 ? '0.2.0' : '0', 16, i = 2 ? 'ED6969' : 'FFFFFF', 700, 30)
            value.Opt('Background222224')
            values.Push(value)
        }
        this.triggerStat := values[1], this.todayStat := values[2], this.weekStat := values[3]
        this.Label(page, 298, 219, 700, 'Быстрые действия', 13, , 700)
        this.Button(page, 298, 254, 170, '▤  Что нового', this.Changelog.Bind(this))
        this.Button(page, 480, 254, 170, '↻  Обновления', (*) => Run('https://github.com/hatiksu/ahk_binder'))
        this.Button(page, 662, 254, 170, '⌘  GitHub', (*) => Run('https://github.com/hatiksu/ahk_binder'), true)
        this.Button(page, 844, 254, 170, 'ⓘ  Пройти гайд', this.Guide.Bind(this))
        this.Label(page, 298, 322, 700, '⌁  Рабочее пространство', 13, , 700)
        this.Button(page, 298, 357, 238, '▣  Открыть конфиги профиля', (*) => Run(this.dir))
        this.Button(page, 550, 357, 238, '↗  Экспортировать триггеры', (*) => this.Export())
        this.Label(page, 298, 423, 700, '☷  Базовые параметры', 13, , 700)
        this.Label(page, 302, 465, 510, 'Фракция для /templeader', 9, 'B8B8C0', 600)
        this.Label(page, 856, 465, 270, 'Род написания триггеров', 9, 'B8B8C0', 600)
        this.factionButtons := Map()
        for i, faction in ['LSPD', 'FIB', 'SANG', 'LSCSD', 'Все'] {
            b := this.Button(page, 298 + (i - 1) * 105, 492, 101, faction, this.SetFaction.Bind(this, faction), false, 36)
            this.factionButtons[faction] := b
            Theme.Select(b, faction = this.faction)
        }
        this.genderButtons := Map()
        for i, pair in [['male', 'Мужской'], ['female', 'Женский']] {
            b := this.Button(page, 856 + (i - 1) * 136, 492, 128, pair[2], this.SetGender.Bind(this, pair[1]), false, 36)
            this.genderButtons[pair[1]] := b
            Theme.Select(b, this.gender = pair[1])
        }
        this.Label(page, 302, 554, 300, 'Тип /esp', 9, 'B8B8C0', 600)
        this.espButtons := Map()
        loop 3 {
            n := A_Index
            b := this.Button(page, 298 + (n - 1) * 85, 581, 80, n, this.SetESP.Bind(this, n), false, 36)
            this.espButtons[n] := b
            Theme.Select(b, n = this.esp)
        }
        this.variables := Map()
        for i, name in ['dis', 'gadis', 'zgadis'] {
            x := 298 + (i - 1) * 280
            this.Label(page, x + 5, 640, 260, '%' name '%', 9, 'B8B8C0', 600)
            field := this.Add(page, 'Edit', 'x' x ' y665 w264 h30', IniRead(this.ini, 'Variables', name, ''))
            field.OnEvent('Change', this.SaveVariable.Bind(this, name))
            this.variables[name] := field
        }
    }

    BuildTriggers() {
        page := 'Триггеры'
        this.Card(page, 272, 102, 884, 611)
        this.search := this.Add(page, 'Edit', 'x298 y127 w360 h32', '')
        SendMessage 0x1501, 1, StrPtr('Поиск триггера, текста или категории…'), this.search
        this.search.OnEvent('Change', (*) => this.Refresh())
        categories := ['Все категории'], seen := Map()
        for item in this.config.entries {
            if !seen.Has(item.category) {
                seen[item.category] := true
                categories.Push(item.category)
            }
        }
        this.category := this.Add(page, 'DropDownList', 'x674 y127 w208 Choose1', categories)
        this.category.OnEvent('Change', (*) => this.Refresh())
        this.Button(page, 896, 126, 106, '↓ Импорт', (*) => this.Import(), false, 34)
        this.Button(page, 1014, 126, 116, '↑ Экспорт', (*) => this.Export(), true, 34)
        this.list := this.Add(page, 'ListView', 'x298 y182 w832 h410 -Multi', ['Триггер', 'Текст / действия', 'Категория'])
        this.list.OnEvent('DoubleClick', (*) => this.EditTrigger())
        this.Button(page, 298, 615, 164, '+ Добавить', (*) => this.EditTrigger(true), true)
        this.Button(page, 474, 615, 150, 'Изменить', (*) => this.EditTrigger())
        this.Button(page, 636, 615, 140, 'Удалить', (*) => this.DeleteTrigger())
        this.Button(page, 858, 615, 272, 'Диагностика конфига', (*) => this.Diagnostics())
        this.count := this.Label(page, 300, 675, 820, '', 9, '8F8F9B')
    }

    BuildBinds() {
        page := 'Бинды клавиш'
        this.Card(page, 272, 102, 884, 611)
        this.Label(page, 298, 125, 810, 'Сочетание клавиш → открыть чат → выполнить шаблон', 10, 'A9A9B3')
        this.bindList := this.Add(page, 'ListView', 'x298 y173 w832 h416 -Multi', ['Клавиши', 'Текст / действия'])
        this.bindList.OnEvent('DoubleClick', (*) => this.EditBind())
        this.Button(page, 298, 615, 180, '+ Добавить бинд', (*) => this.EditBind(true), true)
        this.Button(page, 490, 615, 150, 'Изменить', (*) => this.EditBind())
        this.Button(page, 652, 615, 150, 'Удалить', (*) => this.DeleteBind())
        this.Label(page, 300, 675, 810, 'Добавь {enter} в конце, чтобы отправить сообщение.', 9, '8F8F9B')
    }

    BuildSettings() {
        page := 'Настройки'
        this.Card(page, 272, 102, 884, 611)
        this.Label(page, 298, 129, 800, 'Игра и ввод', 13, , 700)
        this.Label(page, 298, 178, 800, 'Имя процесса игры', 10, 'B8B8C0')
        this.exe := this.Add(page, 'Edit', 'x298 y205 w450 h32', this.process)
        this.Label(page, 298, 253, 800, 'Обработка клавиш работает только в активном окне этого процесса.', 9, '8F8F9B')
        this.Label(page, 298, 305, 800, 'ID фракции для /templeader', 10, 'B8B8C0')
        this.factionId := this.Add(page, 'Edit', 'x298 y333 w180 h32', IniRead(this.ini, 'FactionIDs', this.faction, ''))
        this.factionLabel := this.Label(page, 498, 337, 620, 'Для выбранной фракции: ' this.faction, 9, '8F8F9B')
        this.Label(page, 298, 384, 800, 'Без ID команда /templeader остаётся без аргумента. ID не угадываются.', 9, '8F8F9B')
        this.Label(page, 298, 441, 800, 'Профиль: ' this.profile, 13, , 700)
        this.Label(page, 298, 481, 800, 'У каждого профиля свои наборы, бинды, Discord, репорты и оверлеи.`nНастройки хранятся локально и не публикуются в GitHub.', 10, 'A9A9B3', , 55)
        this.Button(page, 298, 571, 240, 'Сохранить настройки', (*) => this.SaveSettings(), true)
        this.Button(page, 552, 571, 220, 'Открыть папку профиля', (*) => Run(this.dir))
        this.Label(page, 298, 655, 800, 'Поддерживаются {enter}, {left N}, {space}, {tab}, {esc}, {rep}.', 9, '8F8F9B')
    }

    BuildOverlayPage() {
        page := 'Оверлеи'
        this.Card(page, 272, 102, 884, 611)
        this.Card(page, 298, 127, 832, 218, '19191B')
        this.Button(page, 320, 171, 46, '▣', (*) => this.ShowPage('Репорты'), true, 46)
        this.Label(page, 384, 150, 240, 'Счётчик репортов', 12, , 700)
        this.Label(page, 384, 181, 210, 'Выводит на экран`nколичество репортов`nи норму на день', 10, 'B0B0B8', , 64)
        this.overlayToggle := this.Button(page, 616, 174, 136, this.overlayEnabled ? '●  Включён' : '○  Выключен', this.ToggleReportOverlay.Bind(this), false, 38)
        Theme.Select(this.overlayToggle, this.overlayEnabled)
        this.Button(page, 768, 174, 108, 'К репортам', (*) => this.ShowPage('Репорты'))
        this.moveButton := this.Button(page, 888, 174, 128, '✥ Переместить', this.MoveOverlays.Bind(this), true)
        this.Button(page, 1028, 174, 82, '↻ Сброс', this.ResetOverlayPosition.Bind(this))
        this.Label(page, 320, 263, 600, 'Стиль оверлея', 9, 'A9A9B3', 600)
        this.classicButton := this.Button(page, 320, 290, 195, 'Классический', this.SetOverlayStyle.Bind(this, 'classic'), false, 36)
        this.compactButton := this.Button(page, 528, 290, 195, 'Компактные плашки', this.SetOverlayStyle.Bind(this, 'compact'), false, 36)
        Theme.Select(this.classicButton, this.overlayStyle = 'classic')
        Theme.Select(this.compactButton, this.overlayStyle = 'compact')
        this.Label(page, 298, 385, 600, 'Кастомные оверлеи', 13, , 700)
        this.Label(page, 298, 417, 620, 'Создавайте свои оверлеи с текстом, картинками и биндами клавиш', 10, 'A9A9B3')
        this.Button(page, 946, 384, 184, '+ Создать оверлей', (*) => this.EditOverlay(true), true)
        this.customList := this.Add(page, 'ListView', 'x298 y461 w832 h155 -Multi -Hdr', ['', 'Название', 'Клавиши', 'Содержимое'])
        this.customList.OnEvent('DoubleClick', (*) => this.EditOverlay())
        this.customEmpty := this.Label(page, 335, 511, 750, '✦   Нет созданных оверлеев. Нажмите кнопку выше, чтобы добавить первый.', 10, '9999A5', , 55)
        this.Button(page, 298, 641, 160, 'Изменить', (*) => this.EditOverlay())
        this.Button(page, 470, 641, 180, 'Показать / скрыть', (*) => this.SelectedOverlayToggle())
        this.Button(page, 662, 641, 140, 'Удалить', this.DeleteOverlay.Bind(this))
    }

    SelectedOverlayToggle() {
        index := this.customList.GetNext()
        if index
            this.ToggleCustomOverlay(index)
    }

    BuildReports() {
        page := 'Репорты'
        this.Card(page, 272, 102, 884, 611)
        this.Label(page, 298, 127, 700, 'Статистика репортов', 13, , 700)
        this.Card(page, 298, 175, 395, 100, '222224')
        this.Label(page, 318, 190, 340, 'Сегодня / дневная норма', 10, 'B8B8C0')
        this.reportToday := this.Label(page, 318, 220, 340, '', 22, 'B49FFF', 700, 40)
        this.Card(page, 711, 175, 419, 100, '222224')
        this.Label(page, 731, 190, 360, 'За текущую неделю', 10, 'B8B8C0')
        this.reportWeek := this.Label(page, 731, 220, 360, '', 22, 'FFFFFF', 700, 40)
        this.reportProgress := this.Add(page, 'Progress', 'x298 y299 w832 h8 c8870FF Background303034', 0)
        this.reportHint := this.Label(page, 298, 320, 810, '', 9, 'A9A9B3')
        this.Button(page, 298, 362, 180, '+ Принят репорт', this.ChangeReports.Bind(this, 1), true)
        this.Button(page, 490, 362, 120, '− Убрать 1', this.ChangeReports.Bind(this, -1))
        this.Button(page, 622, 362, 150, 'Обнулить день', this.ResetReports.Bind(this))
        this.Label(page, 816, 350, 300, 'Дневная норма', 9, 'B8B8C0')
        this.normField := this.Add(page, 'Edit', 'x816 y377 w110 h30 Number', this.norm)
        this.Button(page, 940, 373, 190, 'Сохранить норму', this.SaveNorm.Bind(this), false, 34)
        this.Label(page, 298, 438, 800, 'История за последние 14 дней', 11, , 600)
        this.reportHistory := this.Add(page, 'ListView', 'x298 y475 w832 h174 -Multi', ['Дата', 'Репорты'])
        this.Label(page, 298, 675, 820, '{rep} учитывается локально при отправке шаблона. Данные сервера не считываются.', 9, '8F8F9B')
    }

    ShowPage(name, *) {
        this.currentPage := name
        for page, controls in this.pages {
            for control in controls
                control.Visible := page = name
        }
        for label, button in this.nav
            Theme.Select(button, label = name)
        subtitles := Map('Основное', 'Установите базовые настройки конфига', 'Оверлеи', 'Настройка и управление оверлеями на экране',
            'Бинды клавиш', 'Создавайте сочетания для быстрого выполнения команд', 'Триггеры', 'Управление сокращениями и конфигами',
            'Репорты', 'Дневная норма, история и статистика', 'Настройки', 'Настройки игры и текущего профиля')
        this.pageTitle.Text := name
        this.pageSubtitle.Text := subtitles[name]
        if name = 'Оверлеи'
            this.customEmpty.Visible := this.customOverlays.Length = 0
        if name = 'Репорты' || name = 'Основное'
            this.UpdateStats()
        if name = 'Настройки' {
            this.factionId.Value := IniRead(this.ini, 'FactionIDs', this.faction, '')
            this.factionLabel.Text := 'Для выбранной фракции: ' this.faction
        }
    }

    Refresh() {
        this.list.Delete()
        this.rows := []
        needle := this.search.Value
        category := this.category.Text
        for item in this.config.entries {
            if category != 'Все категории' && category != item.category
                continue
            if needle != '' && !InStr(item.key ' ' item.text ' ' item.category, needle)
                continue
            this.rows.Push(item)
            this.list.Add(, item.key, item.text, item.category)
        }
        this.list.ModifyCol(1, 130)
        this.list.ModifyCol(2, 490)
        this.list.ModifyCol(3, 190)
        this.bindList.Delete()
        for item in this.binds
            this.bindList.Add(, item.key, item.text)
        this.bindList.ModifyCol(1, 160)
        this.bindList.ModifyCol(2, 650)
        this.count.Text := 'Показано: ' this.rows.Length ' из ' this.config.entries.Length '    •    Набор: ' (this.gender = 'male' ? 'мужской' : 'женский') '    •    Замечаний: ' this.config.problems.Length
        this.UpdateStats()
    }
}
