import unittest
from unittest.mock import patch
import discord_release

class ReleaseMessageTests(unittest.TestCase):

    def release(self, body='Исправлено сохранение настроек.'):
        return {'tag_name': 'v0.9.1', 'body': body, 'html_url': 'https://github.com/hatiksu/ahk_binder/releases/tag/v0.9.1', 'assets': [{'name': 'Binder-by-Hatiksu-v0.9.1.zip', 'state': 'uploaded', 'browser_download_url': 'https://github.com/hatiksu/ahk_binder/releases/download/v0.9.1/Binder-by-Hatiksu-v0.9.1.zip'}]}

    def test_message_links_and_mentions(self):
        message = discord_release.payload(self.release('@everyone Новая версия'))
        self.assertEqual(message['allowed_mentions'], {'parse': []})
        embed = message['embeds'][0]
        self.assertEqual(embed['title'], 'Binder by Hatiksu 0.9.1')
        self.assertIn('.zip', embed['fields'][0]['value'])
        self.assertTrue(embed['fields'][-1]['value'].endswith(').'))

    def test_description_limit_and_formatting(self):
        embed = discord_release.payload(self.release('### Изменения\n' + 'Текст ' * 1000))['embeds'][0]
        self.assertLessEqual(len(embed['description']), 4096)
        self.assertTrue(embed['description'].startswith('**Изменения**'))

    def test_webhook_destination(self):
        with patch('discord_release.urlopen') as request:
            for url in ['http://discord.com/api/webhooks/1/token', 'https://example.com/api/webhooks/1/token']:
                with self.assertRaises(ValueError):
                    discord_release.send(url, {})
            request.assert_not_called()

    def test_failed_send_is_not_retried(self):
        with patch('discord_release.urlopen', side_effect=discord_release.URLError('offline')) as request:
            with self.assertRaises(discord_release.URLError):
                discord_release.send('https://discord.com/api/webhooks/123/token', {})
            self.assertEqual(request.call_count, 1)
if __name__ == '__main__':
    unittest.main()
