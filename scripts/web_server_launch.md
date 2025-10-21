Flutter Web launch: immediate run + troubleshooting

Immediate solution: run with the built-in web server
- Start the app without auto-launching a browser:

  flutter run -d web-server --web-port 52848 --web-hostname localhost

- Then open http://localhost:52848 in your browser.
- Windows users can also run our helper script (forwards SUPABASE_URL/SUPABASE_ANON/MAPBOX_TOKEN as dart-defines):

  PowerShell:
  .\scripts\dev\run_web_server.ps1 -Port 52848 -Host localhost

- Or use the Makefile target (macOS/Linux with make installed):

  make run-flutter-web-server PORT=52848 HOST=localhost

Chrome/Edge launch troubleshooting (step-by-step)
1) Close all Chrome processes
- Open Task Manager and end all tasks named "Google Chrome" and "chrome.exe".
- Re-run: flutter run -d chrome

2) Update Chrome/Edge
- In Chrome: navigate to chrome://settings/help (Edge: edge://settings/help), update and relaunch.

3) Clear Flutter’s temp browser profile
- Delete the Flutter temp profile directories (close browsers first):
  C:\Users\YOUR_USERNAME\AppData\Local\Temp\flutter_tools.*
  Example from a failing log: C:\Users\moise\AppData\Local\Temp\flutter_tools.<hash>\flutter_tools_chrome_device.<id>

4) Specify browser binary and flags explicitly (if needed)
- Point Flutter to a specific Chrome executable path:
  flutter config --chrome-executable="C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
- Pass a browser startup flag to bypass first-run prompts:
  flutter run -d chrome --web-browser-flag="--no-first-run"

5) Free the remote debugging port
- Reboot to clear stale listeners, or allow Flutter to choose any free port:
  flutter run -d chrome --web-port 0

6) Check for port conflicts manually
- List listening ports and owning processes:
  netstat -a -n -o
- If the port shown in the Flutter log is in use, terminate the owning process or run on a different port, e.g.:
  flutter run -d chrome --web-port=8081

7) Clear browser cache (sometimes interferes with devtools attach)
- In Chrome/Edge: Settings ➜ Privacy and security ➜ Clear browsing data ➜ Cached images and files.

8) Disable antivirus/EDR blocking child Chrome
- Temporarily pause AV or add an allow rule for Chrome launched by flutter_tools. If it works, add permanent exceptions.

9) Upgrade Flutter and web tooling
- flutter upgrade
- flutter clean
- flutter pub get

Fallback: use the Web Server device (works even if Chrome won’t auto-launch)
- Start on an explicit port and open it manually:
  flutter run -d web-server --web-port 58582 --web-hostname localhost
  Then open http://localhost:58582 in your browser.
- If the problem persists, run with -d web-server and report the original chrome failure per Flutter’s guidance: https://github.com/flutter/flutter/issues

Notes
- This repository fully supports running with -d web-server; you can develop web features without relying on auto browser launch.
- When using the web server device, Flutter prints the local URL in the console; open it manually in any browser.
- Optional: use Edge directly: flutter run -d edge
