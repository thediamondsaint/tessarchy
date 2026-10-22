import QtQuick
import QtTest
import "../../shell/components"

TestCase {
    id: test
    name: "DesktopWidgets"
    width: 420
    height: 460
    when: windowShown
    visible: true

    DesktopWidgets {
        id: widgets
        objectName: "desktopWidgets"
        width: 380
        height: 420
        mode: "phone"
        weather: ({ok: true, temperature: 22, unit: "°C", description: "Clear", icon: "weather-sun"})
        batteryPresent: true
        batteryPercent: 0.72
    }
    SignalSpy { id: refresh; target: widgets; signalName: "refreshWeather" }

    function test_phone_grid_uses_touch_sized_single_column() {
        compare(widgets.columns, 1);
        verify(widgets.cardWidth >= 340);
        verify(findChild(widgets, "desktopWidgetCard-calendar") !== null);
        verify(findChild(widgets, "desktopWidgetCard-weather") !== null);
        verify(findChild(widgets, "desktopWidgetCard-media") !== null);
        verify(findChild(widgets, "desktopWidgetCard-battery") !== null);
    }

    function test_weather_refresh_signal_is_explicit() {
        refresh.clear();
        widgets.refreshWeather();
        compare(refresh.count, 1);
    }
}
