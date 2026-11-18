#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut
OnError(CheckError)
CheckError(err, mode) {
    static showing := false
    if A_Args.Length && A_Args[1] = '--check' {
        FileAppend err.Message ' at ' err.File ':' err.Line '`n' err.Stack '`n', '*'
        ExitApp 1
    }
    if showing
        return false
    try {
        showing := true
        DarkDialog.Message('Не удалось выполнить действие.`n`n' err.Message, 'Ошибка')
    } finally
        showing := false
    return true
}
SetWorkingDir A_ScriptDir
SendMode 'Event'
SetKeyDelay 25, 25

#Include lib\Theme.ahk
#Include lib\Controls.ahk
#Include lib\Dialogs.ahk
#Include lib\Features.ahk
#Include lib\View.ahk
class Binder extends BinderView {
    __New() {
        this.InitProfile()
        this.gender := IniRead(this.ini, 'General', 'Gender', 'male')
        if this.gender != 'female'
            this.gender := 'male'
        this.process := IniRead(this.ini, 'General', 'Process', 'GTA5.exe')
        this.registered := []
        this.bound := []
        this.rows := []
        this.binds := []
        this.context := (*) => WinActive('ahk_exe ' this.process)
        for gender in ['male', 'female'] {
            if !FileExist(this.dir '\' gender '.txt')
                FileCopy A_ScriptDir '\configs\' gender '.txt', this.dir '\' gender '.txt'
        }
        this.Load()
        this.Build()
        this.Activate()
        A_TrayMenu.Delete()
        A_TrayMenu.Add 'Открыть Binder by Hatiksu', (*) => this.window.Show()
        A_TrayMenu.Add 'Завершить работу', (*) => ExitApp()
        A_TrayMenu.Default := 'Открыть Binder by Hatiksu'
        this.RenderOverlays()
        OnExit((*) => this.SaveOverlayPositions())
        if !(A_Args.Length && A_Args[1] = '--check')
            SetTimer this.DailyRefresh.Bind(this), 60000
    }

    Parse(text) {
        entries := [], problems := [], seen := Map(), category := 'Без категории'
        seen.CaseSense := false
        lines := StrSplit(StrReplace(text, '`r'), '`n')
        for n, line in lines {
            if RegExMatch(line, '^\s*;\s*(.+)$', &comment) {
                category := comment[1]
                continue
            }
            if Trim(line) = ''
                continue
            if !RegExMatch(line, '^:([?*OCcBb0-9SIETRZKPk-]*):([^:]+)::(.*)$', &m) {
                problems.Push('Строка ' n ': неподдерживаемый формат')
                continue
            }
            key := m[2]
            if seen.Has(key) {
                problems.Push('Строка ' n ': повтор ' key ' (работает первая запись)')
                continue
            }
            seen[key] := true
            entries.Push({line: n, key: key, text: m[3], options: m[1], category: category})
        }
        return {lines: lines, entries: entries, problems: problems}
    }

    Load() {
        this.config := this.Parse(FileRead(this.dir '\' this.gender '.txt', 'UTF-8'))
        if this.HasOwnProp('category')
            this.UpdateCategories()
        this.binds := []
        if FileExist(this.dir '\binds.txt') {
            for line in StrSplit(FileRead(this.dir '\binds.txt', 'UTF-8'), '`n', '`r') {
                parts := StrSplit(line, '`t',, 2)
                if parts.Length = 2
                    this.binds.Push({key: parts[1], text: parts[2]})
            }
        }
    }

    Write(path, text) {
        temp := path '.tmp'
        if FileExist(temp)
            FileDelete temp
        FileAppend text, temp, 'UTF-8'
        FileMove temp, path, 1
    }

    Join(lines) {
        text := ''
        for line in lines
            text .= (A_Index = 1 ? '' : '`r`n') line
        return text
    }

    SaveConfig() {
        path := this.dir '\' this.gender '.txt'
        FileCopy path, path '.bak', 1
        this.Write(path, this.Join(this.config.lines))
        this.Load()
        this.Activate()
        this.Refresh()
    }

    EditTrigger(fresh := false) {
        index := this.list.GetNext()
        if !fresh && !index
            return
        item := fresh ? {key: '', text: '', options: '?', line: 0} : this.rows[index]
        this.Editor('Триггер', item.key, item.text, (key, text) => this.StoreTrigger(item, key, text))
    }

    Editor(title, key, text, save, isBind := false) {
        d := DarkDialog.Window(title, 700)
        Theme.Window(d)
        d.MarginX := 24, d.MarginY := 24
        d.AddText('w650', isBind ? 'Нажми сочетание клавиш' : 'Триггер (например /ltk или .ключ)')
        if isBind
            k := KeyPicker(d, 'w650 h40', key)
        else {
            k := d.AddEdit('w650 h36 Background252527 cEEEEF2 -Multi -VScroll', key)
            Theme.Dark(k)
        }
        d.AddText('w650', 'Текст и действия: {enter}, {tab}, {esc}')
        t := d.AddEdit('w650 r8 Background252527 cEEEEF2', text)
        Theme.Dark(t)
        saveButton := Theme.Button(d, 'w180 h38 y+20 Default', 'Сохранить', '765DFF')
        saveButton.OnEvent('Click', Commit)
        this.editorFields := {gui: d, key: k, body: t, save: saveButton}
        d.Show(A_Args.Length && A_Args[1] = '--check' ? 'Hide' : '')
        Commit(*) {
            if Trim(k.Value) = '' || Trim(t.Value) = '' {
                DarkDialog.Message 'Заполни оба поля.'
                return
            }
            if InStr(t.Value, '`n') || InStr(t.Value, '`r') || InStr(t.Value, '`t') {
                DarkDialog.Message 'Используй {enter} вместо переноса строки; табуляция недопустима.'
                return
            }
            if save(Trim(k.Value), t.Value)
                d.Destroy()
        }
    }

    StoreTrigger(item, key, text) {
        if InStr(key, ':') || RegExMatch(key, '\s') {
            DarkDialog.Message 'В триггере нельзя использовать пробелы и двоеточия.'
            return false
        }
        for other in this.config.entries {
            if other.key = key && other.line != item.line {
                DarkDialog.Message 'Такой триггер уже существует.'
                return false
            }
        }
        line := ':' item.options ':' key '::' text
        if item.line
            this.config.lines[item.line] := line
        else
            this.config.lines.Push(line)
        this.SaveConfig()
        return true
    }

    DeleteTrigger() {
        index := this.list.GetNext()
        if index && DarkDialog.Message('Удалить ' this.rows[index].key '?', 'Триггер', 'YesNo') = 'Yes' {
            this.config.lines.RemoveAt(this.rows[index].line)
            this.SaveConfig()
        }
    }

    Import() {
        path := DarkDialog.File(1, , 'Импорт конфига триггеров', 'Триггеры (*.txt)')
        if !path
            return
        incoming := this.Parse(FileRead(path, 'UTF-8'))
        if !incoming.entries.Length {
            DarkDialog.Message 'В файле нет распознанных триггеров. Текущий конфиг сохранён.'
            return
        }
        mode := DarkDialog.Message('Найдено: ' incoming.entries.Length '. Замечаний: ' incoming.problems.Length '.`nДа — заменить текущий набор.`nНет — объединить (существующие триггеры имеют приоритет).`nОтмена — ничего не менять.', 'Импорт', 'YesNoCancel')
        if mode = 'Cancel'
            return
        if mode = 'Yes'
            this.config.lines := incoming.lines
        else {
            seen := Map()
            seen.CaseSense := false
            for item in this.config.entries
                seen[item.key] := true
            skip := Map()
            for item in incoming.entries {
                if seen.Has(item.key)
                    skip[item.line] := true
                else
                    seen[item.key] := true
            }
            this.config.lines.Push('', '; Импорт: ' path)
            for n, line in incoming.lines {
                if !skip.Has(n)
                    this.config.lines.Push(line)
            }
        }
        this.SaveConfig()
        this.Diagnostics()
    }

    Export() {
        path := DarkDialog.File('S16', 'hatiksu_' this.gender '.txt', 'Экспорт конфига', 'Текст (*.txt)')
        if path {
            if !RegExMatch(path, 'i)\.txt$')
                path .= '.txt'
            this.Write(path, this.Join(this.config.lines))
            DarkDialog.Message 'Конфиг экспортирован.'
        }
    }

    Diagnostics() {
        report := this.config.problems.Length ? this.Join(this.config.problems) : 'Ошибок формата и повторов нет.'
        d := DarkDialog.Window('Диагностика конфига', 830)
        Theme.Window(d)
        d.AddEdit('w780 r22 ReadOnly Background252527 cEEEEF2', report)
        d.Show()
    }

    EditBind(fresh := false) {
        index := this.bindList.GetNext()
        if !fresh && !index
            return
        item := fresh ? {key: '', text: ''} : this.binds[index]
        this.Editor('Бинд клавиш', item.key, item.text, (key, text) => this.StoreBind(fresh ? 0 : index, key, text), true)
    }

    StoreBind(index, key, text) {
        for n, item in this.binds {
            if n != index && item.key = key {
                DarkDialog.Message 'Это сочетание уже занято.'
                return false
            }
        }
        for item in this.customOverlays {
            if item.key != '' && item.key = key {
                DarkDialog.Message 'Это сочетание занято оверлеем.'
                return false
            }
        }
        if index
            this.binds[index] := {key: key, text: text}
        else
            this.binds.Push({key: key, text: text})
        this.SaveBinds()
        return true
    }

    DeleteBind() {
        index := this.bindList.GetNext()
        if index && DarkDialog.Message('Удалить бинд?', 'Бинды', 'YesNo') = 'Yes' {
            this.binds.RemoveAt(index)
            this.SaveBinds()
        }
    }

    SaveBinds() {
        lines := []
        for item in this.binds
            lines.Push(item.key '`t' item.text)
        this.Write(this.dir '\binds.txt', this.Join(lines))
        this.Activate()
        this.Refresh()
    }

    SaveSettings() {
        if !RegExMatch(Trim(this.exe.Value), 'i)^[\w. -]+\.exe$') {
            DarkDialog.Message 'Укажи имя процесса, например GTA5.exe.'
            return
        }
        if this.factionId.Value != '' && !RegExMatch(this.factionId.Value, '^\d+$') {
            this.Notify('ID фракции должен быть числом или пустым полем.')
            return
        }
        this.process := Trim(this.exe.Value)
        IniWrite this.process, this.ini, 'General', 'Process'
        IniWrite this.factionId.Value, this.ini, 'FactionIDs', this.faction
        for name, field in this.variables
            IniWrite field.Value, this.ini, 'Variables', name
        this.Refresh()
        this.Notify('Настройки сохранены')
    }

    Activate() {
        HotIf this.context
        for name in this.registered
            Hotstring name, , 'Off'
        for key in this.bound
            Hotkey key, 'Off'
        this.registered := [], this.bound := [], failures := []
        for item in this.config.entries {
            ; Only matching options are used; bodies are always data, never AHK code.
            options := '?XO'
            if InStr(item.options, '*')
                options .= '*'
            name := ':' options ':' item.key
            try {
                Hotstring name, this.Emit.Bind(this, item.text, false), 'On'
                this.registered.Push(name)
            } catch as err
                failures.Push(item.key ': ' err.Message)
        }
        for item in this.binds {
            try {
                Hotkey item.key, this.Emit.Bind(this, item.text, true), 'On'
                this.bound.Push(item.key)
            } catch as err
                failures.Push(item.key ': ' err.Message)
        }
        HotIf
        this.config.problems.Push(failures*)
        this.BindOverlayKeys()
    }

    Emit(text, openChat, *) {
        if !this.context()
            return
        for name, field in this.variables
            text := StrReplace(text, '%' name '%', field.Value)
        text := this.PrepareCommands(text)
        if openChat {
            for modifier in ['Ctrl', 'Alt', 'Shift', 'LWin', 'RWin']
                KeyWait modifier
            if !this.context()
                return
            SendEvent 't'
            Sleep 180
        }
        pos := 1, pendingReport := false
        while RegExMatch(text, '\{([^{}]+)\}', &m, pos) {
            if !this.context()
                return
            SendText SubStr(text, pos, m.Pos - pos)
            token := StrLower(m[1])
            if token = 'enter' || token = 'tab' || token = 'esc' {
                SendEvent '{' token '}'
                Sleep 100
            } else if RegExMatch(token, '^(left|right|space)(?: (\d{1,3}))?$', &action) {
                count := action[2] = '' ? 1 : Min(100, Integer(action[2]))
                SendEvent '{' action[1] ' ' count '}'
            } else if token = '!'
                SendText '!'
            else if token = 'rep'
                pendingReport := true
            pos := m.Pos + m.Len
        }
        if this.context() {
            SendText SubStr(text, pos)
            if pendingReport
                this.ChangeReports(1)
        }
    }

}

RunChecks() {
    checkData := A_ScriptDir '\work\check-data-' DllCall('GetCurrentProcessId', 'uint')
    DirCreate checkData
    IniWrite 37, checkData '\settings.ini', 'Reports', 'Norm'
    ; Instantiate controls and register handlers without showing a window or sending input.
    app := Binder()
    if app.normWeekday != 37 || app.normWeekend != 37
        throw Error('Не перенесена старая дневная норма')
    FileAppend 'OK: ' app.config.entries.Length ' triggers; ' app.registered.Length ' registered; ' app.config.problems.Length ' diagnostics`n', '*'
    if app.registered.Length != app.config.entries.Length
        throw Error('Not all triggers registered')
    for gender in ['male', 'female'] {
        original := FileRead(A_ScriptDir '\configs\' gender '.txt', 'UTF-8')
        parsed := app.Parse(original)
        if StrReplace(original, '`r') != StrReplace(app.Join(parsed.lines), '`r')
            throw Error('Round-trip changed ' gender)
        if parsed.entries.Length != 1543 || parsed.problems.Length != 5
            throw Error('Unexpected parsing result: ' gender)
        app.gender := gender
        app.Load()
        app.Activate()
        if app.registered.Length != 1543
            throw Error('Registration failed: ' gender)
        FileAppend 'OK: ' gender ' parse, lossless export, registration`n', '*'
    }
    sample := app.Parse('; Test`n:?:/ltk::Приветствую. Сделано.{enter}{rep}`n:?:/ltk::duplicate`n?:bad::line`ncontinuation')
    if sample.entries.Length != 1 || sample.problems.Length != 3
        throw Error('Duplicate / malformed line handling failed')
    if sample.entries[1].text != 'Приветствую. Сделано.{enter}{rep}'
        throw Error('Action tokens changed')
    for page in ['Основное', 'Триггеры', 'Бинды клавиш', 'Настройки']
        app.ShowPage(page)
    app.search.Value := '/ltk'
    app.Refresh()
    for row in app.rows {
        if !InStr(row.key ' ' row.text ' ' row.category, '/ltk')
            throw Error('Search filtering failed')
    }
    FileAppend 'OK: duplicate detection, malformed lines, action preservation, pages, search`n', '*'
    for name in ['Оверлеи', 'Репорты', 'Бинды клавиш', 'Триггеры', 'Настройки', 'Основное'] {
        CheckClick(app.nav[name])
        if app.currentPage != name
            throw Error('Не работает кнопка раздела: ' name)
    }
    CheckClickText(app, 'Основное', '▤  Change Log')
    if app.currentPage != 'Change Log'
        throw Error('Не работает страница Change Log')
    CheckClickText(app, 'Change Log', '← На главную')
    for list in [app.list, app.bindList, app.customList] {
        if SendMessage(0x1037, 0, 0, list) & 1
            throw Error('В списке осталась сетка')
        style := DllCall('GetWindowLongPtr', 'ptr', list.Hwnd, 'int', -16, 'ptr')
        if !(style & 0x4000)
            throw Error('В списке остался системный заголовок')
    }
    app.search.Value := ''
    app.category.Select(2)
    for row in app.rows {
        if row.category != app.category.Text
            throw Error('Не работает фильтр категорий')
    }
    app.category.Select(1)
    for faction in ['LSPD', 'FIB', 'SANG', 'LSCSD', 'Все'] {
        CheckClick(app.factionButtons[faction])
        if app.faction != faction
            throw Error('Не работает кнопка фракции: ' faction)
    }
    CheckClick(app.genderButtons['female'])
    if app.gender != 'female'
        throw Error('Не работает женский набор')
    CheckClick(app.genderButtons['male'])
    if app.gender != 'male'
        throw Error('Не работает мужской набор')
    CheckClick(app.espButtons[2])
    if app.PrepareCommands('/esp 3') != '/esp 2'
        throw Error('Не работает выбор /esp')
    app.ShowPage('Бинды клавиш')
    CheckClickText(app, 'Бинды клавиш', '+ Добавить бинд')
    app.editorFields.key.Capture()
    SendMessage 0x100, 0x78, 0, app.editorFields.key.control
    if !RegExMatch(app.editorFields.key.Value, 'F9$') || app.editorFields.key.active
        throw Error('Не работает запись клавиши F9')
    app.editorFields.key.Value := '^!F10'
    if app.editorFields.key.control.Text != 'Ctrl + Alt + F10'
        throw Error('Неправильное отображение сочетания клавиш')
    app.editorFields.body.Value := 'Проверка.{enter}'
    CheckClick(app.editorFields.save)
    app.Load()
    if app.binds.Length != 1 || app.binds[1].key != '^!F10'
        throw Error('Не работает сохранение биндa через кнопку')
    app.ShowPage('Триггеры')
    app.search.Value := ''
    app.Refresh()
    CheckClickText(app, 'Триггеры', '+ Добавить')
    app.editorFields.key.Value := '/hatiksu_test'
    app.editorFields.body.Value := 'Проверка.{enter}{rep}'
    CheckClick(app.editorFields.save)
    if app.config.entries.Length != 1544
        throw Error('Не работает сохранение триггера через кнопку')
    app.ShowPage('Репорты')
    CheckClickText(app, 'Репорты', '+ Принят репорт')
    if app.ReportCounts().day != 1
        throw Error('Не работает счётчик репортов')
    if app.historyTiles.Length != 14 || app.historyTiles[1].count.Text != '1'
        throw Error('Не обновляется история репортов')
    CheckClickText(app, 'Репорты', '− Убрать 1')
    if app.ReportCounts().day != 0
        throw Error('Не работает коррекция счётчика')
    app.ShowPage('Оверлеи')
    CheckClick(app.overlayToggle)
    if !app.overlayEnabled
        throw Error('Не работает включение оверлея')
    CheckClick(app.classicButton)
    if app.overlayStyle != 'classic'
        throw Error('Не работает стиль оверлея')
    CheckClickText(app, 'Оверлеи', '+ Создать оверлей')
    app.overlayEditor.title.Value := 'Проверка'
    app.overlayEditor.body.Value := 'Репорты: {today} / {norm}'
    app.overlayEditor.key.Value := '^!F11'
    CheckClick(app.overlayEditor.save)
    if app.customOverlays.Length != 1 || app.overlayKeys.Length != 1
        throw Error('Не работает сохранение оверлея')
    app.ToggleCustomOverlay(1)
    if app.customOverlays[1].enabled
        throw Error('Не работает переключение оверлея')
    app.ShowPage('Настройки')
    app.exe.Value := 'GTA5_Enhanced.exe'
    CheckClickText(app, 'Настройки', 'Сохранить настройки')
    if IniRead(app.ini, 'General', 'Process') != 'GTA5_Enhanced.exe'
        throw Error('Не работает сохранение настроек')
    app.CreateOverlay(0, 'Проверка счётчика', '', 40, 60)
    CheckClick(app.moveButton)
    if !app.overlayMoving
        throw Error('Не работает режим перемещения оверлея')
    CheckClick(app.moveButton)
    if app.overlayMoving
        throw Error('Не работает сохранение положения оверлея')
    for hwnd, item in Theme.items {
        if DllCall('IsWindow', 'ptr', hwnd)
            SendMessage 0xF, 0, 0, hwnd
    }
    app.ShowPage('Репорты')
    app.weekdayNormField.Value := '50'
    app.weekendNormField.Value := '70'
    CheckClickText(app, 'Репорты', 'Сохранить')
    if IniRead(app.ini, 'Reports', 'WeekdayNorm') != '50' || IniRead(app.ini, 'Reports', 'WeekendNorm') != '70'
        throw Error('Не сохранены две нормы')
    for sample in [['20261120090000', 50], ['20261121090000', 70], ['20261122090000', 70], ['20261123090000', 50]] {
        if app.NormForDay(sample[1]) != sample[2]
            throw Error('Неверная норма для даты ' sample[1])
    }
    for field in [app.weekdayNormField, app.weekendNormField] {
        if DllCall('GetWindowLongPtr', 'ptr', field.Hwnd, 'int', -16, 'ptr') & 0x200004
            throw Error('В поле нормы остались прокрутка или многострочный режим')
    }
    SetTimer((*) => CheckClick(DarkDialog.last.buttons[2]), -100)
    if DarkDialog.Message('Проверка отмены', 'Подтверждение', 'YesNo') != 'No'
        throw Error('Не работает отмена в тёмном диалоге')
    app.ChangeReports(1)
    SetTimer((*) => CheckClick(DarkDialog.last.buttons[2]), -100)
    app.ResetReports()
    if app.ReportCounts().day != 1
        throw Error('Отмена сброса изменила счётчик')
    SetTimer((*) => CheckClick(DarkDialog.last.buttons[1]), -100)
    app.ResetReports()
    if app.ReportCounts().day != 0
        throw Error('Подтверждённый сброс не выполнен')
    SetTimer(FillPrompt, -100)
    prompt := DarkDialog.Prompt('Введите название', 'Новый профиль')
    if prompt.Result != 'OK' || prompt.Value != 'Проверка'
        throw Error('Не работает тёмный диалог ввода')
    SetTimer((*) => CheckClick(DarkDialog.last.buttons[1]), -100)
    if DarkDialog.Choice('Профили', ['Основной', 'Проверка'], 'Проверка') != 'Проверка'
        throw Error('Не работает тёмный выбор варианта')
    SetTimer(ChooseTestFile, -100)
    selected := DarkDialog.File(1, '', 'Выбор конфига', 'Триггеры (*.txt)')
    if selected != A_ScriptDir '\configs\male.txt'
        throw Error('Не работает тёмный выбор файла')
    FileAppend 'OK: legacy norm migration, weekday/weekend boundaries, single-line inputs, dark dialogs, confirmations, file picker`n', '*'
    FileAppend 'OK: native button events, pages, Change Log, dark lists, categories, key capture, reports, overlays, settings`n', '*'
    ExitApp
    FillPrompt() {
        DarkDialog.last.input.Value := 'Проверка'
        CheckClick(DarkDialog.last.buttons[1])
    }
    ChooseTestFile() {
        DarkDialog.last.filename.Value := A_ScriptDir '\configs\male.txt'
        CheckClick(DarkDialog.last.buttons[1])
    }
}

CheckClick(control) {
    SendMessage 0xF5, 0, 0, control
    Sleep 80
}

CheckClickText(app, page, label) {
    for control in app.pages[page] {
        if control.Type = 'Button' && control.Text = label {
            CheckClick(control)
            return
        }
    }
    throw Error('Не найдена кнопка: ' label)
}
if A_Args.Length && A_Args[1] = '--check'
    RunChecks()
rootBinder := Binder()
