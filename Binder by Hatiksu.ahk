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

#Include lib\Icons.ahk
#Include lib\Theme.ahk
#Include lib\Controls.ahk
#Include lib\Dialogs.ahk
#Include lib\ScrollPage.ahk
#Include lib\ReportCounter.ahk
#Include lib\ReportDetector.ahk
#Include lib\ReportOverlay.ahk
#Include lib\GameWindow.ahk
#Include lib\EntryCommands.ahk
#Include lib\Features.ahk
#Include lib\View.ahk
class Binder extends BinderView {
    __New() {
        this.InitProfile()
        this.version := '0.10.0'
        this.history := ReleaseHistory.Load(A_ScriptDir '\CHANGELOG.md')
        this.gender := IniRead(this.ini, 'General', 'Gender', 'male')
        if this.gender != 'female'
            this.gender := 'male'
        this.gameWindow := GameWindow(this.ini)
        this.gameWindow.Refresh()
        this.chatKey := IniRead(this.ini, 'Input', 'ChatKey', 't')
        this.chatDelay := Max(50, Min(2000, Integer(IniRead(this.ini, 'Input', 'ChatDelay', '180'))))
        this.registered := []
        this.bound := []
        this.rows := []
        this.binds := []
        this.context := (*) => this.gameWindow.Active()
        this.testChatHwnd := 0
        this.testInputHwnd := 0
        this.triggerContext := this.TriggerAllowed.Bind(this)
        this.testKeyHandler := this.TestKeyDown.Bind(this)
        OnMessage(0x100, this.testKeyHandler)
        for gender in ['male', 'female'] {
            if !FileExist(this.dir '\' gender '.txt')
                FileCopy A_ScriptDir '\configs\' gender '.txt', this.dir '\' gender '.txt'
        }
        this.Load()
        this.entry := EntryCommands(this)
        this.Build()
        this.Activate()
        if FileExist(A_ScriptDir '\assets\Binder.ico')
            TraySetIcon A_ScriptDir '\assets\Binder.ico'
        A_IconTip := 'Binder by Hatiksu'
        A_TrayMenu.Delete()
        A_TrayMenu.Add 'Открыть Binder by Hatiksu', (*) => this.window.Show()
        A_TrayMenu.Add 'Завершить работу', (*) => ExitApp()
        A_TrayMenu.Default := 'Открыть Binder by Hatiksu'
        this.RenderOverlays()
        OnExit(this.PersistPreferences.Bind(this))
        if !(A_Args.Length && A_Args[1] = '--check')
        {
            SetTimer this.DailyRefresh.Bind(this), 60000
            this.reportWatcher := ReportCounter(this)
        }
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
        this.configRevision := this.HasOwnProp('configRevision') ? this.configRevision + 1 : 1
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
        d.AddText('x24 y78 w650', isBind ? 'Нажми сочетание клавиш' : 'Триггер (например /ltk или .ключ)')
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
        if key = this.entry.trigger {
            DarkDialog.Message 'Этот триггер занят командами при входе.'
            return false
        }
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
        mode := DarkDialog.Message('Найдено: ' incoming.entries.Length '. Замечаний: ' incoming.problems.Length '.`nДа - заменить текущий набор.`nНет - объединить (существующие триггеры имеют приоритет).`nОтмена - ничего не менять.', 'Импорт', 'YesNoCancel')
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
            DarkDialog.Message 'Конфиг экспортирован.'
        }
    }

    Diagnostics() {
        report := this.config.problems.Length ? this.Join(this.config.problems) : 'Ошибок формата и повторов нет.'
        d := DarkDialog.Window('Диагностика конфига', 830)
        Theme.Window(d)
        d.AddEdit('x24 y78 w780 r22 ReadOnly Background252527 cEEEEF2', report)
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
        if key != '' && key = this.entry.key {
            DarkDialog.Message 'Эта клавиша занята командами при входе.'
            return false
        }
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
        key := this.chatKeyField.Value
        if key = '' || !GetKeyVK(key) {
            this.Notify('Выбери одну клавишу открытия чата.')
            return
        }
        if !RegExMatch(this.chatDelayField.Value, '^\d{2,4}$') || Integer(this.chatDelayField.Value) < 50 || Integer(this.chatDelayField.Value) > 2000 {
            this.Notify('Задержка должна быть от 50 до 2000 мс.')
            return
        }
        this.chatKey := key
        this.chatDelay := Integer(this.chatDelayField.Value)
        IniWrite this.chatKey, this.ini, 'Input', 'ChatKey'
        IniWrite this.chatDelay, this.ini, 'Input', 'ChatDelay'
        for name, field in this.variables
            IniWrite field.Value, this.ini, 'Variables', name
        this.Refresh()
        this.Notify('Настройки сохранены')
    }

