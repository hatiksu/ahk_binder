#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut
OnError(CheckError)
CheckError(err, mode) {
    if A_Args.Length && A_Args[1] = '--check' {
        FileAppend err.Message ' at ' err.File ':' err.Line '`n' err.Stack '`n', '*'
        ExitApp 1
    }
}
SetWorkingDir A_ScriptDir
SendMode 'Event'
SetKeyDelay 25, 25

#Include lib\Theme.ahk
#Include lib\Features.ahk
#Include lib\View.ahk
class Binder extends BinderView {
    __New() {
        this.InitProfile()
        this.gender := IniRead(this.ini, 'General', 'Gender', 'male')
        if this.gender != 'female'
            this.gender := 'male'
        this.process := IniRead(this.ini, 'General', 'Process', 'GTA5.exe')
        this.enabled := true
        this.registered := []
        this.bound := []
        this.rows := []
        this.binds := []
        this.context := (*) => this.enabled && WinActive('ahk_exe ' this.process)
        for gender in ['male', 'female'] {
            if !FileExist(this.dir '\' gender '.txt')
                FileCopy A_ScriptDir '\configs\' gender '.txt', this.dir '\' gender '.txt'
        }
        this.Load()
        this.Build()
        this.Activate()
        Hotkey '^!F12', (*) => this.Toggle()
        A_TrayMenu.Add 'Открыть Hatiksu Binder', (*) => this.window.Show()
        A_TrayMenu.Add 'Пауза / продолжить', (*) => this.Toggle()
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
        d := Gui('+Owner' this.window.Hwnd, title)
        Theme.Window(d)
        d.MarginX := 24, d.MarginY := 24
        d.AddText('w650', isBind ? 'Нажми сочетание клавиш' : 'Триггер (например /ltk или .ключ)')
        k := d.Add(isBind ? 'Hotkey' : 'Edit', 'w650 h32' (isBind ? '' : ' Background252527 cEEEEF2'), key)
        Theme.Dark(k)
        d.AddText('w650', 'Текст и действия: {enter}, {tab}, {esc}')
        t := d.AddEdit('w650 r8 Background252527 cEEEEF2', text)
        Theme.Dark(t)
        saveButton := Theme.Button(d, 'w180 h38 y+20 Default', 'Сохранить', '765DFF')
        saveButton.OnEvent('Click', Commit)
        this.editorFields := {gui: d, key: k, body: t, save: saveButton}
        d.Show(A_Args.Length && A_Args[1] = '--check' ? 'Hide' : '')
        Commit(*) {
            if Trim(k.Value) = '' || Trim(t.Value) = '' {
                MsgBox 'Заполни оба поля.'
                return
            }
            if InStr(t.Value, '`n') || InStr(t.Value, '`r') || InStr(t.Value, '`t') {
                MsgBox 'Используй {enter} вместо переноса строки; табуляция недопустима.'
                return
            }
            if save(Trim(k.Value), t.Value)
                d.Destroy()
        }
    }

    StoreTrigger(item, key, text) {
        if InStr(key, ':') || RegExMatch(key, '\s') {
            MsgBox 'В триггере нельзя использовать пробелы и двоеточия.'
            return false
        }
        for other in this.config.entries {
            if other.key = key && other.line != item.line {
                MsgBox 'Такой триггер уже существует.'
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
        if index && MsgBox('Удалить ' this.rows[index].key '?', 'Триггер', 'YesNo') = 'Yes' {
            this.config.lines.RemoveAt(this.rows[index].line)
            this.SaveConfig()
        }
    }

    Import() {
        path := FileSelect(1, , 'Импорт конфига триггеров', 'Триггеры (*.txt)')
        if !path
            return
        incoming := this.Parse(FileRead(path, 'UTF-8'))
        if !incoming.entries.Length {
            MsgBox 'В файле нет распознанных триггеров. Текущий конфиг сохранён.'
            return
        }
        mode := MsgBox('Найдено: ' incoming.entries.Length '. Замечаний: ' incoming.problems.Length '.`nДа — заменить текущий набор.`nНет — объединить (существующие триггеры имеют приоритет).`nОтмена — ничего не менять.', 'Импорт', 'YesNoCancel')
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
        path := FileSelect('S16', 'hatiksu_' this.gender '.txt', 'Экспорт конфига', 'Текст (*.txt)')
        if path {
            if !RegExMatch(path, 'i)\.txt$')
                path .= '.txt'
            this.Write(path, this.Join(this.config.lines))
            MsgBox 'Конфиг экспортирован.'
        }
    }

    Diagnostics() {
        report := this.config.problems.Length ? this.Join(this.config.problems) : 'Ошибок формата и повторов нет.'
        d := Gui('+Owner' this.window.Hwnd, 'Диагностика — исходные строки сохранены')
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
        if key = '^!F12' {
            MsgBox 'Это сочетание зарезервировано для паузы.'
            return false
        }
        for n, item in this.binds {
            if n != index && item.key = key {
                MsgBox 'Это сочетание уже занято.'
                return false
            }
        }
        for item in this.customOverlays {
            if item.key != '' && item.key = key {
                MsgBox 'Это сочетание занято оверлеем.'
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
        if index && MsgBox('Удалить бинд?', 'Бинды', 'YesNo') = 'Yes' {
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
            MsgBox 'Укажи имя процесса, например GTA5.exe.'
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

    Toggle() {
        this.enabled := !this.enabled
        this.state.Text := this.enabled ? '● Биндер включён' : '○ Биндер на паузе'
    }
}

RunChecks() {
    ; Instantiate controls and register handlers without showing a window or sending input.
    app := Binder()
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
    app.editorFields.key.Value := '^!F10'
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
    if !app.CreateProfileMenu().Handle
        throw Error('Не работает меню профилей')
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
    FileAppend 'OK: native button events, 6 pages, factions, gender, ESP, bind and trigger persistence, reports, overlays, settings`n', '*'
    ExitApp
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
