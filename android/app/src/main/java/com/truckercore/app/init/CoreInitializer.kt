package com.truckercore.app.init

import android.content.Context
import androidx.startup.Initializer

class CoreInitializer : Initializer<Unit> {
  override fun create(context: Context) {
    // Keep extremely light; defer heavy work to after first frame
    // Example: warm small caches, set up logging flags
  }
  override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}
