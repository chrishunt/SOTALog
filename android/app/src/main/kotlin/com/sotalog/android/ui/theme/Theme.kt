package com.sotalog.android.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

data class AppColors(
    val orange: Color,
    val blue: Color,
    val green: Color,
    val red: Color,
    val lightBlue: Color,
    val pink: Color,
    val yellow: Color,
)

val LocalAppColors = staticCompositionLocalOf {
    AppColors(
        orange = AppOrange,
        blue = AppBlue,
        green = AppGreen,
        red = AppRed,
        lightBlue = AppLightBlue,
        pink = AppPink,
        yellow = AppYellow,
    )
}

private val LightAppColors = AppColors(
    orange = AppOrange,
    blue = AppBlue,
    green = AppGreen,
    red = AppRed,
    lightBlue = AppLightBlue,
    pink = AppPink,
    yellow = AppYellow,
)

private val DarkAppColors = AppColors(
    orange = AppOrangeDark,
    blue = AppBlueDark,
    green = AppGreenDark,
    red = AppRedDark,
    lightBlue = AppLightBlueDark,
    pink = AppPinkDark,
    yellow = AppYellowDark,
)

private val LightColorScheme = lightColorScheme(
    primary = AppBlue,
    onPrimary = Color.White,
    primaryContainer = AppLightBlue.copy(alpha = 0.3f),
    onPrimaryContainer = AppBlue,
    secondary = AppGreen,
    onSecondary = Color.White,
    secondaryContainer = AppGreen.copy(alpha = 0.2f),
    onSecondaryContainer = AppGreen,
    tertiary = AppOrange,
    onTertiary = Color.White,
    tertiaryContainer = AppOrange.copy(alpha = 0.2f),
    onTertiaryContainer = AppOrange,
    error = AppRed,
    onError = Color.White,
    background = LightBackground,
    onBackground = Color(0xFF1C1B1F),
    surface = LightSurface,
    onSurface = Color(0xFF1C1B1F),
    surfaceVariant = LightSurfaceVariant,
    onSurfaceVariant = Color(0xFF49454F),
)

private val DarkColorScheme = darkColorScheme(
    primary = AppBlueDark,
    onPrimary = Color(0xFF003258),
    primaryContainer = AppBlue,
    onPrimaryContainer = AppLightBlueDark,
    secondary = AppGreenDark,
    onSecondary = Color(0xFF003828),
    secondaryContainer = AppGreen,
    onSecondaryContainer = AppGreenDark,
    tertiary = AppOrangeDark,
    onTertiary = Color(0xFF4A2800),
    tertiaryContainer = AppOrange,
    onTertiaryContainer = AppOrangeDark,
    error = AppRedDark,
    onError = Color(0xFF4A1E00),
    background = DarkBackground,
    onBackground = Color(0xFFE6E1E5),
    surface = DarkSurface,
    onSurface = Color(0xFFE6E1E5),
    surfaceVariant = DarkSurfaceVariant,
    onSurfaceVariant = Color(0xFFCAC4D0),
)

@Composable
fun SOTALogTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    val appColors = if (darkTheme) DarkAppColors else LightAppColors

    CompositionLocalProvider(LocalAppColors provides appColors) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = Typography,
            content = content,
        )
    }
}

object SOTALogTheme {
    val appColors: AppColors
        @Composable
        get() = LocalAppColors.current
}
