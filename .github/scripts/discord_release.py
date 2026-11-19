import json
import os
import re
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlparse, urlunparse, parse_qsl, urlencode
from urllib.request import Request, urlopen
SUPPORT = 'https://discord.gg/HhEAgE3XGZ'

def payload(release):
    version = release['tag_name'].removeprefix('v')
    description = (release.get('body') or 'Новая версия биндера уже доступна.').strip()
    description = re.sub('\\[Поддержка в Discord\\]\\([^)]*\\)\\.?', '', description).strip()
    description = re.sub('(?m)^#{1,6}\\s+(.+)$', '**\\1**', description)
    if len(description) > 3500:
        description = description[:3400].rstrip() + '\n\nПолное описание доступно на странице релиза.'
    archive = next((a for a in release.get('assets', []) if a['name'].startswith('Binder-by-Hatiksu-v') and a['name'].endswith('.zip') and (a.get('state') == 'uploaded')), None)
    download = archive['browser_download_url'] if archive else release['html_url']
    embed = {'title': 'Binder by Hatiksu ' + version, 'url': release['html_url'], 'description': description, 'color': 7757311, 'fields': [{'name': 'Скачать', 'value': f'[Архив с биндером]({download})', 'inline': True}, {'name': 'GitHub', 'value': f"[Открыть релиз]({release['html_url']})", 'inline': True}, {'name': 'Поддержка', 'value': f'[Поддержка в Discord]({SUPPORT}).'}]}
    if release.get('published_at'):
        embed['timestamp'] = release['published_at']
    return {'username': 'Binder by Hatiksu', 'allowed_mentions': {'parse': []}, 'embeds': [embed]}

def get_release(repository, tag, token):
    url = f"https://api.github.com/repos/{repository}/releases/tags/{quote(tag, safe='')}"
    headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'Binder-by-Hatiksu'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    with urlopen(Request(url, headers=headers), timeout=20) as response:
        return json.load(response)

def send(webhook, message):
    parsed = urlparse(webhook)
    if parsed.scheme != 'https' or parsed.hostname != 'discord.com' or (not re.fullmatch('/api(?:/v\\d+)?/webhooks/\\d+/[A-Za-z0-9_-]+', parsed.path)):
        raise ValueError('Некорректный адрес Discord webhook')
    query = dict(parse_qsl(parsed.query))
    query['wait'] = 'true'
    url = urlunparse(parsed._replace(query=urlencode(query)))
    request = Request(url, data=json.dumps(message, ensure_ascii=False).encode('utf-8'), headers={'Content-Type': 'application/json', 'User-Agent': 'Binder-by-Hatiksu'}, method='POST')
    with urlopen(request, timeout=25) as response:
        result = json.load(response)
        print('Анонс опубликован. Сообщение: ' + result['id'])

def main():
    if len(sys.argv) == 3 and sys.argv[1] == '--preview':
        print(json.dumps(payload(json.loads(Path(sys.argv[2]).read_text(encoding='utf-8'))), ensure_ascii=False, indent=2))
        return
    webhook = os.environ.get('DISCORD_WEBHOOK_URL', '')
    if not webhook:
        raise ValueError('Добавьте secret DISCORD_RELEASE_WEBHOOK в настройках Actions репозитория')
    repository = os.environ['GITHUB_REPOSITORY']
    tag = os.environ['RELEASE_TAG']
    for attempt in range(25):
        release = get_release(repository, tag, os.environ.get('GH_TOKEN', ''))
        if release.get('draft') or release.get('prerelease'):
            print('Черновики и предварительные версии не публикуются.')
            return
        if any((a.get('state') == 'uploaded' and a['name'].startswith('Binder-by-Hatiksu-v') and a['name'].endswith('.zip') for a in release.get('assets', []))):
            send(webhook, payload(release))
            return
        if attempt < 24:
            time.sleep(5)
    raise ValueError('Архив релиза ещё не загружен. Запустите workflow повторно после загрузки ZIP')
if __name__ == '__main__':
    try:
        main()
    except HTTPError as error:
        print(f'Сервис вернул HTTP {error.code}.', file=sys.stderr)
        sys.exit(1)
    except URLError:
        print('Не удалось соединиться с сервисом. Адрес вебхука скрыт.', file=sys.stderr)
        sys.exit(1)
    except (ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
