class BinderView extends BinderFeatures {
    Build() {
        g := Gui('-Caption +Border', 'Binder by Hatiksu')
        this.window := g
        Theme.Window(g)
        sidebar := g.AddText('x0 y0 w246 h746 Background1B1B1D +0x4000000', '')
        g.AddText('x245 y0 w1 h746 Background333335', '')
        logo := Theme.Button(g, 'x24 y22 w30 h30 -Tabstop', 'H', '765DFF')
        brand := g.AddText('x65 y22 w175 h34 BackgroundTrans', 'Binder by Hatiksu')
        brand.SetFont('s15 w700 italic')
        brand.OnEvent('Click', (*) => PostMessage(0xA1, 2, 0, , g))
        this.profileButton := Theme.Button(g, 'x18 y80 w210 h44', '● ' this.profile ' ⌄', '18181A')
        this.profileButton.OnEvent('Click', this.ProfileMenu.Bind(this))
        this.pages := Map(), this.nav := Map()
        this.tables := Map()
        this.switchingPage := false
        this.refreshing := false
        this.queuedPage := ''
        this.pageDispatch := this.DispatchQueuedPage.Bind(this)
        names := ['Основное', 'Оверлеи', 'Бинды клавиш', 'Триггеры', 'Репорты', 'Настройки']
        symbols := ['⌂', '▱', '⌨', 'ϟ', '▣', '⚙']
        for i, name in names {
            y := 144 + (i - 1) * 40
            if name = 'Настройки'
                y += 18
            button := Theme.Button(g, 'x18 y' y ' w210 h34', symbols[i] ' ' name, '1B1B1D')
            Theme.items[button.Hwnd].nav := true
            button.OnEvent('Click', this.ShowPage.Bind(this, name))
            this.nav[name] := button
            this.pages[name] := []
        }
        this.pageTitle := g.AddText('x272 y25 w740 h30 BackgroundTrans', 'Основное')
        this.pageTitle.SetFont('s17 w700')
        this.pageTitle.OnEvent('Click', (*) => PostMessage(0xA1, 2, 0, , g))
        this.pageSubtitle := g.AddText('x272 y61 w760 h22 cA9A9B1 BackgroundTrans', '')
        Theme.Button(g, 'x1090 y22 w27 h26 -Tabstop', '−', '19191B').OnEvent('Click', (*) => g.Minimize())
        Theme.Button(g, 'x1128 y22 w27 h26 -Tabstop', '×', '19191B').OnEvent('Click', (*) => g.Hide())
        this.statusText := g.AddText('x276 y724 w870 h20 c777780 BackgroundTrans Hidden', '')
        this.Card('Основное', 272, 90, 884, 623)
        this.BuildHome()
        this.BuildTriggers()
        this.BuildBinds()
        this.BuildSettings()
        this.BuildOverlayPage()
        this.BuildReports()
        this.pages['Change Log'] := []
        this.BuildChangelog()
        this.pages['Гайд'] := []
        this.BuildGuide()
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
        else if type = 'ListView' {
            customHeader := !InStr(options, '-Hdr')
            c := this.window.AddListView(options ' -Hdr -LV0x1 Background1C1C1F cE6E6ED -E0x200', value)
            Theme.Dark(c)
            Theme.List(c, value.Length)
            c.GetPos(&x, &y, &w, &h)
            labels := []
            if customHeader {
                panel := Theme.Panel(this.window, 'x' x ' y' y ' w' w ' h38', '242427')
                this.pages[page].Push(panel)
                for index, title in value {
                    label := this.window.AddText('x' (x + 14) ' y' (y + 9) ' w100 h22 Background242427 cA9A9B7', title)
                    label.SetFont('s9 w600')
                    labels.Push(label)
                    this.pages[page].Push(label)
                }
                c.Move(x, y + 40, w, h - 40)
            } else
                panel := 0
            this.tables[c.Hwnd] := {control: c, panel: panel, labels: labels, x: x, y: y, width: w}
        }
        else {
            if type = 'Edit'
                options .= ' Background171719 cEEEEF2 -E0x200 -Multi -VScroll'
            else if type = 'ListView'
                options .= ' Background1D1D1F cDEDEE5 -E0x200'
            else if type = 'Text'
                options .= ' BackgroundTrans'
            c := this.window.Add(type, options, value)
            if type = 'Edit'
                Theme.SingleLine(c)
            if type = 'Edit' || type = 'ListView' || type = 'DropDownList'
                Theme.Dark(c)
        }
        this.pages[page].Push(c)
        return c
    }