    Activate() {
        HotIf this.triggerContext
        for name in this.registered
            Hotstring name, , 'Off'
        this.registered := [], failures := []
        for item in this.config.entries {
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
        HotIf this.context
        for key in this.bound
            Hotkey key, 'Off'
        this.bound := []
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
        this.entry.Register()
    }

    TriggerAllowed(*) {
        active := WinExist('A')
        if !active
            return false
        if active = this.testChatHwnd
            return true
        if A_Args.Length && (A_Args[1] = '--check' || A_Args[1] = '--ui-test')
            return false
        return WinGetPID('ahk_id ' active) != DllCall('GetCurrentProcessId', 'uint')
    }

    BuildActions(text) {
        for name, field in this.variables
            text := StrReplace(text, '%' name '%', field.Value)
        text := this.PrepareCommands(text)
        actions := [], pos := 1
        while RegExMatch(text, '\{([^{}]+)\}', &match, pos) {
            literal := SubStr(text, pos, match.Pos - pos)
            if literal != ''
                actions.Push({type: 'text', value: literal})
            token := StrLower(match[1])
            if token = 'rep' {
                if !actions.Length || actions[-1].type != 'key' || actions[-1].value != 'Enter'
                    actions.Push({type: 'key', value: 'Enter'})
            } else if token = 'enter' || token = 'tab' || token = 'esc'
                actions.Push({type: 'key', value: token = 'enter' ? 'Enter' : token})
            else if RegExMatch(token, '^(left|right|space)(?: (\d{1,3}))?$', &action) {
                count := action[2] = '' ? 1 : Min(100, Integer(action[2]))
                actions.Push({type: 'key', value: action[1] ' ' count})
            } else if token = '!'
                actions.Push({type: 'text', value: '!'})
            pos := match.Pos + match.Len
        }
        if pos <= StrLen(text)
            actions.Push({type: 'text', value: SubStr(text, pos)})
        return actions
    }

    Emit(text, openChat, *) {
        if !(openChat ? this.context() : this.triggerContext())
            return
        target := WinExist('A')
        actions := this.BuildActions(text)
        if openChat {
            for modifier in ['Ctrl', 'Alt', 'Shift', 'LWin', 'RWin']
                KeyWait modifier
            if !this.context() || WinExist('A') != target
                return
            SendEvent '{' this.chatKey '}'
            Sleep this.chatDelay
        }
        for action in actions {
            if WinExist('A') != target
                return
            if target = this.testChatHwnd {
                this.ApplyTestAction(action)
                continue
            }
            if action.type = 'text' {
                if this.context()
                    SendText action.value
                else
                    SendInput '{Text}' action.value
            } else {
                SendEvent '{' action.value '}'
                Sleep 60
            }
        }
    }

    OpenTriggerTest(*) {
        if this.testChatHwnd && DllCall('IsWindow', 'ptr', this.testChatHwnd) {
            this.testChat.Show()
            return
        }
        g := DarkDialog.Window('Проверка триггеров', 780, this.CloseTriggerTest.Bind(this))
        this.testChat := g
        this.testChatHwnd := g.Hwnd
        g.AddText('x24 y78 w732 h54 cB0B0BD', 'Введи .ку и нажми пробел. Сообщение появится в журнале ниже.`nЭто локальная проверка: текст никуда не отправляется.')
        this.testInput := g.AddEdit('x24 y150 w732 h40 Background171719 cEEEEF2 -Multi -VScroll')
        Theme.SingleLine(this.testInput)
        this.testInputHwnd := this.testInput.Hwnd
        this.testStatus := g.AddText('x24 y210 w732 h26 cA695EC', 'Отправлено сообщений: 0')
        this.testOutput := g.AddEdit('x24 y251 w732 h164 ReadOnly Background171719 cEEEEF2')
        Theme.Dark(this.testOutput)
        this.testMessages := []
        Theme.Button(g, 'x24 y438 w180 h38', 'Очистить').OnEvent('Click', (*) => this.ClearTriggerTest())
        g.Show('w780 h502' (A_Args.Length && A_Args[1] = '--check' ? ' Hide' : ''))
        this.testInput.Focus()
    }

    CloseTriggerTest(*) {
        this.testChatHwnd := 0
        this.testInputHwnd := 0
    }

    ClearTriggerTest() {
        this.testMessages := []
        this.testInput.Value := ''
        this.testOutput.Value := ''
        this.testStatus.Text := 'Отправлено сообщений: 0'
    }

    ApplyTestAction(action) {
        if action.type = 'text'
            SendMessage 0xC2, true, StrPtr(action.value), this.testInput
        else if action.value = 'Enter'
            this.RecordTestMessage()
        else if RegExMatch(action.value, '^(left|right|space) (\d+)$', &movement) {
            count := Integer(movement[2])
            if movement[1] = 'space' {
                spaces := ''
                loop count
                    spaces .= ' '
                SendMessage 0xC2, true, StrPtr(spaces), this.testInput
            } else {
                start := Buffer(4), finish := Buffer(4)
                SendMessage 0xB0, start.Ptr, finish.Ptr, this.testInput
                position := movement[1] = 'left' ? Max(0, NumGet(start, 0, 'uint') - count) : Min(StrLen(this.testInput.Value), NumGet(finish, 0, 'uint') + count)
                SendMessage 0xB1, position, position, this.testInput
            }
        } else if action.value = 'esc'
            this.testInput.Value := ''
    }

    RecordTestMessage() {
        value := this.testInput.Value
        if value = ''
            return
        this.testMessages.Push(value)
        this.testOutput.Value := this.Join(this.testMessages)
        this.testInput.Value := ''
        this.testStatus.Text := 'Отправлено сообщений: ' this.testMessages.Length
    }

    TestKeyDown(key, lp, msg, hwnd) {
        if key = 13 && hwnd = this.testInputHwnd {
            this.RecordTestMessage()
            return 0
        }
    }

}

RunChecks() {
    checkData := A_ScriptDir '\work\check-data-' DllCall('GetCurrentProcessId', 'uint')
    DirCreate checkData
    IniWrite 37, checkData '\settings.ini', 'Reports', 'Norm'
    app := Binder()
    if app.normWeekday != 37 || app.normWeekend != 37
        throw Error('Не перенесена старая дневная норма')
    for required in ['0.1.0', '0.2.0', '0.3.0', '0.4.0', '0.5.0'] {
        found := false
        for entry in app.history {
            if entry.version = required
                found := true
        }
        if !found
            throw Error('Из истории пропала версия ' required)
    }
    if app.historyScroll.cards.Length != app.history.Length
        throw Error('Не все версии отображаются в истории')
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
    for column in [1, 2, 3] {
        if Theme.ListText(app.list, 0, column - 1) != app.list.GetText(1, column)
            throw Error('Прямое чтение ячейки отличается от текста ListView')
    }
    FileAppend 'OK: duplicate detection, malformed lines, action preservation, pages, search`n', '*'
    for name in ['Оверлеи', 'Репорты', 'Бинды клавиш', 'Триггеры', 'Настройки', 'Основное'] {
        CheckClick(app.nav[name])
        if app.currentPage != name
            throw Error('Не работает кнопка раздела: ' name)
    }
    CheckClickText(app, 'Основное', '▤ Change Log')
    if app.currentPage != 'Change Log'
        throw Error('Не работает страница Change Log')
    CheckClickText(app, 'Change Log', '← На главную')
    app.Guide()
    if app.currentPage != 'Гайд' || app.guideScroll.cards.Length != 7
        throw Error('Не работает страница гайда')
    CheckClickText(app, 'Гайд', '← На главную')
    app.ShowPage('Change Log')
    scroll := app.historyScroll
    if scroll.total <= scroll.height
        throw Error('История не содержит ожидаемого объёма текста')
    SendMessage 0x20A, (65536 - 120) << 16, 0, scroll.viewport.Hwnd
    Sleep 40
    if scroll.offset <= 0
        throw Error('Не работает колесо мыши в истории')
    SendMessage 0x115, 7, 0, scroll.viewport.Hwnd
    Sleep 40
    if scroll.offset != scroll.total - scroll.height
        throw Error('Не работает прокрутка к последней версии')
    scrollInfo := Buffer(28, 0)
    NumPut('uint', 28, 'uint', 4, scrollInfo)
    DllCall('GetScrollInfo', 'ptr', scroll.viewport.Hwnd, 'int', 1, 'ptr', scrollInfo)
    if NumGet(scrollInfo, 20, 'int') != Round(scroll.offset)
        throw Error('Полоса прокрутки не соответствует положению страницы')
    scroll.SetOffset(0)
    app.ShowPage('Основное')
    app.switchingPage := true
    app.ShowPage('Репорты')
    app.ShowPage('Настройки')
    app.switchingPage := false
    app.DispatchQueuedPage()
    if app.currentPage != 'Настройки' || app.queuedPage != ''
        throw Error('Повторные клики не открывают последнюю выбранную страницу')
    for page, controls in app.pages {
        if page = app.currentPage
            continue
        for control in controls {
            if control is ScrollPage {
                if control.Visible
                    throw Error('Прокручиваемая область осталась на чужой странице')
            } else if DllCall('GetWindowLongPtr', 'ptr', control.Hwnd, 'int', -16, 'ptr') & 0x10000000
                throw Error('Элемент раздела остался видимым после переключения: ' page)
        }
    }
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
    for faction in ['LSPD', 'FIB', 'SANG', 'LSCSD'] {
        CheckClick(app.factionButtons[faction])
        if app.faction != faction
            throw Error('Не работает кнопка фракции: ' faction)
    }
    for extra in ['GOV', 'EMS', 'WN', 'BALLAS', 'VAGOS', 'FAM', 'BLOODS', 'MARA'] {
        app.SetFaction(extra)
        if app.factionButtons['Все'].Text != 'Все' || Theme.items[app.factionButtons['Все'].Hwnd].selected || IniRead(app.ini, 'General', 'Faction') != extra
            throw Error('Не работает дополнительная фракция ' extra)
    }
    SetTimer(ChooseEMS, -100)
    CheckClick(app.factionButtons['Все'])
    if app.faction != 'EMS'
        throw Error('Кнопка остальных фракций не открывает выбор')
    SetTimer((*) => CheckClick(DarkDialog.last.buttons[2]), -100)
    CheckClick(app.factionButtons['Все'])
    if app.faction != 'EMS'
        throw Error('Отмена выбора изменила фракцию')
    for faction, id in BinderFeatures.factionIDs {
        app.SetFaction(faction)
        if app.PrepareCommands('/templeader{space}') != '/templeader ' id '{space}' || app.PrepareCommands('/templeader 99') != '/templeader ' id
            throw Error('Неверный ID /templeader: ' faction)
        if app.PrepareCommands('/prange 1000 99') != '/prange 1000 ' id || app.PrepareCommands('/prange 500') != '/prange 500 ' id
            throw Error('Неверный ID /prange: ' faction)
    }
    app.SetFaction('LSPD')
    CheckClick(app.genderButtons['female'])
    if app.gender != 'female'
        throw Error('Не работает женский набор')
    CheckClick(app.genderButtons['male'])
    if app.gender != 'male'
        throw Error('Не работает мужской набор')
    CheckClick(app.espButtons[2])
    if app.PrepareCommands('/esp 3') != '/esp 2'
        throw Error('Не работает выбор /esp')
    app.ShowPage('Команды при входе')
    if app.currentPage != 'Команды при входе' || app.entry.buttons.Count != 9
        throw Error('Не открывается список команд при входе')
    for command in EntryCommands.commands {
        if !app.entry.selected[command]
            app.entry.Toggle(command)
    }
    app.SetFaction('FIB')
    for n in [1, 2, 3] {
        app.entry.ChooseESP(n)
        queue := app.entry.Queue()
        if queue.Length != 9 || queue[4] != '/esp ' n || queue[5] != '/templeader 7'
            throw Error('Неверный порядок или параметры очереди команд')
    }
    app.faction := 'Все'
    rejected := false
    try app.entry.Queue()
    catch ValueError
        rejected := true
    if !rejected
        throw Error('Темплидерка запускается без выбранной фракции')
    app.SetFaction('FIB')
    app.entry.triggerField.Value := '.entry_test'
    app.entry.keyField.Value := 'F9'
    app.entry.Save()
    reloadedEntry := EntryCommands(app)
    if reloadedEntry.trigger != '.entry_test' || reloadedEntry.key != 'F9' || !reloadedEntry.selected['/netstat']
        throw Error('Набор команд не сохранился после перезапуска')
    app.entry.Toggle('/netstat')
    if app.entry.Queue().Length != 8
        throw Error('Выключенная команда осталась в очереди')
    if app.entry.Conflict('F9', '/tl') = ''
        throw Error('Конфликт с существующим триггером не обнаружен')
    FileAppend 'OK: entry command queue, ESP modes, factions, persistence and conflicts`n', '*'
    app.ShowPage('Бинды клавиш')
    CheckClickText(app, 'Бинды клавиш', '+ Добавить бинд')
    app.editorFields.key.control.GetPos(&editorX, &editorY)
    app.editorFields.gui.GetPos(, , &editorWidth)
    if editorX != 24 || editorY < 78 || editorWidth > 760 * A_ScreenDPI / 96
        throw Error('Содержимое редактора смещено относительно заголовка')
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
    ReportCounter.Accept(app, '10000001', FormatTime(, 'yyyyMMddHHmmss'))
    if app.ReportCounts().day != 1
        throw Error('Не работает счётчик репортов')
    if app.historyTiles.Length != 14 || app.historyTiles[1].count.Text != '1'
        throw Error('Не обновляется история репортов')
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
    if !GameWindow.Matches('Grand Theft Auto V', 'grcWindow') || GameWindow.Matches('Grand Theft Auto V', 'Chrome_WidgetWin_1') || GameWindow.Matches('Majestic Launcher', 'grcWindow')
        throw Error('Автоопределение выбирает неподходящее окно')
    probe := Gui(, 'Тест привязки окна')
    probe.AddText(, 'Тест')
    target := GameWindow(app.ini)
    target.Use(probe.Hwnd)
    if target.hwnd != probe.Hwnd || target.mode != 'manual' || target.Active()
        throw Error('Неверная привязка скрытого окна')
    restoredTarget := GameWindow(app.ini)
    if restoredTarget.mode != 'manual' || restoredTarget.title != 'Тест привязки окна'
        throw Error('Выбранное окно не сохранилось')
    probe.Destroy()
    if target.Refresh() || target.Active()
        throw Error('Закрытое окно осталось целью биндов')
    target.Use()
    if target.mode != 'auto'
        throw Error('Не включается автоматический поиск окна')
    app.chatKeyField.Value := 'F6'
    app.chatDelayField.Value := '250'
    CheckClickText(app, 'Настройки', 'Сохранить настройки')
    if IniRead(app.ini, 'Input', 'ChatKey') != 'F6' || IniRead(app.ini, 'Input', 'ChatDelay') != '250'
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
    app.CreateOverlay(0, app.ReportOverlayText(app.ReportCounts()), '', 40, 60)
    overlayHandle := app.overlayWindows[1].gui.Hwnd
    builds := app.overlayBuilds
    paints := app.statsPaints
    loop 20 {
        app.DailyRefresh()
        app.UpdateStats()
    }
    if app.overlayBuilds != builds || app.statsPaints != paints
        throw Error('Фоновое обновление повторно строит неизменившийся интерфейс')
    ReportCounter.Accept(app, '10000002', FormatTime(, 'yyyyMMddHHmmss'))
    if app.overlayWindows[1].gui.Hwnd != overlayHandle || app.overlayBuilds != builds
        throw Error('Изменение счётчика пересоздало окно оверлея')
    if !InStr(app.overlayWindows[1].textControl.Text, app.ReportCounts().day ' /')
        throw Error('Текст оверлея не обновился')
    app.ShowPage('Триггеры')
    app.search.Value := ''
    app.Refresh()
    app.list.Modify(1, 'Select Focus')
    app.Refresh()
    if app.list.GetNext() != 1
        throw Error('Неизменившийся поиск повторно создаёт строки')
    app.search.Value := '/hatiksu_test'
    app.ScheduleSearch()
    Sleep 220
    if app.rows.Length != 1 || app.rows[1].key != '/hatiksu_test'
        throw Error('Не работает отложенный поиск')
    if Theme.listData[app.list.Hwnd].Length != app.list.GetCount() || Theme.listData[app.list.Hwnd][1][2] != app.list.GetText(1, 2)
        throw Error('Данные отрисовки списка не соответствуют результатам поиска')
    cachePointer := ObjPtr(Theme.listData[app.list.Hwnd])
    app.ShowPage('Основное')
    app.ShowPage('Триггеры')
    if ObjPtr(Theme.listData[app.list.Hwnd]) != cachePointer
        throw Error('Возврат в раздел заново создал неизменившийся список')
    app.SetFaction('WN')
    app.SetESP(2)
    for name, value in Map('dis', '@мой_дискорд', 'gadis', '@главный', 'zgadis', '@заместитель') {
        app.variables[name].Value := value
        app.SaveVariable(name, app.variables[name])
    }
    app.PersistPreferences()
    loaded := {}
    ObjSetBase(loaded, Binder.Prototype)
    loaded.InitProfile()
    if loaded.faction != 'WN' || loaded.esp != '2'
        throw Error('Фракция или ESP не восстановились из сохранённого профиля')
    for name, field in app.variables {
        if IniRead(loaded.ini, 'Variables', name) != field.Value
            throw Error('Не сохранилось Discord-поле ' name)
    }
    first := app.BuildActions('Приветствую.{enter}{rep}')
    second := app.BuildActions('Здравствуйте.{rep}')
    if first.Length != 2 || first[2].value != 'Enter' || second.Length != 2 || second[2].value != 'Enter'
        throw Error('Маркер rep должен отправлять один Enter')
    app.OpenTriggerTest()
    countBefore := app.ReportCounts().day
    for action in first
        app.ApplyTestAction(action)
    if app.testMessages.Length != 1 || app.testMessages[1] != 'Приветствую.' || app.ReportCounts().day != countBefore
        throw Error('Проверка триггера отправляет текст неверно или меняет счётчик')
    app.testChat.Destroy()
    app.CloseTriggerTest()
    FileAppend 'OK: saved faction, ESP and Discord fields; rep sends once; local trigger test does not change report counts`n', '*'
    FileAppend 'OK: complete version history, guide layout, wheel and scrollbar, cached stats, stable overlays, debounced search`n', '*'
    FileAppend 'OK: legacy norm migration, weekday/weekend boundaries, single-line inputs, dark dialogs, confirmations, file picker`n', '*'
    detector := ReportDetector()
    box := {x: 100, y: 100, w: 160, h: 40}
    detector.Observe('23267105', false, box, 1000)
    detector.Observe('23267105', false, box, 1300)
    detector.Click(150, 120, 1400)
    if detector.Observe('', false, 0, 1600) != ''
        throw Error('Потеря распознавания засчитана как закрытие')
    if detector.Observe('', true, 0, 1900) != '' || detector.Observe('', true, 0, 2200) != '23267105'
        throw Error('Подтверждённое закрытие не распознано')
    if detector.Observe('', true, 0, 2500) != ''
        throw Error('Повторное подтверждение прибавило репорт')
    detector.Observe('23267140', false, box, 3000)
    detector.Observe('23267140', false, box, 3300)
    detector.Click(150, 120, 3400)
    detector.Observe('23267105', false, box, 3500)
    if detector.Observe('', true, 0, 3700) != '' || detector.Observe('', true, 0, 4000) != ''
        throw Error('Переход к другому обращению засчитан как закрытие')
    beforeAuto := app.ReportCounts().day
    date := FormatTime(, 'yyyyMMddHHmmss')
    if !ReportCounter.Accept(app, '23267105', date) || ReportCounter.Accept(app, '23267105', date)
        throw Error('Не работает защита от повторного подсчёта')
    restored := {}
    ObjSetBase(restored, Binder.Prototype)
    restored.InitProfile()
    if restored.ReportCounts().day != beforeAuto + 1 || !restored.autoClosed.Has('23267105')
        throw Error('После перезапуска потерялся счётчик или защита от дублей')
    app.overlayMoving := true
    movingHUD := ReportOverlay(app, 40, 60)
    if movingHUD.gui.BackColor != '202023'
        throw Error('Не работает режим перемещения прозрачного оверлея')
    movingHUD.gui.Destroy()
    app.overlayMoving := false
    FileAppend 'OK: confirmed closure, OCR gaps, report switching, deduplication, restart and automatic totals`n', '*'
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
    ChooseEMS() {
        DarkDialog.last.list.Modify(1, '-Select')
        DarkDialog.last.list.Modify(2, 'Select Focus')
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
if A_Args.Length && A_Args[1] = '--profile-ui' {
    uiProfilePoll := WaitForProfileWindow.Bind(rootBinder)
    SetTimer uiProfilePoll, 100
}

WaitForProfileWindow(app) {
    global uiProfilePoll
    if !DllCall('IsWindowVisible', 'ptr', app.window.Hwnd)
        return
    SetTimer uiProfilePoll, 0
    RunNavigationProfile(app)
}

RunNavigationProfile(app) {
    NavigationProfile(app)
}

class NavigationProfile {
    __New(app) {
        this.app := app
        label := A_Args.Length >= 2 ? A_Args[2] : 'navigation'
        DirCreate A_ScriptDir '\work'
        this.path := A_ScriptDir '\work\ui-profile-' RegExReplace(label, '[^a-zA-Z0-9_-]') '.txt'
        if FileExist(this.path)
            FileDelete this.path
        this.names := ['Триггеры', 'Основное', 'Триггеры', 'Бинды клавиш', 'Триггеры', 'Репорты', 'Триггеры', 'Настройки', 'Основное']
        this.index := 0
        this.pending := ''
        this.completed := A_TickCount
        this.receive := this.Complete.Bind(this)
        for name, button in app.nav
            button.OnEvent('Click', this.receive)
        this.timerCallback := this.Tick.Bind(this)
        SetTimer this.timerCallback, 20
    }

    Tick() {
        if this.pending != '' {
            if A_TickCount - this.started > 3000 {
                FileAppend 'TIMEOUT ' this.pending '`n', this.path, 'UTF-8'
                this.Stop()
            }
            return
        }
        if A_TickCount - this.completed < 150
            return
        this.index += 1
        if this.index > this.names.Length * 3 {
            FileAppend 'DONE`n', this.path, 'UTF-8'
            this.Stop()
            return
        }
        this.pending := this.names[Mod(this.index - 1, this.names.Length) + 1]
        this.started := A_TickCount
        PostMessage 0xF5, 0, 0, this.app.nav[this.pending]
    }

    Complete(control, *) {
        if this.pending = '' || control.Hwnd != this.app.nav[this.pending].Hwnd
            return
        if this.app.currentPage != this.pending {
            FileAppend 'WRONG PAGE ' this.pending '`n', this.path, 'UTF-8'
            this.Stop()
            return
        }
        DllCall('RedrawWindow', 'ptr', this.app.window.Hwnd, 'ptr', 0, 'ptr', 0, 'uint', 0x185)
        this.completed := A_TickCount
        FileAppend (this.completed - this.started) ' ms ' this.pending '`n', this.path, 'UTF-8'
        this.pending := ''
    }

    Stop() {
        SetTimer this.timerCallback, 0
        for name, button in this.app.nav
            button.OnEvent('Click', this.receive, 0)
    }
}
