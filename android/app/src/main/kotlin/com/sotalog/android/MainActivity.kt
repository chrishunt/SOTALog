package com.sotalog.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.sotalog.android.ui.navigation.SOTALogNavigation
import com.sotalog.android.ui.theme.SOTALogTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            SOTALogTheme {
                SOTALogNavigation()
            }
        }
    }
}