    Columns(c, widths) {
        table := this.tables[c.Hwnd]
        offset := 0
        for index, width in widths {
            c.ModifyCol(index, width)
            if table.labels.Length >= index
                table.labels[index].Move(table.x + offset + 14, table.y + 9, Max(30, width - 24), 22)
            offset += width
        }
    }

    TableVisible(c, visible) {
        this.SetVisible(c, visible)
        table := this.tables[c.Hwnd]
        if table.panel
            this.SetVisible(table.panel, visible)
        for label in table.labels
            this.SetVisible(label, visible)
    }

    SetVisible(control, visible) {
        if control is ScrollPage {
            if control.Visible != visible
                control.Visible := visible
        } else {
            shown := DllCall('GetWindowLongPtr', 'ptr', control.Hwnd, 'int', -16, 'ptr') & 0x10000000
            if (shown != 0) != visible
                control.Visible := visible
        }
    }

    Label(page, x, y, w, text, size := 10, color := 'EEEEF2', weight := 400, h := 24) {
        decoded := Icons.Decode(text)
        if decoded.name != '' && decoded.label != '' {
            icon := Theme.Icon(this.window, 'x' x ' y' y ' w22 h' Min(h, 26), decoded.name, 'B2A4DC')
            this.pages[page].Push(icon)
            x += 30, w -= 30, text := decoded.label
        }
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

    RoundedInput(page, x, y, width, height, value, center := false) {
        frame := this.Card(page, x, y, width, height, '252527')
        Theme.items[frame.Hwnd].inputFrame := true
        field := this.Add(page, 'Edit', 'x' (x + 12) ' y' (y + (height - 20) // 2) ' w' (width - 24) ' h20' (center ? ' Center' : ''), value)
        field.Opt('Background252527')
        field.OnEvent('Focus', (*) => Theme.Select(frame, true))
        field.OnEvent('LoseFocus', (*) => Theme.Select(frame, false))
        return field
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
            value := this.Label(page, x + 16, 153, 165, i = 4 ? this.version : '0', 16, i = 2 ? 'ED6969' : 'FFFFFF', 700, 30)
            value.Opt('Background222224')
            values.Push(value)
        }
        this.triggerStat := values[1], this.todayStat := values[2], this.weekStat := values[3]
        this.Label(page, 298, 219, 700, 'Быстрые действия', 13, , 700)
        this.Button(page, 298, 254, 170, '▤ Change Log', (*) => this.ShowPage('Change Log'))
        this.Button(page, 480, 254, 170, '↻ Обновления', (*) => Run('https://github.com/hatiksu/ahk_binder/releases'))
        this.Button(page, 662, 254, 170, '◉ Discord', (*) => Run('https://discord.gg/KtrHWbjwFY'), true)
        this.Button(page, 844, 254, 170, 'ⓘ Пройти гайд', this.Guide.Bind(this))
        this.Label(page, 298, 322, 700, '⌁ Рабочее пространство', 13, , 700)
        this.Button(page, 298, 357, 238, '▣ Открыть конфиги профиля', (*) => Run(this.dir))
        this.Button(page, 550, 357, 238, '↗ Экспортировать триггеры', (*) => this.Export())
        this.Label(page, 298, 423, 700, '☷ Базовые параметры', 13, , 700)
        this.Label(page, 302, 465, 510, 'Фракция для /templeader', 9, 'B8B8C0', 600)
        this.Label(page, 856, 465, 270, 'Род написания триггеров', 9, 'B8B8C0', 600)
        this.factionButtons := Map()
        for i, faction in ['LSPD', 'FIB', 'SANG', 'LSCSD', 'Все'] {
            b := this.Button(page, 298 + (i - 1) * 105, 492, 101, faction, this.SetFaction.Bind(this, faction), false, 36)
            this.factionButtons[faction] := b
            Theme.Select(b, faction != 'Все' && faction = this.faction)
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
            this.Label(page, x + 5, 635, 260, '%' name '%', 9, 'B8B8C0', 600)
            field := this.RoundedInput(page, x, 661, 264, 40, IniRead(this.ini, 'Variables', name, ''))
            field.OnEvent('Change', this.SaveVariable.Bind(this, name))
            this.variables[name] := field
        }
    }

    BuildTriggers() {
        page := 'Триггеры'
        this.Card(page, 272, 102, 884, 611)
        this.search := this.Add(page, 'Edit', 'x298 y127 w360 h32', '')
        SendMessage 0x1501, 1, StrPtr('Поиск триггера, текста или категории…'), this.search
        this.searchRefresh := this.Refresh.Bind(this)
        this.search.OnEvent('Change', this.ScheduleSearch.Bind(this))
        categories := ['Все категории'], seen := Map()
        for item in this.config.entries {
            if !seen.Has(item.category) {
                seen[item.category] := true
                categories.Push(item.category)
            }
        }
        this.category := CategoryPicker(this.window, 'x674 y126 w208 h34', categories, (*) => this.Refresh())
        this.pages[page].Push(this.category.control)
        this.Button(page, 896, 126, 106, '↓ Импорт', (*) => this.Import(), false, 34)
        this.Button(page, 1014, 126, 116, '↑ Экспорт', (*) => this.Export(), true, 34)
        this.list := this.Add(page, 'ListView', 'x298 y182 w832 h410 -Multi', ['Триггер', 'Текст / действия', 'Категория'])
        this.list.OnEvent('DoubleClick', (*) => this.EditTrigger())
        this.triggerEmpty := this.Label(page, 350, 338, 730, 'Ничего не найдено. Попробуй другой запрос или категорию.', 11, '9999A8', , 60)
        this.triggerEmpty.Opt('Center')
        this.Button(page, 298, 615, 150, '+ Добавить', (*) => this.EditTrigger(true), true)
        this.Button(page, 460, 615, 125, 'Изменить', (*) => this.EditTrigger())
        this.Button(page, 597, 615, 120, 'Удалить', (*) => this.DeleteTrigger())
        this.Button(page, 729, 615, 132, 'Проверить', (*) => this.OpenTriggerTest())
        this.Button(page, 873, 615, 257, 'Диагностика конфига', (*) => this.Diagnostics())
        this.count := this.Label(page, 300, 675, 820, '', 9, '8F8F9B')
    }

    BuildBinds() {
        page := 'Бинды клавиш'
        this.Card(page, 272, 102, 884, 611)
        this.Label(page, 298, 125, 810, 'Быстрые команды на удобных сочетаниях клавиш', 11, 'A9A9B3')
        this.bindEmptyPanel := this.Card(page, 298, 173, 832, 416, '1B1B1E')
        this.bindList := this.Add(page, 'ListView', 'x298 y173 w832 h416 -Multi', ['Клавиши', 'Текст / действия'])
        this.bindList.OnEvent('DoubleClick', (*) => this.EditBind())
        this.bindEmptyIcon := Theme.Icon(this.window, 'x685 y280 w60 h55', 'keyboard', '9B86FF', '1B1B1E')
        this.pages[page].Push(this.bindEmptyIcon)
        this.bindEmptyTitle := this.Label(page, 460, 353, 510, 'Пока нет биндов', 16, 'EEEEF2', 600, 34)
        this.bindEmptyTitle.Opt('Center Background1B1B1E')
        this.bindEmptyHint := this.Label(page, 420, 405, 590, 'Назначь сочетание клавиш и добавь текст команды.`nНажми «Добавить бинд», чтобы создать первый.', 11, '9999A8', , 60)
        this.bindEmptyHint.Opt('Center Background1B1B1E')
        this.Button(page, 298, 615, 180, '+ Добавить бинд', (*) => this.EditBind(true), true)
        this.Button(page, 490, 615, 150, 'Изменить', (*) => this.EditBind())
        this.Button(page, 652, 615, 150, 'Удалить', (*) => this.DeleteBind())
        this.Label(page, 300, 675, 810, 'Добавь {enter} в конце, чтобы отправить сообщение.', 9, '8F8F9B')
    }

    BuildSettings() {
        page := 'Настройки'
        this.Card(page, 272, 102, 884, 611)
        this.Label(page, 298, 129, 800, 'Игра и ввод', 13, , 700)
        this.gameStatus := this.Label(page, 298, 176, 800, 'Ожидаю окно игры', 11, 'D8C9FF', , 28)
        this.Button(page, 298, 215, 205, 'Выбрать окно игры', this.ChooseGameWindow.Bind(this))
        this.Button(page, 515, 215, 205, 'Автоматически', this.AutoGameWindow.Bind(this))
        this.Label(page, 298, 264, 810, 'Бинды и автоподсчёт работают только в найденном или выбранном окне игры.', 9, '8F8F9B')
        this.Label(page, 298, 316, 310, 'Клавиша открытия чата', 10, 'B8B8C0')
        this.chatKeyField := KeyPicker(this.window, 'x298 y345 w310 h40', this.chatKey)
        this.pages[page].Push(this.chatKeyField.control)
        this.Label(page, 638, 316, 350, 'Задержка открытия чата, мс', 10, 'B8B8C0')
        this.chatDelayField := this.RoundedInput(page, 638, 345, 170, 40, this.chatDelay, true)
        this.Label(page, 298, 399, 810, 'Если текст бинда появляется раньше чата, увеличь задержку. Триггеры работают в уже открытом чате.', 9, '8F8F9B')
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
        this.overlayToggle := this.Button(page, 616, 174, 136, this.overlayEnabled ? '● Включён' : '○ Выключен', this.ToggleReportOverlay.Bind(this), false, 38)
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
        this.customEmptyPanel := this.Card(page, 298, 461, 832, 155, '1B1B1E')
        this.customList := this.Add(page, 'ListView', 'x298 y461 w832 h155 -Multi -Hdr', ['', 'Название', 'Клавиши', 'Содержимое'])
        this.customList.OnEvent('DoubleClick', (*) => this.EditOverlay())
        this.customEmptyIcon := Theme.Icon(this.window, 'x695 y484 w38 h38', 'sparkles', 'A391ED', '1B1B1E')
        this.pages[page].Push(this.customEmptyIcon)
        this.customEmpty := this.Label(page, 335, 539, 750, 'Нет созданных оверлеев. Нажмите кнопку выше, чтобы добавить первый.', 10, '9999A5', , 55)
        this.customEmpty.Opt('Center Background1B1B1E')
        this.overlayActions := [
            this.Button(page, 298, 641, 160, 'Изменить', (*) => this.EditOverlay()),
            this.Button(page, 470, 641, 180, 'Показать / скрыть', (*) => this.SelectedOverlayToggle()),
            this.Button(page, 662, 641, 140, 'Удалить', this.DeleteOverlay.Bind(this))]
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
        caption := this.Label(page, 318, 190, 340, 'Сегодня / дневная норма', 10, 'B8B8C0')
        caption.Opt('Background222224')
        this.reportToday := this.Label(page, 318, 220, 340, '', 22, 'B49FFF', 700, 40)
        this.reportToday.Opt('Background222224')
        this.Card(page, 711, 175, 419, 100, '222224')
        caption := this.Label(page, 731, 190, 360, 'За текущую неделю', 10, 'B8B8C0')
        caption.Opt('Background222224')
        this.reportWeek := this.Label(page, 731, 220, 360, '', 22, 'FFFFFF', 700, 40)
        this.reportWeek.Opt('Background222224')
        this.reportProgress := this.Add(page, 'Progress', 'x298 y299 w832 h8 c8870FF Background303034', 0)
        this.reportHint := this.Label(page, 298, 320, 810, '', 9, 'A9A9B3')
        this.Label(page, 298, 346, 116, 'Норма в будни', 9, 'B8B8C0')
        this.weekdayNormField := this.RoundedInput(page, 298, 371, 112, 40, this.normWeekday, true)
        this.Label(page, 434, 346, 132, 'Норма в выходные', 9, 'B8B8C0')
        this.weekendNormField := this.RoundedInput(page, 434, 371, 112, 40, this.normWeekend, true)
        this.Button(page, 570, 373, 180, 'Сохранить', this.SaveNorm.Bind(this), false, 36)
        this.Label(page, 298, 438, 800, 'История за последние 14 дней', 11, , 600)
        this.historyTiles := []
        loop 14 {
            index := A_Index - 1
            x := 298 + Mod(index, 7) * 120
            y := 475 + (index // 7) * 86
            tile := this.Card(page, x, y, 108, 74, index = 0 ? '292338' : '222224')
            date := this.Label(page, x + 12, y + 10, 84, '', 9, 'A8A8B5')
            count := this.Label(page, x + 12, y + 34, 84, '', 16, index = 0 ? 'B6A2FF' : 'EEEEF2', 600, 30)
            date.Opt('Background' (index = 0 ? '292338' : '222224'))
            count.Opt('Background' (index = 0 ? '292338' : '222224'))
            this.historyTiles.Push({date: date, count: count, panel: tile})
        }
        this.autoReportStatus := this.Label(page, 298, 675, 820, 'Автоподсчёт: ожидаю игру', 9, '8F8F9B')
    }

    ShowPage(name, *) {
        if this.switchingPage || this.refreshing {
            this.queuedPage := name
            return
        }
        previous := this.HasOwnProp('visiblePage') ? this.visiblePage : ''
        if previous = name
            return
        this.switchingPage := true
        visible := DllCall('GetWindowLongPtr', 'ptr', this.window.Hwnd, 'int', -16, 'ptr') & 0x10000000
        if visible
            DllCall('SendMessageW', 'ptr', this.window.Hwnd, 'uint', 0xB, 'uptr', 0, 'ptr', 0)
        try {
            SetTimer this.searchRefresh, 0
            if previous != '' {
                for control in this.pages[previous]
                    this.SetVisible(control, false)
            } else {
                for page, controls in this.pages {
                    if page != name {
                        for control in controls
                            this.SetVisible(control, false)
                    }
                }
            }
            this.currentPage := name
            this.visiblePage := name
            for control in this.pages[name]
                this.SetVisible(control, true)
            if this.nav.Has(previous)
                Theme.Select(this.nav[previous], false)
            if this.nav.Has(name)
                Theme.Select(this.nav[name], true)
            subtitles := Map('Основное', 'Установите базовые настройки конфига', 'Оверлеи', 'Настройка и управление оверлеями на экране',
                'Бинды клавиш', 'Создавайте сочетания для быстрого выполнения команд', 'Триггеры', 'Управление сокращениями и конфигами',
                'Репорты', 'Дневная норма, история и статистика', 'Настройки', 'Настройки игры и текущего профиля',
                'Change Log', 'История обновлений Binder by Hatiksu', 'Гайд', 'Как настроить и использовать Binder by Hatiksu')
            this.pageTitle.Text := name
            this.pageSubtitle.Text := subtitles[name]
            if name = 'Триггеры'
                this.Refresh()
            else
                this.EmptyStates()
            if name = 'Репорты' || name = 'Основное'
                this.UpdateStats()
            if name = 'Настройки' {
                this.UpdateGameStatus()
            }
        } finally {
            if visible {
                DllCall('SendMessageW', 'ptr', this.window.Hwnd, 'uint', 0xB, 'uptr', 1, 'ptr', 0)
                DllCall('RedrawWindow', 'ptr', this.window.Hwnd, 'ptr', 0, 'ptr', 0, 'uint', 0x85)
            }
            this.switchingPage := false
            if this.queuedPage != ''
                SetTimer this.pageDispatch, -1
        }
    }

    DispatchQueuedPage() {
        if this.switchingPage || this.refreshing
            return
        target := this.queuedPage
        this.queuedPage := ''
        if target != ''
            this.ShowPage(target)
    }

    Refresh() {
        if this.refreshing {
            SetTimer this.searchRefresh, -140
            return
        }
        this.refreshing := true
        try {
            SetTimer this.searchRefresh, 0
            needle := this.search.Value
            category := this.category.Text
            signature := this.configRevision '|' needle '|' category
            if !this.HasOwnProp('listSignature') || this.listSignature != signature {
                visible := DllCall('GetWindowLongPtr', 'ptr', this.list.Hwnd, 'int', -16, 'ptr') & 0x10000000
                SendMessage 0xB, 0, 0, this.list
                try {
                    this.list.Delete()
                    this.rows := []
                    drawRows := []
                    for item in this.config.entries {
                        if category != 'Все категории' && category != item.category
                            continue
                        if needle != '' && !InStr(item.key ' ' item.text ' ' item.category, needle)
                            continue
                        this.rows.Push(item)
                        drawRows.Push([item.key, item.text, item.category])
                        this.list.Add(, item.key, item.text, item.category)
                    }
                    this.Columns(this.list, [140, 480, 192])
                    Theme.SetListData(this.list, drawRows)
                    this.listSignature := signature
                } finally {
                    SendMessage 0xB, 1, 0, this.list
                    this.list.Visible := visible != 0
                    this.list.Redraw()
                }
            }
            bindings := ''
            for item in this.binds
                bindings .= item.key '`t' item.text '`n'
            if !this.HasOwnProp('bindSignature') || bindings != this.bindSignature {
                this.bindList.Delete()
                for item in this.binds
                    this.bindList.Add(, KeyLabel(item.key), item.text)
                this.Columns(this.bindList, [220, 592])
                this.bindSignature := bindings
            }
            this.count.Text := 'Показано: ' this.rows.Length ' из ' this.config.entries.Length ' • Набор: ' (this.gender = 'male' ? 'мужской' : 'женский') ' • Замечаний: ' this.config.problems.Length
            this.UpdateStats()
            this.EmptyStates()
        } finally {
            this.refreshing := false
            if this.queuedPage != '' && !this.switchingPage
                SetTimer this.pageDispatch, -1
        }
    }

    ScheduleSearch(*) {
        SetTimer this.searchRefresh, -140
    }

    EmptyStates() {
        name := this.currentPage
        this.TableVisible(this.list, name = 'Триггеры' && this.rows.Length > 0)
        this.SetVisible(this.triggerEmpty, name = 'Триггеры' && this.rows.Length = 0)
        empty := name = 'Бинды клавиш' && this.binds.Length = 0
        this.TableVisible(this.bindList, name = 'Бинды клавиш' && !empty)
        for c in [this.bindEmptyPanel, this.bindEmptyIcon, this.bindEmptyTitle, this.bindEmptyHint]
            this.SetVisible(c, empty)
        empty := name = 'Оверлеи' && this.customOverlays.Length = 0
        this.TableVisible(this.customList, name = 'Оверлеи' && !empty)
        this.SetVisible(this.customEmptyPanel, empty)
        this.SetVisible(this.customEmpty, empty)
        this.SetVisible(this.customEmptyIcon, empty)
        for button in this.overlayActions
            this.SetVisible(button, name = 'Оверлеи' && !empty)
    }

    BuildChangelog() {
        page := 'Change Log'
        this.Card(page, 272, 102, 884, 611)
        this.Button(page, 298, 125, 144, '← На главную', (*) => this.ShowPage('Основное'))
        this.historyScroll := ScrollPage(this.window, 298, 180, 832, 507)
        for entry in this.history
            this.historyScroll.AddCard(entry.version, entry.lines, entry.version = this.version ? 'Текущая версия' : 'Предыдущая версия')
        this.historyScroll.Finish()
        this.pages[page].Push(this.historyScroll)
    }

    BuildGuide() {
        page := 'Гайд'
        this.Card(page, 272, 102, 884, 611)
        this.Button(page, 298, 125, 144, '← На главную', (*) => this.ShowPage('Основное'))
        this.guideScroll := ScrollPage(this.window, 298, 180, 832, 507)
        steps := [
            ['01 Профиль и персонаж', ['Выбери профиль в меню слева сверху. Каждый профиль хранит свои триггеры, бинды, оверлеи и статистику.', 'На главной выбери пол, фракцию LSPD / FIB / SANG / LSCSD и тип /esp. Discord-поля сохраняются сразу.']],
            ['02 Триггеры', ['Открой нужный чат, введи сокращение и нажми пробел. Например: .ку. Маркер {rep} отправит готовый ответ, а {enter}{rep} не отправит его дважды.', 'Кнопка «Проверить» открывает локальный чат без отправки сообщений наружу. В редакторах конфигов подстановка отключена, чтобы не мешать изменениям.']],
            ['03 Бинды клавиш', ['Нажми «Добавить бинд», затем поле клавиш и введи сочетание. Esc отменяет запись, Backspace очищает поле.', 'Бинд открывает чат клавишей T и вставляет шаблон. Добавь {enter} в конце, если сообщение нужно отправить сразу.']],
            ['04 Нормы и репорты', ['В разделе «Репорты» отдельно укажи нормы для будней и выходных и нажми «Сохранить». Суббота и воскресенье считаются выходными.', 'Маркер {rep} отправляет готовое сообщение в активном чате. Счётчик автоматически увеличивается после подтверждённого закрытия обращения.']],
            ['05 Оверлеи', ['Включи счётчик или создай плашку с текстом и изображением. Поддерживаются {today}, {week}, {norm} и Discord-поля.', 'Нажми «Переместить», перетащи плашки и нажми «Готово». Оверлеи рассчитаны на оконный режим игры или режим без рамки.']],
            ['06 Настройки игры', ['Окно игры определяется автоматически. Если оно не найдено, нажми «Выбрать окно игры». Настрой клавишу чата и задержку для биндов.', 'Фракция, тип /esp и Discord-поля сохраняются в профиле и восстанавливаются после перезапуска. Кнопка «Все» сохраняет своё название.']],
            ['07 Обновление', ['Кнопка «Обновления» открывает GitHub Releases. Скачай архив новой версии, закрой скрипт и распакуй исходники.', 'Сохрани папку data при обновлении: в ней находятся личные конфиги и статистика. Поддержка - по кнопке Discord на главной.']]]
        for step in steps
            this.guideScroll.AddCard(step[1], step[2])
        this.guideScroll.Finish()
        this.pages[page].Push(this.guideScroll)
    }
}
