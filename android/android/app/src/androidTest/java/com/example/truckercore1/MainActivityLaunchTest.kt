package com.example.truckercore1

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.ext.junit.rules.ActivityScenarioRule
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainActivityLaunchTest {
    @get:Rule
    val rule = ActivityScenarioRule(MainActivity::class.java)

    @Test
    fun launchesMainActivity() {
        // If we reached here without crash, the activity launched.
        // Additional assertions can be added with Espresso.
    }
}
