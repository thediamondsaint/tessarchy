"""Every visible boot surface must say Tessarchy, and keep the build tokens.

The ISO is built from a copy of releng's profile, so any file this repository
does NOT override comes back as Arch branding ("Arch Linux install medium",
Arch's splash, HDT and memtest entries). These tests hold the line on the
override set and on the placeholder tokens mkarchiso substitutes at build
time — a literal path where %INSTALL_DIR% belongs produces a medium that
cannot find itself and drops to a rescue shell.
"""
import importlib.util
import re
import struct
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
BOOT = ROOT / 'iso/boot'
script_spec = importlib.util.spec_from_file_location(
    'boot_assets', ROOT / 'scripts/export-boot-assets.py')
boot_assets = importlib.util.module_from_spec(script_spec)
script_spec.loader.exec_module(boot_assets)

# mkarchiso substitutes these into every boot configuration it installs.
TOKENS = ('%INSTALL_DIR%', '%ARCH%', '%ARCHISO_UUID%')


def png_size(path):
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise AssertionError(f'{path} is not a PNG')
    width, height = struct.unpack('>II', data[16:24])
    return width, height


class BootMenus(unittest.TestCase):
    def setUp(self):
        self.files = sorted(BOOT.rglob('*'))

    def test_the_boot_tree_carries_the_overrides(self):
        for expected in ('syslinux/archiso_head.cfg', 'syslinux/archiso_sys-linux.cfg',
                         'syslinux/archiso_tail.cfg', 'grub/loopback.cfg',
                         'efiboot/loader/loader.conf'):
            self.assertIn(BOOT / expected, self.files)

    def test_nothing_in_the_boot_tree_reads_as_arch(self):
        for path in self.files:
            if not path.is_file() or path.suffix == '.png':
                continue
            text = path.read_text(errors='replace')
            self.assertNotIn('Arch Linux', text, path)
            self.assertIsNone(re.search(r'\bArch\b', text), path)

    def test_kernel_paths_and_the_medium_uuid_stay_substitutable(self):
        for path in self.files:
            if not path.is_file() or path.suffix == '.png':
                continue
            text = path.read_text(errors='replace')
            if 'vmlinuz' in text or 'initramfs' in text:
                self.assertIn('%INSTALL_DIR%', text, path)
                self.assertIn('%ARCH%', text, path)
            if 'archisosearchuuid' in text:
                self.assertIn('%ARCHISO_UUID%', text, path)
            self.assertNotIn('/arch/boot/', text, path)

    def test_the_menu_background_is_a_vesa_sized_png_named_splash(self):
        # mkarchiso copies exactly one image from syslinux/ and only under this
        # name; any other filename reaches the built ISO as nothing at all.
        background = BOOT / 'syslinux/splash.png'
        self.assertEqual(png_size(background), (640, 480))
        head = (BOOT / 'syslinux/archiso_head.cfg').read_text()
        artwork = (BOOT / 'syslinux/splash.svg').read_text()
        self.assertIn('MENU BACKGROUND splash.png', head)
        self.assertIn('Tessarchy', head)
        self.assertIn('TESSARCHY', artwork)
        self.assertIn('TESSA NETWORK INSTALLER', artwork)
        self.assertNotIn('Quiet Edge', artwork + head)
        self.assertEqual([p.name for p in (BOOT / 'syslinux').glob('*.png')], ['splash.png'])

    def test_the_isolinux_labels_are_unique_and_tessarchy_led(self):
        labels = []
        for name in ('archiso_sys-linux.cfg', 'archiso_tail.cfg'):
            for line in (BOOT / 'syslinux' / name).read_text().splitlines():
                if line.startswith('LABEL '):
                    labels.append(line.split(None, 1)[1])
        self.assertEqual(len(labels), len(set(labels)))
        self.assertIn('arch', labels)

    def test_the_uefi_default_entry_exists(self):
        loader = (BOOT / 'efiboot/loader/loader.conf').read_text()
        match = re.search(r'^default\s+(\S+)$', loader, re.MULTILINE)
        self.assertIsNotNone(match)
        self.assertTrue((BOOT / 'efiboot/loader/entries' / match.group(1)).is_file())

    def test_every_uefi_entry_is_tessarchy_led_or_a_tool(self):
        entries = sorted((BOOT / 'efiboot/loader/entries').glob('*.conf'))
        self.assertTrue(entries)
        titles = [re.search(r'^title\s+(.*)$', p.read_text(), re.MULTILINE).group(1)
                  for p in entries]
        live = [t for t in titles if 'memtest' not in t.lower()]
        self.assertTrue(all('Tessarchy' in t for t in live), titles)


class SplashHold(unittest.TestCase):
    """The Plymouth theme must not settle on the clip's fade-out frame."""

    def setUp(self):
        self.script = (ROOT / 'session/boot/tessarchy.script').read_text()

    def test_the_theme_holds_an_exported_rest_frame(self):
        self.assertIn('logo-rest.png', self.script)

    def test_the_rest_frame_matches_the_clip(self):
        match = re.search(r'^REST_FRAME\s*=\s*(\d+);', self.script, re.MULTILINE)
        self.assertIsNotNone(match, 'REST_FRAME is not declared')
        if not shutil.which('ffmpeg'):
            self.skipTest('ffmpeg unavailable to measure the clip')
        clip = ROOT / 'session/boot/power-on.mp4'
        self.assertEqual(int(match.group(1)), boot_assets.rest_frame(clip))

    def test_the_exported_rest_frame_is_not_the_last_frame(self):
        if not shutil.which('ffmpeg'):
            self.skipTest('ffmpeg unavailable to measure the clip')
        rest = boot_assets.rest_frame(ROOT / 'session/boot/power-on.mp4')
        self.assertLess(rest, boot_assets.FRAMES - 1,
                        'holding the final frame is what left the screen empty')


class LiveText(unittest.TestCase):
    def test_the_live_motd_names_tessarchy_and_the_installer(self):
        motd = (ROOT / 'iso/airootfs/etc/motd').read_text()
        self.assertIn('Tessarchy', motd)
        self.assertIn('tessarchy-install', motd)
        for stale in ('no installer', 'Arch Linux install medium'):
            self.assertNotIn(stale, motd)

    def test_staging_overrides_releng_boot_files_and_names_the_product(self):
        staging = (ROOT / 'scripts/stage-iso.sh').read_text()
        self.assertIn('iso/boot', staging)
        self.assertIn('iso_publisher="Tessarchy"', staging)
        self.assertNotIn('prototype"', staging.split('iso_publisher=')[1][:60])


if __name__ == '__main__':
    unittest.main()
