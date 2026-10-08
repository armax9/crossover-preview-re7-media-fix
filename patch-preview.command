#!/bin/bash
set -euo pipefail
/usr/bin/python3 - "$@" <<'PY'
import os,sys,subprocess,shutil,json,time,argparse,pwd
from pathlib import Path
parser=argparse.ArgumentParser(description='RE7 media compatibility patch for CrossOver Preview')
parser.add_argument('--app',default='/Applications/CrossOver Preview.app')
parser.add_argument('--bottle',default='Steam')
parser.add_argument('--bottles-dir')
parser.add_argument('--check',action='store_true')
parser.add_argument('--restore',action='store_true')
parser.add_argument('--diagnostics',action='store_true')
args=parser.parse_args()
user=pwd.getpwuid(int(os.environ.get('SUDO_UID',os.getuid())))
userhome=Path(user.pw_dir)
root=Path(args.app)/'Contents/SharedSupport/CrossOver'
bottles=Path(args.bottles_dir) if args.bottles_dir else userhome/'Library/Application Support/CrossOver/Bottles'
if Path(args.bottle).name!=args.bottle: raise SystemExit('Use a bottle name, not a path.')
conf=bottles/args.bottle/'cxbottle.conf'

state=root/'RE7-media-patch.json'
if os.geteuid()!=0 and '--check' not in sys.argv: raise SystemExit('Run installation using sudo; use --check to verify without installing.')
if '--restore' in sys.argv:
 if not state.exists(): raise SystemExit('No installed patch state found.')
 data=json.loads(state.read_text());backup=Path(data['backup']);conf=Path(data.get('config',str(conf)))
 for n in ['winegstreamer.so','winedmo.so']: shutil.copy2(backup/n,root/'lib/wine/x86_64-unix'/n)
 shutil.copy2(backup/'cxbottle.conf',conf)
 state.unlink(); print('Original media modules and bottle settings restored.');raise SystemExit
framework=root/'lib64/GStreamer.framework'
libs=framework/'Libraries';plugins=libs/'gstreamer-1.0'
required=['coreelements','typefindfunctions','libav','asf','playback','audioconvert','audioresample','videoconvertscale','volume','app','deinterlace','videofilter']
for n in required:
 if not (plugins/('libgst'+n+'.dylib')).exists():raise SystemExit('Missing plugin: '+n)
if not conf.exists():raise SystemExit('Steam bottle config missing.')
if '--check' in sys.argv:
 print('Preview and Steam bottle found; all required plugins present.')
 raise SystemExit
if state.exists(): raise SystemExit('Patch already installed; restart the bottle and test RE7.')
# Prepare copies before changing the application.
import tempfile
with tempfile.TemporaryDirectory(prefix='re7-media-') as td:
 prepared=Path(td)
 for n in ['winegstreamer.so','winedmo.so']:
  s=root/'lib/wine/x86_64-unix'/n;d=prepared/n;shutil.copy2(s,d)
  paths=subprocess.check_output(['/usr/bin/otool','-l',str(d)],text=True)
  target='@loader_path/../../../lib64/GStreamer.framework/Libraries'
  if target not in paths:
   subprocess.run(['/usr/bin/install_name_tool','-rpath','@loader_path/../../../lib/x86_64',target,str(d)],check=True)
  subprocess.run(['/usr/bin/codesign','--force','--sign','-',str(d)],check=True)
 backup=root/('RE7-media-backup-'+time.strftime('%Y%m%d-%H%M%S'));backup.mkdir()
 for n in ['winegstreamer.so','winedmo.so']:shutil.copy2(root/'lib/wine/x86_64-unix'/n,backup/n)
 shutil.copy2(conf,backup/'cxbottle.conf')
 state.write_text(json.dumps({'backup':str(backup),'config':str(conf)}))
 try:
  selected=framework/'RE7Plugins';selected.mkdir(exist_ok=True)
  for n in required:
   d=selected/('libgst'+n+'.dylib')
   if not (d.exists() or d.is_symlink()):d.symlink_to(plugins/d.name)
  subprocess.run(['/usr/bin/xattr','-dr','com.apple.quarantine',str(framework)],check=False)
  for n in ['winegstreamer.so','winedmo.so']:shutil.copy2(prepared/n,root/'lib/wine/x86_64-unix'/n)
  s=conf.read_text();section='[EnvironmentVariables]';s=s if section in s else s+'\n'+section+'\n';start=s.index(section)+len(section);end=s.find('\n[',start);end=len(s) if end<0 else end
  keys=['GST_PLUGIN_PATH','GST_PLUGIN_PATH_1_0','GST_PLUGIN_SYSTEM_PATH','GST_PLUGIN_SYSTEM_PATH_1_0','GST_REGISTRY','GST_REGISTRY_1_0','GST_DEBUG','GST_DEBUG_FILE']
  block='\n'.join(l for l in s[start:end].splitlines() if not any(l.strip().startswith('"'+k+'"') for k in keys))
  values={'GST_PLUGIN_PATH_1_0':str(selected),'GST_PLUGIN_SYSTEM_PATH_1_0':str(selected),'GST_REGISTRY_1_0':str(conf.parent/'re7-media-registry-v1.bin'),'GST_DEBUG':'3' if args.diagnostics else '0'}
  if args.diagnostics: values['GST_DEBUG_FILE']=str(userhome/'Downloads/re7-media.log')
  settings='\n'.join('"'+k+'" = "'+v+'"' for k,v in values.items())
  conf.write_text(s[:start]+'\n'+settings+'\n'+block+'\n'+s[end:])
 except Exception:
  for n in ['winegstreamer.so','winedmo.so']:shutil.copy2(backup/n,root/'lib/wine/x86_64-unix'/n)
  shutil.copy2(backup/'cxbottle.conf',conf);state.unlink();raise
print('Installed. Backup:',backup)
print('Fully restart the selected bottle and launch RE7. Logging is disabled unless --diagnostics was selected.')
PY
