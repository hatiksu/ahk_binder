#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut
OnError(CheckError)
CheckError(err, mode) {
    if A_Args.Length && A_Args[1] = '--check' {
        FileAppend err.Message ' at line ' err.Line '`n', '*'
        ExitApp 1
    }
}
SetWorkingDir A_ScriptDir
SendMode 'Event'
SetKeyDelay 25, 25

class Binder {
    __New() {
        this.dir := A_ScriptDir '\data'
        DirCreate this.dir
        this.ini := this.dir '\settings.ini'
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

    Build() {
        g := Gui(, 'Hatiksu Binder')
        this.window := g
        g.BackColor := '19191D'
        g.SetFont('s10 cEEEEF4', 'Segoe UI')
        g.AddText('x24 y22 w220 h32 cA497FF', 'HATIKSU BINDER')
        g.AddText('x265 y24 w570', 'GTA V  /  Majestic RP')
        this.state := g.AddText('x855 y24 w220', '● Включён')
        this.pages := Map()
        for i, name in ['Основное', 'Триггеры', 'Бинды клавиш', 'Настройки'] {
            button := g.AddButton('x20 y' (92 + (i - 1) * 48) ' w210 h38', name)
            button.OnEvent('Click', this.ShowPage.Bind(this, name))
            this.pages[name] := []
        }
        g.AddText('x24 y490 w205 h64 c9999AA', 'AutoHotkey v2`nCtrl + Alt + F12 — пауза')
        g.AddButton('x20 y562 w210 h34', 'Пауза / продолжить').OnEvent('Click', (*) => this.Toggle())
        this.Add('Основное', 'Text', 'x270 y86 w760 h36', 'Твой биндер. Твои команды.')
        this.summary := this.Add('Основное', 'Text', 'x270 y145 w730 h85', '')
        this.Add('Основное', 'Text', 'x270 y240 w730 h90 cAAAAAA', 'Триггеры заменяют сокращения в открытом чате игры.`nБинды открывают чат клавишей T и выполняют заданный текст.`nВсе изменения сохраняются автоматически.')
        this.Add('Основное', 'Button', 'x270 y365 w240 h40', 'Перейти к триггерам').OnEvent('Click', this.ShowPage.Bind(this, 'Триггеры'))

        this.Add('Триггеры', 'Text', 'x270 y80 w760', 'Триггеры • конфиги мужского и женского пола')
        this.sex := this.Add('Триггеры', 'DropDownList', 'x270 y115 w170 Choose' (this.gender = 'male' ? 1 : 2), ['Мужской', 'Женский'])
        this.sex.OnEvent('Change', (*) => this.ChangeGender())
        this.search := this.Add('Триггеры', 'Edit', 'x455 y115 w280 h28 c111111', '')
        this.search.OnEvent('Change', (*) => this.Refresh())
        this.Add('Триггеры', 'Button', 'x748 y114 w120 h30', 'Импорт').OnEvent('Click', (*) => this.Import())
        this.Add('Триггеры', 'Button', 'x880 y114 w120 h30', 'Экспорт').OnEvent('Click', (*) => this.Export())
        this.list := this.Add('Триггеры', 'ListView', 'x270 y160 w760 h340 c111111 -Multi', ['Триггер', 'Текст', 'Категория'])
        this.list.OnEvent('DoubleClick', (*) => this.EditTrigger())
        this.Add('Триггеры', 'Button', 'x270 y515 w145 h34', 'Добавить').OnEvent('Click', (*) => this.EditTrigger(true))
        this.Add('Триггеры', 'Button', 'x425 y515 w145 h34', 'Изменить').OnEvent('Click', (*) => this.EditTrigger())
        this.Add('Триггеры', 'Button', 'x580 y515 w145 h34', 'Удалить').OnEvent('Click', (*) => this.DeleteTrigger())
        this.Add('Триггеры', 'Button', 'x735 y515 w295 h34', 'Диагностика конфига').OnEvent('Click', (*) => this.Diagnostics())
        this.count := this.Add('Триггеры', 'Text', 'x270 y565 w760 h30', '')

        this.Add('Бинды клавиш', 'Text', 'x270 y80 w760', 'Бинды клавиш • сочетание → текст в чат')
        this.bindList := this.Add('Бинды клавиш', 'ListView', 'x270 y125 w760 h365 c111111 -Multi', ['Клавиши', 'Текст / действия'])
        this.bindList.OnEvent('DoubleClick', (*) => this.EditBind())
        this.Add('Бинды клавиш', 'Button', 'x270 y515 w160 h36', 'Добавить бинд').OnEvent('Click', (*) => this.EditBind(true))
        this.Add('Бинды клавиш', 'Button', 'x445 y515 w160 h36', 'Изменить').OnEvent('Click', (*) => this.EditBind())
        this.Add('Бинды клавиш', 'Button', 'x620 y515 w160 h36', 'Удалить').OnEvent('Click', (*) => this.DeleteBind())

        this.Add('Настройки', 'Text', 'x270 y80 w760', 'Настройки')
        this.Add('Настройки', 'Text', 'x270 y130 w700', 'Процесс игры (биндер работает только в этом окне)')
        this.exe := this.Add('Настройки', 'Edit', 'x270 y158 w450 c111111', this.process)
        this.variables := Map()
        for i, name in ['dis', 'gadis', 'zgadis'] {
            this.Add('Настройки', 'Text', 'x270 y' (220 + (i - 1) * 65) ' w650', '%' name '% — Discord')
            this.variables[name] := this.Add('Настройки', 'Edit', 'x270 y' (245 + (i - 1) * 65) ' w450 c111111', IniRead(this.ini, 'Variables', name, ''))
        }
        this.Add('Настройки', 'Text', 'x270 y445 w730 h55', 'Поддерживаются {enter}, {tab}, {esc}. Неизвестные маркеры,`nвключая {rep}, сохраняются в конфиге и пропускаются при отправке.')
        this.Add('Настройки', 'Button', 'x270 y520 w230 h38', 'Сохранить настройки').OnEvent('Click', (*) => this.SaveSettings())
        g.OnEvent('Close', (*) => g.Hide())
        this.Refresh()
        this.ShowPage('Основное')
        if !(A_Args.Length && A_Args[1] = '--check')
            g.Show('w1060 h625')
    }

    Add(page, type, options, value) {
        c := this.window.Add(type, options, value)
        this.pages[page].Push(c)
        return c
    }

    ShowPage(name, *) {
        for page, controls in this.pages
            for control in controls
                control.Visible := page = name
    }

    Refresh() {
        this.list.Delete()
        this.rows := []
        needle := this.search.Value
        for item in this.config.entries {
            if needle != '' && !InStr(item.key ' ' item.text ' ' item.category, needle)
                continue
            this.rows.Push(item)
            this.list.Add(, item.key, item.text, item.category)
        }
        this.list.ModifyCol(1, 125)
        this.list.ModifyCol(2, 440)
        this.list.ModifyCol(3, 170)
        this.bindList.Delete()
        for item in this.binds
            this.bindList.Add(, item.key, item.text)
        this.bindList.ModifyCol(1, 160)
        this.bindList.ModifyCol(2, 570)
        this.count.Text := 'Показано: ' this.rows.Length ' • Замечаний: ' this.config.problems.Length
        this.summary.Text := 'Триггеров: ' this.config.entries.Length '     Биндов: ' this.binds.Length '`nНабор: ' (this.gender = 'male' ? 'мужской' : 'женский') '`nПроцесс игры: ' this.process
    }

    ChangeGender() {
        this.gender := this.sex.Value = 1 ? 'male' : 'female'
        IniWrite this.gender, this.ini, 'General', 'Gender'
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
        d.SetFont('s10', 'Segoe UI')
        d.AddText('w650', isBind ? 'Нажми сочетание клавиш' : 'Триггер (например /ltk или .ключ)')
        k := d.Add(isBind ? 'Hotkey' : 'Edit', 'w650', key)
        d.AddText('w650', 'Текст и действия: {enter}, {tab}, {esc}')
        t := d.AddEdit('w650 r8', text)
        d.AddButton('w180 Default', 'Сохранить').OnEvent('Click', Commit)
        d.Show()
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
        d.AddEdit('w780 r22 ReadOnly', report)
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
        this.process := Trim(this.exe.Value)
        IniWrite this.process, this.ini, 'General', 'Process'
        for name, field in this.variables
            IniWrite field.Value, this.ini, 'Variables', name
        this.Refresh()
        MsgBox 'Настройки сохранены.'
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
    }

    Emit(text, openChat, *) {
        if !this.context()
            return
        for name, field in this.variables
            text := StrReplace(text, '%' name '%', field.Value)
        if openChat {
            for modifier in ['Ctrl', 'Alt', 'Shift', 'LWin', 'RWin']
                KeyWait modifier
            if !this.context()
                return
            SendEvent 't'
            Sleep 180
        }
        pos := 1
        while RegExMatch(text, '\{([^{}]+)\}', &m, pos) {
            if !this.context()
                return
            SendText SubStr(text, pos, m.Pos - pos)
            token := StrLower(m[1])
            if token = 'enter' || token = 'tab' || token = 'esc' {
                SendEvent '{' token '}'
                Sleep 100
            }
            pos := m.Pos + m.Len
        }
        if this.context()
            SendText SubStr(text, pos)
    }

    Toggle() {
        this.enabled := !this.enabled
        this.state.Text := this.enabled ? '● Включён' : '● На паузе'
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
    ExitApp
}
if A_Args.Length && A_Args[1] = '--check'
    RunChecks()
app := Binder()

