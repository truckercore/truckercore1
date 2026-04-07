package com.truckercore.macrobenchmark

import androidx.benchmark.macro.MacrobenchmarkRule
import androidx.benchmark.macro.StartupMode
import androidx.benchmark.macro.StartupTimingMetric
import androidx.benchmark.macro.collectBaselineProfile
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

private const val PKG = "com.truckercore.app"

@RunWith(AndroidJUnit4::class)
@LargeTest
class BaselineProfile {
  @get:Rule
  val rule = MacrobenchmarkRule()

  @Test
  fun generate() = rule.collectBaselineProfile(
    packageName = PKG,
    stableIterations = 3,
    includeInStartupProfile = true,
    maxIterations = 8
  ) {
    // Cold start to first frame of landing route
    startActivityAndWait()
    device.waitForIdle()

    // TODO: Use UiAutomator to navigate your hot paths. Example:
    // val safety = device.findObject(androidx.test.uiautomator.By.textContains("Safety"))
    // safety?.click()
    // device.waitForIdle()
  }

  @Test
  fun coldStartTiming() = rule.measureRepeated(
    packageName = PKG,
    metrics = listOf(StartupTimingMetric()),
    iterations = 5,
    startupMode = StartupMode.COLD
  ) {
    startActivityAndWait()
  }
}
