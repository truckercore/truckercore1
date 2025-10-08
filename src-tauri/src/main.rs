#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::Manager;

fn main() {
  tauri::Builder::default()
    .setup(|app| {
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
      let window = app.get_window("main").unwrap();
      // Prevent file:// navigation
      window.listen("tauri://file-drop", |_e| { /* ignore */ });
      window.eval(&format!("window.location.replace('{}');", start_url))?;
      Ok(())
    })
    .build(tauri::generate_context!())
    .expect("error while running tauri application")
    .run(|_app_handle, _event| { let _ = _event; });
}
