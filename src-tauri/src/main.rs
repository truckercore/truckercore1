#![cfg_attr(all(not(debug_assertions), target_os = "windows"), windows_subsystem = "windows")]

use tauri::Manager;

#[tauri::command]
async fn app_check_updates() -> Result<(), String> {
  tauri::updater::check().await.map_err(|e| format!("check failed: {e}"))
}

fn main() {
  tauri::Builder::default()
    .invoke_handler(tauri::generate_handler![app_check_updates])
    .setup(|app| {
      // Parse optional --role argument
      let args: Vec<String> = std::env::args().collect();
      let mut role = "generic".to_string();
      let mut i = 0;
      while i + 1 < args.len() {
        if args[i] == "--role" {
          let v = args[i + 1].as_str();
          match v {
            "owner-operator" | "fleet-manager" | "freight-broker" | "truck-stop" => role = v.to_string(),
            _ => {}
          }
          i += 1;
        }
        i += 1;
      }

      let start_url = format!("https://app.truckercore.com/desktop?role={}", role);
      if let Some(window) = app.get_window("main") {
        // Prevent file:// navigation and ignore file drops
        window.listen("tauri://file-drop", |_e| { /* ignore */ });
        let _ = window.eval(&format!("window.location.replace('{}');", start_url));
      }

      // Optional UX hook: show a dialog when update becomes available
      let handle = app.handle();
      let win = handle.get_window("main");
      app.listen_global("tauri://update-available", move |_| {
        if let Some(w) = win.as_ref() {
          let _ = tauri::api::dialog::message(Some(w), "Update", "A new version is available. Downloading…");
        }
      });

      Ok(())
    })
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
