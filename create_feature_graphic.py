#!/usr/bin/env python3
import sys
import subprocess

# Create a white canvas 1024x500
subprocess.run([
    'sips',
    '-c', '500', '1024',
    '--setProperty', 'format', 'png',
    '-o', '/Users/zhihan/projects/hymnal_mobile/feature_graphic_base.png',
    '/Users/zhihan/projects/hymnal_mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'
])

# Resize icon to fit nicely in the banner (400x400 to leave margins)
subprocess.run([
    'sips',
    '-z', '400', '400',
    '/Users/zhihan/projects/hymnal_mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    '--out', '/Users/zhihan/projects/hymnal_mobile/icon_400.png'
])

print("Base canvas and icon created. Manual compositing required.")
