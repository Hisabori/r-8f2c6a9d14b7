from pathlib import Path
import argparse, hashlib, json, plistlib, struct, zipfile
ROOT = Path(__file__).resolve().parents[1]
MODELS = {'yamnet.tflite': '10c95ea3eb9a7bb4cb8bddf6feb023250381008177ac162ce169694d05c317de', 'research-sleep.onnx': 'ccc3c94646cab11d53fab9d2bedae8c777c3c5ec3f0926a421c35fe44c46400c'}
for name, digest in MODELS.items():
    assert hashlib.sha256((ROOT/'Resources'/name).read_bytes()).hexdigest() == digest
for folder in ['App','Care','Native','Packages']:
    for file in (ROOT/folder).rglob('*.swift'):
        text = file.read_text(encoding='utf-8-sig')
        assert 'import Flutter' not in text and 'FlutterMethodChannel' not in text
assert not (ROOT/'pubspec.yaml').exists()
parser = argparse.ArgumentParser(); parser.add_argument('--app',type=Path); args=parser.parse_args()
if args.app:
    app=args.app
    info=plistlib.loads((app/'Info.plist').read_bytes())
    assert info['CFBundleIdentifier']=='app.caresuite.super'
    assert info['CFBundleShortVersionString']=='0.4.16' and info['CFBundleVersion']=='21'
    executable=app/info['CFBundleExecutable']
    magic,cpu=struct.unpack('<II',executable.read_bytes()[:8])
    assert magic==0xfeedfacf and cpu==0x100000c
    assert not any('Flutter' in p.name or 'App.framework'==p.name for p in app.rglob('*'))
    for name,digest in MODELS.items(): assert hashlib.sha256((app/name).read_bytes()).hexdigest()==digest
    ids={plistlib.loads((p/'Info.plist').read_bytes())['CFBundleIdentifier'] for p in (app/'PlugIns').glob('*.appex')}
    assert {'app.caresuite.super.healthlive','app.caresuite.super.barklive'}<=ids
print(json.dumps({'source_verified':True,'model_hashes_verified':True,'native_device_payload_verified':bool(args.app),'physical_device_verified':False}))
